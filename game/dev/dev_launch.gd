class_name DevLaunch
extends RefCounted
## A dev launch request for the Level scene (Level Playtester): level id, hand (tower type ids), seed, instant
## playback and whether the result is saved. Set in-process with request(), or written to user://dev_launch.json
## by the editor dock before it plays res://game/level/level.tscn (the played game is another process). The
## LevelController takes it once at setup (take()); without one it behaves exactly as before. A file older than
## MAX_AGE seconds is ignored and removed, so a stale request never hijacks a later run.

const FILE := "user://dev_launch.json"
const MAX_AGE := 120.0
const LEVEL_SCENE := "res://game/level/level.tscn"

static var _pending = null # Dictionary or null

## A request: level_id, hand (Array of tower type ids; empty = the saved hand), level_seed (>= 1), instant
## (true/false, or null = the setting), record (false: the result is not written to the save).
static func make(level_id: String, hand: Array = [], level_seed: int = 1, instant = null, record := false) -> Dictionary:
	return {"level_id": level_id, "hand": hand.map(func(h): return str(h)), "seed": maxi(1, level_seed),
		"instant": instant, "record": record, "time": Time.get_unix_time_from_system()}

## Requests a launch in this process (the next Level scene setup takes it).
static func request(req: Dictionary) -> void:
	_pending = req

## Writes the request for another process (the editor's Play); returns a problem or "".
static func write_file(req: Dictionary, path: String = FILE) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return "cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(req, "  "))
	f.close()
	return ""

## Whether a request is waiting (in-process or a fresh file).
static func has_request(path: String = FILE) -> bool:
	return _pending != null or FileAccess.file_exists(path)

## Takes the waiting request (in-process first, then the file, which is deleted); null when there is none.
static func take(path: String = FILE) -> Variant:
	if _pending != null:
		var p = _pending
		_pending = null
		return p
	if not FileAccess.file_exists(path): return null
	var text := FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary): return null
	var req: Dictionary = json.data
	if Time.get_unix_time_from_system() - float(req.get("time", 0.0)) > MAX_AGE: return null
	return req

static func clear(path: String = FILE) -> void:
	_pending = null
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
