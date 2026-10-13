class_name EventLog
extends RefCounted
## The events the logic wrote, the warnings, and the actions (presentation groups events by action and beat).
##
## ACTIONS (C# `using (log.BeginAction(kind, actor, detail)) { ... }`):
##   var scope := log.begin_action(ActionKind.Cast, caster.id, ability.name)
##   ... writes ...
##   scope.dispose()            # or log.end_action(); dispose() is idempotent like the C# IDisposable
## or the callable form:  log.in_action(ActionKind.Cast, caster.id, "Strike", func(): ...)  (returns the callable's result).
## An action opened inside another one joins it (actions never nest); every begin_action needs exactly one
## dispose()/end_action(), including on early returns (GDScript has no `using`/finally).
##
## BEATS: write() outside begin_beat()/end_beat() makes each event its own beat; the resolver wraps each queue item
## (or checkpoint) in begin_beat()/end_beat() (C# internal BeginBeat/EndBeat).
## C# event BeatCompleted → signal beat_completed(beat: int).

## Raised when a beat with events is complete, with that beat's id: the state at that moment is
## the state after the beat (presentation captures its view frame here).
signal beat_completed(beat: int)

## Array of GameEvent.
var events: Array = []
## Array of String.
var warnings: Array = []
## Array of ActionInfo.
var actions: Array = []

var _open_action: int = -1
var _action_depth: int = 0
var _beat_counter: int = 0
var _current_beat: int = -1
var _last_completed_beat: int = -1

## The open action's id, or -1.
var current_action: int:
	get: return _open_action

func write(e: GameEvent) -> GameEvent:
	e.id = events.size()
	e.action = _open_action
	var alone := _current_beat < 0
	if alone:
		_beat_counter += 1
		e.beat = _beat_counter # outside a queue item every write is its own beat
	else:
		e.beat = _current_beat
	events.append(e)
	if alone: _complete_beat()
	return e

## Reports the last written beat as complete, once.
func _complete_beat() -> void:
	if events.is_empty(): return
	var b: int = events[events.size() - 1].beat
	if b == _last_completed_beat: return
	_last_completed_beat = b
	beat_completed.emit(b)

## Opens an action; call dispose() on the result (or end_action()) to close it. An action opened inside
## another one joins it (a level lost during a cast belongs to that cast), so actions never nest.
func begin_action(kind: int, actor: int, detail = null) -> ActionScope:
	if _action_depth == 0:
		_open_action = actions.size()
		var a := ActionInfo.new()
		a.id = _open_action
		a.kind = kind
		a.actor = actor
		a.detail = detail
		actions.append(a)
	_action_depth += 1
	return ActionScope.new(self)

## Closes one begin_action (what disposing the C# scope does).
func end_action() -> void:
	if _action_depth > 0:
		_action_depth -= 1
		if _action_depth == 0: _open_action = -1

## begin_action + fn.call() + end_action, returning fn's result.
func in_action(kind: int, actor: int, detail, fn: Callable) -> Variant:
	var scope := begin_action(kind, actor, detail)
	var r = fn.call()
	scope.dispose()
	return r

## The token begin_action returns (C# IDisposable ActionScope).
class ActionScope extends RefCounted:
	var _log: EventLog
	func _init(p_log: EventLog) -> void: _log = p_log
	func dispose() -> void:
		if _log != null: _log.end_action()
		_log = null

## Starts a new beat: every write until end_beat shares it. The previous beat is complete.
func begin_beat() -> void:
	_complete_beat()
	_beat_counter += 1
	_current_beat = _beat_counter

func end_beat() -> void:
	_complete_beat()
	_current_beat = -1

## Array of the events of that type, in order.
func of_type(p_type: int) -> Array:
	var out := []
	for e in events:
		if e.type == p_type: out.append(e)
	return out

static func _name_or_null(s: GameState, p_id: int) -> Variant:
	var e := s.get_entity(p_id)
	return e.name if e != null else null

## One deterministic line per event; used by golden tests and the console (same text as the C#).
func format(e: GameEvent, s: GameState) -> String:
	var sb := GameEventType.name_of(e.type)
	var src = null if e.source < 0 else _name_or_null(s, e.source)
	var tgt = null if e.target < 0 else _name_or_null(s, e.target)
	if src != null and tgt != null and src != tgt: sb += " %s->%s" % [src, tgt]
	elif tgt != null: sb += " " + tgt
	elif src != null: sb += " " + src
	if e.detail != null and e.detail != "": sb += " " + e.detail
	if e.type == GameEventType.EntityMoved or e.type == GameEventType.EntityEnteredTile or e.type == GameEventType.Collision \
			or e.type == GameEventType.EntitySpawned or e.type == GameEventType.EntityResurrected:
		sb += " %s->%s" % [Dirs.pos_str(e.from), Dirs.pos_str(e.to)]
	if e.targets != null and e.targets.size() > 0:
		var names := PackedStringArray()
		for t in e.targets:
			var n = _name_or_null(s, t)
			names.append("" if n == null else n)
		sb += " [" + ",".join(names) + "]"
	var keys: Array = e.facts.keys()
	keys.sort() # String < is ordinal (code point order), like StringComparer.Ordinal
	for k in keys:
		sb += " %s=%s" % [k, Num.to_str(e.facts[k])]
	if e.tags.size() > 0:
		var tags: Array = e.tags.keys()
		tags.sort()
		sb += " {" + ",".join(PackedStringArray(tags)) + "}"
	return sb

func dump(s: GameState) -> String:
	var lines := PackedStringArray()
	for e in events: lines.append(format(e, s))
	return "\n".join(lines)
