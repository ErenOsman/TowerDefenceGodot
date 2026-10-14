extends SceneTree
## Resident job runner: keeps one Godot process open so checks / tests / renders skip the start-up and the import.
##   godot --headless --path <project> -s tools/daemon.gd -- <queue dir>            (headless daemon)
##   xvfb-run … godot --path <project> --rendering-driver opengl3 -s tools/daemon.gd -- <queue dir> render
## Started by systemd (td-godot-headless / td-godot-render user services); the client is /home/ubuntu/godot/jobs.sh.
## See /home/ubuntu/godot/README-daemon.md.
##
## Queue: <q>/jobs/<id>.json = {id, cmd, args[], cwd?, godot_args[]?, timeout?}, taken in name order (every 0.2 s),
## moved to <q>/running/ while it runs; the result is <q>/done/<id>.out (text) + <q>/done/<id>.code (exit code,
## written last). Heartbeat: <q>/alive rewritten every second while idle; <q>/busy = "<pid> <job id> <start>" while a
## job runs (the main loop is blocked during in-process jobs). Log: <q>/daemon.log.
##
## Commands
##   ping                  → "pong …" (no import check)
##   check [--full]        → like tools/check.gd: "CHECK OK <n> scripts" or "CHECK FAIL <path>" lines (+ the errors)
##   test [--filter name]  → the test suite in-process (tests/suite_runner.gd), output and exit code like tests/run.gd
##   shot [godot args…] <tools/x.gd> [--] [args…]   (render daemon only) → the tool script in a child Godot process
##   reload [--all]        → reload changed scripts (--all: every script)
##   restart               → finish and quit(0); systemd starts a fresh process
## Before every job but ping/restart: art/ and data/ assets without a .import (or newer than it) → a child
## `godot --headless --import` under /home/ubuntu/godot/.td.lock (this process cannot import).
## Scripts changed since the last job are reloaded in place (with every script that references them); a changed
## class_name set (a new / renamed / removed global class) needs a fresh process: that job runs in a child process
## and the daemon restarts after it. Between test runs the autoloads get fresh script instances (fresh GameApp,
## SaveData…), static vars go back to their defaults and stray nodes under /root are freed.
## Limits: after 200 jobs or above 1.5 GB RSS the daemon finishes the job and quits (systemd restarts it).

const POLL_S := 0.2
const HEARTBEAT_MS := 1000
const MAX_JOBS := 200
const MAX_RSS_KB := 1536 * 1024
const LOCK := "/home/ubuntu/godot/.td.lock"
const LOCK_WAIT_S := 90
const SELF := "res://tools/daemon.gd"
const CHECK_ROOTS := ["res://sim", "res://tests", "res://game", "res://tools", "res://addons"]
const ASSET_ROOTS := ["res://art", "res://data"]
const IMPORTABLE := ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "dds", "ktx", "fbx", "glb",
	"gltf", "blend", "obj", "dae", "wav", "ogg", "mp3", "ttf", "otf", "woff", "woff2", "fnt", "font"]
const RESOURCE_EXT := ["tscn", "tres", "scn", "res"]

## Captures the engine log (print, errors) of one job, formatted like Godot's console.
class Capture extends Logger:
	var on := false
	var paused := false
	var lines := PackedStringArray()
	var _m := Mutex.new()
	const KINDS := ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]
	const AT := ["   at: ", "     at: ", "          at: ", "          at: "]

	func start() -> void:
		_m.lock(); lines = PackedStringArray(); on = true; paused = false; _m.unlock()

	func stop() -> String:
		_m.lock(); on = false; var t := "\n".join(lines); lines = PackedStringArray(); _m.unlock()
		return t

	func add(text: String) -> void:
		_m.lock()
		if on and not paused: lines.append(text)
		_m.unlock()

	func _log_message(message: String, _error: bool) -> void:
		if not on or paused: return
		add(message.trim_suffix("\n"))

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if not on or paused: return
		var k := clampi(error_type, 0, 3)
		var t := "%s: %s\n%s%s (%s:%d)" % [KINDS[k], rationale if rationale != "" else code, AT[k], function, file, line]
		for bt in script_backtraces:
			if bt != null and not bt.is_empty():
				# the daemon's own frames are left out (a run.gd backtrace ends in the test; a compile error met by
				# the daemon's reload has no backtrace, like a load in a fresh process)
				var frames := PackedStringArray()
				for i in bt.get_frame_count():
					if bt.get_frame_file(i) == "res://tools/daemon.gd": break
					frames.append("              [%d] %s (%s:%d)" % [i, bt.get_frame_function(i), bt.get_frame_file(i), bt.get_frame_line(i)])
				if not frames.is_empty():
					t += "\n          %s backtrace (most recent call first):\n%s" % [bt.get_language_name(), "\n".join(frames)]
				break
		add(t)

