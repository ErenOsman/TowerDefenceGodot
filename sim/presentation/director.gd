class_name Director
extends RefCounted
## Plays the event log back: actions one at a time, their beats in order, the events of a beat
## together. A beat ends when all its presenters are ready; presenters not yet done keep playing as
## tails. Busy until everything has finished — input is blocked while busy. Engine-free: the view
## calls tick() with scaled delta time (game speed).
## (Animation & Presentation — Design, Director.)
## C# events ActionStarted/ActionEnded/BeatStarted/BeatEnded → the signals below.

signal action_started(info: ActionInfo)
signal action_ended(info: ActionInfo)
signal beat_started(beat: BeatPlayback)
signal beat_ended(beat: BeatPlayback)

var _log: EventLog
var _factory: IPresenterFactory
var _frames: FrameRecorder

var _cursor: int = 0
var _actions: Array = []  # queue of Array[BeatPlayback]
var _current_action = null  # Array of BeatPlayback, or null
var _beat_index: int = 0
var _current_beat: BeatPlayback = null
var _beat_presenters: Array = []  # of IPresenter
var _tails: Array = []  # of IPresenter

## Instant playback (a setting): every action finishes as soon as it starts.
var instant: bool = false

## The frame the view should show: set when a beat starts, so HP drops as its hit plays.
var shown: ViewFrame = null

## Something is playing or waiting to play: input must stay blocked.
var busy: bool:
	get: return _current_beat != null or _current_action != null or _actions.size() > 0 or _tails.size() > 0 or _cursor < _log.events.size()

## The action playing now, if any (what Skip would finish).
var current_action: ActionInfo:
	get: return _current_action[0].action if _current_action != null and _current_action.size() > 0 else null

func _init(log: EventLog, factory: IPresenterFactory, frames: FrameRecorder) -> void:
	_log = log
	_factory = factory
	_frames = frames
	shown = frames.current()

# ------------------------------------------------------------------ playback

## Advances playback by dt seconds (scaled); takes new events from the log first.
func tick(dt: float) -> void:
	_ingest()
	for p in _beat_presenters: p.tick(dt)
	for p in _tails: p.tick(dt)
	_tails = _tails.filter(func(p): return not p.done)

	# advance as far as possible this frame: zero-length beats and actions do not cost a frame each
	for guard in 10000:
		if _current_beat != null:
			if not instant and not _beat_presenters.all(func(p): return p.ready): return
			if instant:
				for p in _beat_presenters: p.finish()
			_end_beat()
			continue
		if _current_action != null and _beat_index < _current_action.size():
			_beat_index += 1
			_start_beat(_current_action[_beat_index - 1])
			continue
		if _current_action != null:
			_end_action()
			continue
		if _actions.size() > 0:
			_start_action(_actions.pop_front())
			continue
		if instant: _finish_tails()
		return

## Finishes the current action at once (all its beats); the next one plays normally.
func skip() -> void:
	_ingest()
	if _current_action == null and _actions.size() > 0: _start_action(_actions.pop_front())
	if _current_action == null:
		_finish_tails()
		return
	_finish_tails()
	while true:
		if _current_beat != null:
			for p in _beat_presenters: p.finish()
			_end_beat()
		if _beat_index < _current_action.size():
			_beat_index += 1
			_start_beat(_current_action[_beat_index - 1])
			continue
		_end_action()
		break
	_finish_tails()

## Finishes everything that is queued (e.g. when leaving the level).
func finish_all() -> void:
	var was := instant
	instant = true
	tick(0)
	instant = was
	_finish_tails()

# ------------------------------------------------------------------ internals

## Groups events written since the last call into actions and beats.
func _ingest() -> void:
	var events: Array = _log.events
	if _cursor >= events.size(): return
	var action = null
	var beat: BeatPlayback = null
	var action_id := -2147483648
	while _cursor < events.size():
		var e: GameEvent = events[_cursor]
		if action == null or e.action != action_id or e.action < 0:
			if action != null: _actions.append(action)
			action = []
			action_id = e.action
			beat = null
		if beat == null or beat.beat != e.beat:
			beat = BeatPlayback.new()
			beat.beat = e.beat
			if e.action >= 0 and e.action < _log.actions.size():
				beat.action = _log.actions[e.action]
			else:
				var info := ActionInfo.new()
				info.id = -1
				info.kind = ActionKind.Command
				beat.action = info
			action.append(beat)
		beat.events.append(e)
		_cursor += 1
	if action != null: _actions.append(action)

func _start_action(action: Array) -> void:
	_current_action = action
	_beat_index = 0
	action_started.emit(action[0].action)

func _end_action() -> void:
	var info: ActionInfo = _current_action[0].action
	_current_action = null
	action_ended.emit(info)

func _start_beat(beat: BeatPlayback) -> void:
	beat.frame = _frames.frame(beat.beat)
	_current_beat = beat
	shown = beat.frame
	_beat_presenters.clear()
	for e in beat.events:
		var p: IPresenter = _factory.create(e, beat) if _factory != null else null
		if p == null: continue
		_beat_presenters.append(p)
		p.begin()
	beat_started.emit(beat)

func _end_beat() -> void:
	var beat := _current_beat
	for p in _beat_presenters:
		if not p.done: _tails.append(p)
	_beat_presenters.clear()
	_current_beat = null
	_frames.release(beat.beat)
	beat_ended.emit(beat)

func _finish_tails() -> void:
	for p in _tails: p.finish()
	_tails.clear()
