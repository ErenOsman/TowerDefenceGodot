class_name FrameRecorder
extends RefCounted
## Captures a view frame whenever the event log completes a beat, and hands them out by beat. The
## Director releases each frame once its beat has played.
## Port note: the C# overload FrameRecorder(LevelSession) is FrameRecorder.of_session(session);
## FrameRecorder.new(state, log, session = null) is the other constructor.

var _state: GameState
var _session: LevelSession
var _log: EventLog
var _frames: Dictionary = {}  # beat → ViewFrame

func _init(state: GameState, log: EventLog, session: LevelSession = null) -> void:
	_state = state
	_log = log
	_session = session
	log.beat_completed.connect(_on_beat_completed)

## The C# FrameRecorder(LevelSession) constructor.
static func of_session(session: LevelSession) -> FrameRecorder:
	return FrameRecorder.new(session.state, session.log, session)

func detach() -> void:
	if _log.beat_completed.is_connected(_on_beat_completed): _log.beat_completed.disconnect(_on_beat_completed)

func _on_beat_completed(beat: int) -> void:
	_frames[beat] = ViewFrame.capture(_state, _session, beat)

## The frame after a beat, or the current state when none was recorded.
func frame(beat: int) -> ViewFrame:
	return _frames[beat] if _frames.has(beat) else ViewFrame.capture(_state, _session, beat)

func current() -> ViewFrame:
	return ViewFrame.capture(_state, _session, -1)

func release(beat: int) -> void:
	_frames.erase(beat)

var count: int:
	get: return _frames.size()