var q := ""
var render := false
var proj := ""          # absolute project dir, with a trailing /
var godot_bin := ""
var cap := Capture.new()
var autoload_names: Array[String] = []

var busy := false
var jobs_done := 0
var quit_after := false
var _poll_t := 0.0
var _beat_ms := -100000
var _log: FileAccess

# script bookkeeping
var _mtime := {}        # res path (.gd/.tscn/.tres…) → modified time seen
var _text := {}         # .gd path → source
var _cname := {}        # .gd path → class_name ("" none)
var _status := {}       # .gd path → true (compiles) / false
var _statics := {}      # .gd path → {static var → default value}
var _class_set := ""    # sorted class_name list at start-up (a change needs a restart)
var _asset_seen := {}   # asset path → source mtime already imported (or tried)
var _restart_reason := ""

# ------------------------------------------------------------------ start-up

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot --headless --path <project> -s tools/daemon.gd -- <queue dir> [render]")
		quit(2)
		return
	q = args[0].trim_suffix("/")
	render = args.size() > 1 and args[1] == "render"
	proj = ProjectSettings.globalize_path("res://")
	godot_bin = OS.get_executable_path()
	for d in ["jobs", "running", "done", "tmp"]: DirAccess.make_dir_recursive_absolute(q.path_join(d))
	_log = FileAccess.open(q.path_join("daemon.log"), FileAccess.READ_WRITE if FileAccess.file_exists(q.path_join("daemon.log")) else FileAccess.WRITE)
	if _log: _log.seek_end()
	Engine.max_fps = 10
	if render: RenderingServer.render_loop_enabled = false # the daemon draws nothing; children render
	for p in ProjectSettings.get_property_list():
		var n: String = p.name
		if n.begins_with("autoload/"): autoload_names.append(n.trim_prefix("autoload/"))
	if not render: root.size = Vector2i(1920, 1080)
	OS.add_logger(cap)
	DirAccess.remove_absolute(q.path_join("busy"))
	for f in DirAccess.get_files_at(q.path_join("running")): DirAccess.remove_absolute(q.path_join("running").path_join(f))
	_clean_done(3600)
	var t := Time.get_ticks_msec()
	_index_all()
	_heartbeat(true)
	log_line("start pid %d %s, %d scripts indexed and loaded in %d ms, %d broken, %d classes" % [OS.get_process_id(),
		"render" if render else "headless", _text.size(), Time.get_ticks_msec() - t, _broken().size(),
		_class_set.count(",") + 1])

## Loads every project script once (this is the start-up cost the daemon saves later) and records static defaults.
func _index_all() -> void:
	var names: Array[String] = []
	for p in _files("res://", ["gd"] + RESOURCE_EXT):
		_mtime[p] = FileAccess.get_modified_time(p)
		if not p.ends_with(".gd"): continue
		_text[p] = FileAccess.get_file_as_string(p)
		_cname[p] = _class_name_of(_text[p])
		_scan_text(p, _text[p])
		if _cname[p] != "": names.append(_cname[p])
	names.sort()
	_class_set = ",".join(names)
	# the engine knows the global classes the last import wrote; one missing (the start-up import was skipped
	# because the lock stayed busy) means jobs must run in a child process after an import, then a restart
	var known := {}
	for c in ProjectSettings.get_global_class_list(): known[str(c["class"])] = true
	var missing := names.filter(func(n): return not known.has(n))
	if not missing.is_empty():
		_restart_reason = "global class cache is stale (%s…): no import at start-up" % missing[0]
	cap.paused = true
	for p in _text:
		if p == SELF: _status[p] = true; continue
		var s = load(p)
		_status[p] = _compiles(s)
	cap.paused = false
	for p in _text:
		var s = ResourceLoader.get_cached_ref(p) if ResourceLoader.has_cached(p) else null
		if s is GDScript: _statics[p] = _static_values(s)

# ------------------------------------------------------------------ main loop

