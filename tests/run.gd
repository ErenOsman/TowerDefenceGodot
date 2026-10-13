extends SceneTree
## Test runner: godot --headless --path . -s tests/run.gd [--filter name]
## Runs every test_* method of every res://tests/test_*.gd (TestCase subclasses). Exit code 1 on failures.
## A GDScript runtime error inside a test prints an error (see the log) but the run continues; such a test
## is counted as an error when its script printed one (watch for "SCRIPT ERROR" lines).

func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--filter" and i + 1 < args.size(): filter = args[i + 1]
	var files := _find_tests("res://tests")
	files.sort()
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var ran_methods := 0
	for path in files:
		if filter != "" and not path.get_file().contains(filter) and not _has_method_matching(path, filter):
			continue
		var script = load(path)
		if script == null:
			failures.append("%s: could not load (parse error?)" % path); failed += 1
			continue
		var inst = script.new()
		if not (inst is TestCase):
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"): continue
			if filter != "" and not name.contains(filter) and not path.get_file().contains(filter): continue
			ran_methods += 1
			inst._current = "%s.%s" % [path.get_file().get_basename(), name]
			var before: int = inst._failures.size()
			inst.setup()
			inst.call(name)
			inst.teardown()
			if inst._failures.size() == before:
				passed += 1
			else:
				failed += 1
		for f in inst._failures: failures.append(f)
	print("")
	for f in failures: print("FAIL  " + f)
	print("---- %d passed, %d failed (%d test methods in %d files)" % [passed, failed, ran_methods, files.size()])
	quit(1 if failed > 0 else 0)

func _find_tests(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null: return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
		f = d.get_next()
	return out

func _has_method_matching(path: String, filter: String) -> bool:
	var s = load(path)
	if s == null: return false
	for m in s.get_script_method_list():
		if String(m.name).contains(filter): return true
	return false
