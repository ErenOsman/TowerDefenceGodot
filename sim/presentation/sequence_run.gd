class_name SequenceRun
extends RefCounted
## Plays a sequence's lines in order (engine-free; the level drives it and the speech bubble shows
## `current`). A line waiting for an event also accepts one that happened while the previous
## line showed, so a player who acts early is not stuck; it moves on only while nothing is playing
## (the action that caused the event has finished). It never changes the game.

## Raised when the line changes (also when the sequence ends: current is then null). C# event LineChanged.
signal line_changed

var _lines: Array = []
var _shown_for: float = 0.0
var _seen_this_line: Dictionary = {}  # SequenceEvent → true
var _seen_last_line: Dictionary = {}

## The line showing (index into the sequence), or -1 when finished.
var index: int = -1

## Changes whenever the line changes (the bubble redraws on it).
var version: int = 0

func _init(lines = null) -> void:
	if lines != null: _lines.append_array(lines)
	index = 0 if _lines.size() > 0 else -1

var count: int:
	get: return _lines.size()

## The line showing, or null when the sequence is over.
var current: SequenceLine:
	get: return _lines[index] if index >= 0 and index < _lines.size() else null

var finished: bool:
	get: return current == null

## Commands should wait: the line showing pauses play.
var blocking: bool:
	get: return current != null and current.pauses_play

## Advances time; a timed line or a line whose event has come moves on (events only while playback is idle).
func tick(dt: float, playback_idle: bool) -> void:
	var line := current
	if line == null: return
	_shown_for += dt
	if line.continue_on == SequenceContinue.Seconds and _shown_for >= line.seconds: _next()
	elif line.continue_on == SequenceContinue.Event and playback_idle and (_seen_this_line.has(line.wait_for) or _seen_last_line.has(line.wait_for)): _next()

## The player clicked the bubble (or pressed Space): a click line moves on.
func click() -> void:
	if current != null and current.continue_on == SequenceContinue.Click: _next()

## A game event happened.
func notify(e: int) -> void:
	if current != null: _seen_this_line[e] = true

## Ends the sequence at once.
func skip() -> void:
	if finished: return
	index = -1
	_changed()

func _next() -> void:
	_seen_last_line = _seen_this_line
	_seen_this_line = {}
	_shown_for = 0.0
	index = index + 1 if index + 1 < _lines.size() else -1
	_changed()

func _changed() -> void:
	version += 1
	line_changed.emit()