func _process(delta: float) -> bool:
	_heartbeat()
	if busy or quit_after: return false
	_poll_t += delta
	if _poll_t < POLL_S: return false
	_poll_t = 0.0
	var jobs := DirAccess.get_files_at(q.path_join("jobs"))
	var names: Array[String] = []
	for f in jobs:
		if f.ends_with(".json"): names.append(f)
	if names.is_empty(): return false
	names.sort()
	var src := q.path_join("jobs").path_join(names[0])
	var dst := q.path_join("running").path_join(names[0])
	if DirAccess.rename_absolute(src, dst) != OK: return false # the client took it back
	var job = JSON.parse_string(FileAccess.get_file_as_string(dst))
	if not (job is Dictionary): job = {"id": names[0].get_basename(), "cmd": "?", "args": []}
	if not job.has("id"): job.id = names[0].get_basename()
	_run_job(job, dst)
	return false

func _heartbeat(force := false) -> void:
	if quit_after: return
	var now := Time.get_ticks_msec()
	if not force and now - _beat_ms < HEARTBEAT_MS: return
	_beat_ms = now
	var f := FileAccess.open(q.path_join("alive"), FileAccess.WRITE)
	if f: f.store_string("%d %s\n" % [OS.get_process_id(), "render" if render else "headless"])

func _run_job(job: Dictionary, running_path: String) -> void:
	busy = true
	var id := str(job.id)
	var cmd := str(job.get("cmd", ""))
	var args: Array = job.get("args", [])
	_heartbeat(true)
	var bf := FileAccess.open(q.path_join("busy"), FileAccess.WRITE)
	if bf: bf.store_string("%d %s %d\n" % [OS.get_process_id(), id, int(Time.get_unix_time_from_system())]); bf = null
	var t0 := Time.get_ticks_msec()
	if FileAccess.get_modified_time(SELF) != _mtime.get(SELF, -1) and _restart_reason == "":
		_restart_reason = "tools/daemon.gd changed" # this job still runs on the old code
	cap.start()
	var code := 1
	if not cmd in ["ping", "restart"]:
		await _ensure_imported()
	match cmd:
		"ping":
			print("pong %s pid %d, %d jobs done, rss %d MB, up %d s" % ["render" if render else "headless",
				OS.get_process_id(), jobs_done, _rss_kb() / 1024, Time.get_ticks_msec() / 1000])
			code = 0
		"check": code = await _job_check(args)
		"test": code = await _job_test(args)
		"shot": code = await _job_shot(job)
		"reload": code = _job_reload(args)
		"restart":
			print("restarting (systemd starts a new process in ~5 s)")
			_restart_reason = "restart job"
			code = 0
		_:
			print("unknown command '%s' (ping, check, test, shot, reload, restart)" % cmd)
			code = 2
	var text := cap.stop()
	_write_done(id, text, code)
	DirAccess.remove_absolute(running_path)
	jobs_done += 1
	var ms := Time.get_ticks_msec() - t0
	var rss := _rss_kb()
	log_line("job %s %s %s → %d in %.1f s (rss %d MB)" % [id, cmd, " ".join(args), code, ms / 1000.0, rss / 1024])
	if jobs_done >= MAX_JOBS and _restart_reason == "": _restart_reason = "%d jobs" % jobs_done
	if rss > MAX_RSS_KB and _restart_reason == "": _restart_reason = "rss %d MB" % (rss / 1024)
	if jobs_done % 20 == 0: _clean_done(3600)
	_heartbeat(true)
	DirAccess.remove_absolute(q.path_join("busy"))
	busy = false
	if _restart_reason != "":
		log_line("quit for restart: " + _restart_reason)
		quit_after = true
		DirAccess.remove_absolute(q.path_join("alive")) # clients fall back at once until the new process is up
		quit(0)

func _write_done(id: String, text: String, code: int) -> void:
	var d := q.path_join("done")
	var f := FileAccess.open(d.path_join(id + ".out.tmp"), FileAccess.WRITE)
	if f: f.store_string(text + ("\n" if text != "" and not text.ends_with("\n") else "")); f = null
	DirAccess.rename_absolute(d.path_join(id + ".out.tmp"), d.path_join(id + ".out"))
	f = FileAccess.open(d.path_join(id + ".code.tmp"), FileAccess.WRITE)
	if f: f.store_string("%d\n" % code); f = null
	DirAccess.rename_absolute(d.path_join(id + ".code.tmp"), d.path_join(id + ".code"))

