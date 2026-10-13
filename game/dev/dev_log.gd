class_name DevLog
extends Logger
## Captures the engine's log (print, push_warning, push_error, script errors) into a ring of the last LIMIT
## lines for the F1 dev panel's Log tab. Installed by the DevPanel autoload with OS.add_logger() (only when the
## dev panel is enabled). The engine may call it from any thread, hence the mutex.

const LIMIT := 200
const ERROR_TYPES := ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

static var current: DevLog = null

var _lines := PackedStringArray()
var _mutex := Mutex.new()
## Bumped on every line (the panel refreshes when it changes).
var serial := 0

func _log_message(message: String, error: bool) -> void:
	for l in message.rstrip("\n").split("\n"):
		add(("! " if error else "") + l)

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, script_backtraces: Array) -> void:
	var kind: String = ERROR_TYPES[error_type] if error_type >= 0 and error_type < ERROR_TYPES.size() else "ERROR"
	var text := rationale if rationale != "" else code
	# push_error / push_warning: point at the script that called it, not the engine's C++ file
	for bt in script_backtraces:
		if bt is ScriptBacktrace and bt.get_frame_count() > 0:
			file = bt.get_frame_file(0)
			line = bt.get_frame_line(0)
			function = bt.get_frame_function(0)
			break
	add("%s: %s  (%s:%d %s)" % [kind, text, file.get_file(), line, function])

## Adds a line (also usable directly: DevLog.current.add("…")).
func add(text: String) -> void:
	_mutex.lock()
	_lines.append(text)
	if _lines.size() > LIMIT: _lines = _lines.slice(_lines.size() - LIMIT)
	serial += 1
	_mutex.unlock()

## The captured lines, oldest first.
func lines() -> PackedStringArray:
	_mutex.lock()
	var copy := _lines.duplicate()
	_mutex.unlock()
	return copy

func clear() -> void:
	_mutex.lock()
	_lines.clear()
	serial += 1
	_mutex.unlock()

## Installs the capture once; returns it.
static func install() -> DevLog:
	if current == null:
		current = DevLog.new()
		OS.add_logger(current)
	return current