func log_line(s: String) -> void:
	var line := "%s %s" % [Time.get_datetime_string_from_system(false, true), s]
	if _log: _log.store_line(line); _log.flush()
	var was := cap.paused
	cap.paused = true # the daemon's own notes stay out of the job output (same output as a direct run)
	print("[daemon] " + s)
	cap.paused = was

# ------------------------------------------------------------------ commands

func _job_check(args: Array) -> int:
	_world_teardown()
	if args.has("--full"): _reload_all()
	var sync := _sync_scripts(true)
	if sync.restart:
		_world_setup(true)
		return await _child_godot(["--headless", "--path", proj, "-s", "tools/check.gd"], 300, true)
	# scripts that do not compile (and were not just recompiled): again, so their errors show in this job's output
	for p in _broken():
		if not _reloaded_now.has(p): _reload_one(p)
	_world_setup(true)
	var bad: Array[String] = []
	var n := 0
	for root in CHECK_ROOTS:
		for p in _files(root, ["gd"]):
			n += 1
			if not _status.get(p, false): bad.append(p)
	if bad.is_empty():
		print("CHECK OK %d scripts" % n)
		return 0
	for p in bad: print("CHECK FAIL " + p)
	return 1

func _job_test(args: Array) -> int:
	var filter := ""
	for i in args.size():
		if str(args[i]) == "--filter" and i + 1 < args.size(): filter = str(args[i + 1])
	_world_teardown()
	var sync := _sync_scripts()
	if sync.restart:
		_world_setup(true)
		var a := ["--headless", "--path", proj, "-s", "tests/run.gd", "--"]
		a.append_array(args)
		return await _child_godot(a, 600, true)
	_world_setup(false) # fresh, not-ready autoloads: what tests see inside a fresh run.gd's _initialize
	var runner = load("res://tests/suite_runner.gd")
	var code := 1
	if runner == null or not runner.can_instantiate():
		print("FAIL  tests/suite_runner.gd does not compile")
	else:
		var r: Dictionary = runner.run(filter)
		print(r.text)
		code = 1 if r.failed > 0 else 0
	_world_teardown()
	_world_setup(true)
	return code

## shot [godot args…] <tools/x.gd> [--] [args…]: the tool in a child Godot on this daemon's display.
func _job_shot(job: Dictionary) -> int:
	if not render:
		print("shot: only the render daemon runs tool scripts (jobs.sh --render shot …)")
		return 2
	var args: Array = job.get("args", [])
	var gargs: Array = job.get("godot_args", [])
	var i := 0
	while i < args.size() and not str(args[i]).ends_with(".gd"):
		gargs.append(args[i]); i += 1
	if i >= args.size():
		print("shot: no tool script (shot [godot args…] tools/x.gd [args…])")
		return 2
	var script := str(args[i])
	var rest := args.slice(i + 1)
	if not rest.is_empty() and str(rest[0]) == "--": rest = rest.slice(1)
	var a := ["--path", proj, "--rendering-driver", "opengl3", "--audio-driver", "Dummy"]
	a.append_array(gargs)
	a.append_array(["-s", script, "--"])
	a.append_array(rest)
	var timeout := int(job.get("timeout", 300))
	return await _child_godot(a, timeout, false, str(job.get("cwd", proj)))

func _job_reload(args: Array) -> int:
	_world_teardown()
	if args.has("--all"):
		_reload_all()
	var sync := _sync_scripts(true)
	_world_setup(true)
	print("reloaded %d scripts%s, %d broken" % [sync.reloaded, " (all)" if args.has("--all") else "", _broken().size()])
	if sync.restart: print("class_name set changed: restarting after this job")
	return 0

# ------------------------------------------------------------------ child processes

## Runs godot with `a` in a child process (output into this job's output); keeps the heartbeat going.
func _child_godot(a: Array, timeout_s: int, headless_note: bool, cwd := "") -> int:
	if headless_note:
		# a new global class: the child needs the class cache the import writes
		log_line("running in a child process (%s)" % _restart_reason)
		await _child(_import_cmd(), proj)
	var parts := ["timeout", str(timeout_s), godot_bin]
	parts.append_array(a)
	var r := await _child(_shell(parts), cwd if cwd != "" else proj)
	if r.out != "": print(r.out.trim_suffix("\n"))
	return r.code

## bash -c `command` in `cwd`, polled each frame; returns {code, out}.
func _child(command: String, cwd: String) -> Dictionary:
	var tag := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var out := q.path_join("tmp").path_join(tag + ".out")
	var code_f := q.path_join("tmp").path_join(tag + ".code")
	var line := "cd %s && { %s ; } > %s 2>&1; echo $? > %s.part && mv %s.part %s" % [_q(cwd), command, _q(out),
		_q(code_f), _q(code_f), _q(code_f)]
	var pid := OS.create_process("bash", ["-c", line])
	if pid <= 0: return {"code": 1, "out": "[daemon] could not start bash"}
	while not FileAccess.file_exists(code_f):
		await process_frame
		if not OS.is_process_running(pid) and not FileAccess.file_exists(code_f):
			await create_timer(0.2).timeout
			if not FileAccess.file_exists(code_f): break
	var code := int(FileAccess.get_file_as_string(code_f).strip_edges()) if FileAccess.file_exists(code_f) else 1
	var text := FileAccess.get_file_as_string(out) if FileAccess.file_exists(out) else ""
	DirAccess.remove_absolute(out)
	DirAccess.remove_absolute(code_f)
	return {"code": code, "out": text}

func _shell(parts: Array) -> String:
	var s := PackedStringArray()
	for p in parts: s.append(_q(str(p)))
	return " ".join(s)

func _q(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

# ------------------------------------------------------------------ imports

## The import, under the shared lock but never waiting more than LOCK_WAIT_S for it (a caller that holds the lock
## while it waits for this daemon would otherwise dead-lock): exit 75 = the lock was busy, nothing imported.
func _import_cmd() -> String:
	return "flock -w %d -E 75 %s timeout 600 %s" % [LOCK_WAIT_S, _q(LOCK), _shell([godot_bin, "--headless", "--path", proj, "--import"])]

## Assets under art/ and data/ without a .import, or newer than it, are imported by a child Godot (with the lock).
func _ensure_imported() -> void:
	var stale: Array[String] = []
	for root in ASSET_ROOTS:
		for p in _files(root, IMPORTABLE):
			var m := FileAccess.get_modified_time(p)
			if _asset_seen.get(p, -1) == m: continue
			var imp := p + ".import"
			if not FileAccess.file_exists(imp) or m > FileAccess.get_modified_time(imp): stale.append(p)
			else: _asset_seen[p] = m
	if stale.is_empty(): return
	var t := Time.get_ticks_msec()
	var r := await _child(_import_cmd(), proj)
	var log_f := FileAccess.open(q.path_join("import.log"), FileAccess.WRITE)
	if log_f: log_f.store_string(r.out)
	if r.code == 75:
		# the lock stayed busy: try again before the next job; say so in this job's output
		print("[daemon] WARNING: %s was busy for %d s, %d changed asset(s) not imported yet (%s…)" % [LOCK, LOCK_WAIT_S,
			stale.size(), stale[0].get_file()])
		log_line("import skipped: lock busy for %d s" % LOCK_WAIT_S)
		return
	var replaced := 0
	for p in stale:
		_asset_seen[p] = FileAccess.get_modified_time(p)
		if ResourceLoader.has_cached(p):
			ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE); replaced += 1
	log_line("imported %d changed asset(s) (%s…) in %.1f s, exit %d, %d cached reloaded" % [stale.size(),
		stale[0].get_file(), (Time.get_ticks_msec() - t) / 1000.0, r.code, replaced])

# ------------------------------------------------------------------ script reload

## Reloads every script changed since the last job in place, with the scripts that depend on it (see _closure).
## deep (check): also every script that depends on those, transitively, for every change since the last deep
## sync, so a check lists the same failures as a fresh tools/check.gd. Returns {reloaded, restart}; restart = the
## global class set changed (this process cannot learn new class_names).
func _sync_scripts(deep := false) -> Dictionary:
	var changed: Array[String] = []
	var res_changed: Array[String] = []
	var seen := {}
	var self_changed := false
	_reloaded_now.clear()
	for p in _files("res://", ["gd"] + RESOURCE_EXT):
		seen[p] = true
		var m := FileAccess.get_modified_time(p)
		if _mtime.get(p, -1) == m: continue
		_mtime[p] = m
		if p == SELF: self_changed = true
		if p.ends_with(".gd"): changed.append(p)
		else: res_changed.append(p)
	for p in _mtime.keys():
		if not seen.has(p):
			_mtime.erase(p)
			if p.ends_with(".gd"):
				_text.erase(p); _status.erase(p); _statics.erase(p); _scan.erase(p); _pending_deep.erase(p)
				if _cname.get(p, "") != "": _restart_reason = "class_name removed: " + p
				_cname.erase(p)
	for p in changed:
		_text[p] = FileAccess.get_file_as_string(p)
		var cn := _class_name_of(_text[p])
		if cn != _cname.get(p, ""):
			_restart_reason = "class_name changed in %s (%s → %s)" % [p.get_file(), _cname.get(p, ""), cn]
		_cname[p] = cn
		_scan_text(p, _text[p])
		if p != SELF: _pending_deep[p] = true
	if self_changed and _restart_reason == "": _restart_reason = "tools/daemon.gd changed"
	var names: Array[String] = []
	for p in _cname:
		if _cname[p] != "": names.append(_cname[p])
	names.sort()
	if ",".join(names) != _class_set and _restart_reason == "": _restart_reason = "class_name set changed"
	var need_child := _restart_reason != "" and _restart_reason != "tools/daemon.gd changed" and _restart_reason != "restart job"
	var reloaded := 0
	var roots: Array[String] = []
	if deep:
		for p in _pending_deep: roots.append(p)
	else:
		roots = changed.filter(func(x): return x != SELF)
	if not roots.is_empty() and not need_child:
		var t_c := Time.get_ticks_msec()
		var order := _closure(roots, deep)
		var t_r := Time.get_ticks_msec()
		_in_use.clear()
		for p in order:
			_reload_one(p)
			_reloaded_now[p] = true
		reloaded = order.size()
		if deep: _pending_deep.clear()
		_reload_ms = "closure %d ms, reload %d ms" % [t_r - t_c, Time.get_ticks_msec() - t_r]
		log_line("reloaded %d scripts%s in %s (%d changed: %s%s)%s" % [reloaded, " (deep)" if deep else "", _reload_ms,
			roots.size(), ", ".join(roots.slice(0, 4).map(func(x): return x.get_file())), "…" if roots.size() > 4 else "",
			"; with live instances: " + ", ".join(_in_use) if not _in_use.is_empty() else ""])
	if self_changed: _status[SELF] = _compiles(ResourceLoader.load(SELF, "GDScript", ResourceLoader.CACHE_MODE_IGNORE))
	for p in res_changed:
		if ResourceLoader.has_cached(p): ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
	return {"reloaded": reloaded, "restart": need_child}

## What to reload for a set of changed scripts, bases before subclasses:
##   the changed scripts; every script that names one of them (class_name, autoload name, res:// path or file
##   name), since constants and enums are inlined at compile time and compile errors show there; and, transitively,
##   every script that extends one of those (member layout). Users of users are not recompiled for a test (calls
##   resolve by name at run time; only a constant chain through two scripts would be missed); deep (check)
##   follows users transitively too, like a fresh compile of everything would.
func _closure(changed: Array[String], deep := false) -> Array[String]:
	var name_of := {}   # class / autoload name → path
	for p in _cname:
		if _cname[p] != "": name_of[_cname[p]] = p
	for a in autoload_names:
		name_of[a] = str(ProjectSettings.get_setting("autoload/" + a, "")).trim_prefix("*")
	# reverse index: path → scripts that name it; base path → subclasses
	var users := {}
	var subs := {}
	for f in _text:
		if f == SELF: continue
		var sc: Dictionary = _scan.get(f, {})
		var hit := {}
		for w in sc.get("words", {}):
			if name_of.has(w): hit[name_of[w]] = true
		for t in sc.get("paths", {}):
			if _text.has(t): hit[t] = true
		for t in hit:
			if t != f: (users.get_or_add(t, []) as Array).append(f)
		var base := _base_path(f, name_of)
		if base != "": (subs.get_or_add(base, []) as Array).append(f)
	var inset := {}
	var rank := {}
	var queue: Array[String] = []
	for p in changed:
		if p != SELF and _text.has(p) and not inset.has(p): inset[p] = true; rank[p] = 0; queue.append(p)
	var i := 0
	while i < queue.size():
		var p := queue[i]
		i += 1
		if rank[p] == 0 or deep:
			for u in users.get(p, []):
				if not inset.has(u): inset[u] = true; rank[u] = 1; queue.append(u)
		for u in subs.get(p, []):
			if not inset.has(u): inset[u] = true; rank[u] = 2; queue.append(u)
	var order: Array[String] = []
	for p in inset: order.append(p)
	var depth := {}
	for p in order: depth[p] = _depth(p, name_of)
	order.sort_custom(func(a, b): return depth[a] < depth[b] or (depth[a] == depth[b] and rank[a] < rank[b]))
	return order

## Identifiers (capitalised words) and script paths a script mentions, and what it extends.
func _scan_text(p: String, text: String) -> void:
	if _re_word == null:
		_re_word = RegEx.create_from_string("\\b[A-Z][A-Za-z0-9_]*")
		_re_path = RegEx.create_from_string("[\"'](res://[^\"']+?\\.gd|[^\"'/\\s]+\\.gd)[\"']")
		_re_ext = RegEx.create_from_string("(?m)^extends\\s+(?:[\"']([^\"']+)[\"']|([A-Za-z_]\\w*))")
	var words := {}
	for m in _re_word.search_all(text): words[m.get_string()] = true
	var paths := {}
	for m in _re_path.search_all(text):
		var t := m.get_string(1)
		paths[t if t.begins_with("res://") else p.get_base_dir().path_join(t).simplify_path()] = true
	var ext := ""
	var em := _re_ext.search(text)
	if em != null:
		ext = em.get_string(1)
		if ext != "" and not ext.begins_with("res://"): ext = p.get_base_dir().path_join(ext).simplify_path()
		if ext == "": ext = "@" + em.get_string(2)  # a class name (resolved later)
	_scan[p] = {"words": words, "paths": paths, "ext": ext}

func _base_path(p: String, name_of: Dictionary) -> String:
	var ext: String = _scan.get(p, {}).get("ext", "")
	if ext.begins_with("@"): return name_of.get(ext.substr(1), "")
	return ext

func _depth(p: String, name_of: Dictionary) -> int:
	var d := 0
	var cur := p
	while d < 32:
		cur = _base_path(cur, name_of)
		if cur == "" or not _text.has(cur): break
		d += 1
	return d

var _scan := {}       # .gd path → {words, paths, ext}
var _pending_deep := {}  # changed since the last deep (check) sync
var _reloaded_now := {}  # reloaded by the last sync
var _re_word: RegEx
var _re_path: RegEx
var _re_ext: RegEx
var _reload_ms := ""
var _in_use: Array[String] = []   # scripts reloaded with live instances during the last sync

## Recompiles a script in place (the same object: users keep their reference). Fresh statics when it has no
## live instances; otherwise its state is kept (reload(true)).
func _reload_one(p: String) -> void:
	if p == SELF: return
	var s = ResourceLoader.get_cached_ref(p) if ResourceLoader.has_cached(p) else null
	if s == null:
		s = load(p) # first load (new file, or it never compiled): errors go to the job output
		_status[p] = _compiles(s)
		if s is GDScript: _statics[p] = _static_values(s)
		return
	if not (s is GDScript): return
	s.source_code = FileAccess.get_file_as_string(p)
	cap.paused = true
	var err: int = s.reload(false)
	cap.paused = false
	if err == ERR_ALREADY_IN_USE:
		_in_use.append(p.get_file())
		err = s.reload(true)
	elif err != OK:
		err = s.reload(false) # again, so the parse errors reach the output
	_status[p] = err == OK
	if err == OK: _statics[p] = _static_values(s)

func _reload_all() -> void:
	var all: Array[String] = []
	for p in _text: if p != SELF: all.append(p)
	_world_teardown()
	_in_use.clear()
	for p in all: _reload_one(p)
	for p in all: _reload_one(p) # a second pass: everything compiled against the new versions
	log_line("reloaded all %d scripts%s" % [all.size(), "; with live instances: " + ", ".join(_in_use) if not _in_use.is_empty() else ""])
	_in_use.clear()

func _compiles(s) -> bool:
	return s is Script and ((s as Script).can_instantiate() or (s as Script).is_abstract())

func _broken() -> Array[String]:
	var out: Array[String] = []
	for p in _status:
		if not _status[p]: out.append(p)
	return out

func _class_name_of(text: String) -> String:
	var re := RegEx.create_from_string("(?m)^(?:@\\w+(?:\\([^)]*\\))?\\s+)*class_name\\s+([A-Za-z_]\\w*)")
	var m := re.search(text)
	return m.get_string(1) if m else ""

# ------------------------------------------------------------------ world reset (between runs)

## Takes the autoloads' script instances away (their nodes stay: the global names point at them), frees stray
## nodes, puts static vars back to their defaults. Afterwards almost no script has live instances, so reloads
## are clean.
func _world_teardown() -> void:
	paused = false
	Engine.time_scale = 1.0
	for tw in get_processed_tweens(): tw.kill()
	# lambdas and script methods left connected to the tree / root by a run would outlive a reload of their script
	for o in [self, root]:
		for sig in o.get_signal_list():
			for c in o.get_signal_connection_list(sig.name):
				var cb: Callable = c.callable
				var tgt: Object = cb.get_object()
				if tgt == self: continue
				if cb.is_custom() or (tgt != null and tgt.get_script() != null):
					o.disconnect(sig.name, cb)
	if current_scene != null:
		var cs := current_scene
		current_scene = null
		if is_instance_valid(cs): cs.free()
	for c in root.get_children():
		if not autoload_names.has(String(c.name)): c.free()
	for a in autoload_names:
		var n := root.get_node_or_null(a)
		if n == null: continue
		_disconnect_all(n)
		for c in n.get_children(): c.free()
		n.set_meta("_daemon_script", n.get_script())
		n.set_script(null)
	_reset_statics()

## Gives the autoloads fresh script instances (fresh GameApp, SaveData…), in autoload order. ready = also run
## their _ready like a start-up does (the in-process test run gets them not ready, as inside run.gd's _initialize).
func _world_setup(ready: bool) -> void:
	# headless windows are 64×64 (visible rect 1920×1920 with the project's stretch); a fresh run.gd's tests run
	# outside the tree, where nodes fall back to 1920×1080: give /root that size
	if not render: root.size = Vector2i(1920, 1080)
	for a in autoload_names:
		var n := root.get_node_or_null(a)
		if n == null: continue
		var s = n.get_meta("_daemon_script") if n.has_meta("_daemon_script") else n.get_script()
		if s == null:
			var path := str(ProjectSettings.get_setting("autoload/" + a, "")).trim_prefix("*")
			if path.ends_with(".gd"): s = load(path)
		if n.has_meta("_daemon_script"): n.remove_meta("_daemon_script")
		if s != null and n.get_script() == null: n.set_script(s)
	if ready:
		for a in autoload_names:
			var n := root.get_node_or_null(a)
			if n != null and n.has_method("_ready"): n.call("_ready")

func _disconnect_all(n: Object) -> void:
	for sig in n.get_signal_list():
		for c in n.get_signal_connection_list(sig.name):
			if n.is_connected(sig.name, c.callable): n.disconnect(sig.name, c.callable)
	for c in n.get_incoming_connections():
		var src: Object = c.signal.get_object()
		if src != null and src.is_connected(c.signal.get_name(), c.callable): src.disconnect(c.signal.get_name(), c.callable)

func _static_values(s: GDScript) -> Dictionary:
	var out := {}
	for p in s.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = s.get(p.name)
			out[p.name] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return out

## Static vars back to the values they had right after their script compiled. Non-null object defaults (shared
## instances like TerrainDef.Ground) are kept as they are; loggers held in statics are removed from the engine.
func _reset_statics() -> void:
	for p in _statics:
		var s = ResourceLoader.get_cached_ref(p) if ResourceLoader.has_cached(p) else null
		if not (s is GDScript): continue
		var defaults: Dictionary = _statics[p]
		for k in defaults:
			var d = defaults[k]
			if d is Object and d != null: continue
			var cur = s.get(k)
			if cur is Logger and cur != cap: OS.remove_logger(cur)
			s.set(k, d.duplicate(true) if (d is Array or d is Dictionary) else d)

# ------------------------------------------------------------------ helpers

func _files(dir: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null: return out
	d.include_hidden = false
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with(".") and f != "reference": out.append_array(_files(dir.path_join(f), exts))
		elif exts.has(f.get_extension().to_lower()):
			out.append(dir.path_join(f))
		f = d.get_next()
	return out

func _rss_kb() -> int:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	while f != null and not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("VmRSS:"): return int(l.trim_prefix("VmRSS:").strip_edges().split(" ")[0])
	return 0

func _clean_done(max_age_s: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	for sub in ["done", "tmp"]:
		var d := q.path_join(sub)
		for f in DirAccess.get_files_at(d):
			var p := d.path_join(f)
			if now - FileAccess.get_modified_time(p) > maxi(max_age_s, 3600): DirAccess.remove_absolute(p)
