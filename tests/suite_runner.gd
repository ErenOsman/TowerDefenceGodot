extends RefCounted
## The test suite's discovery / run / summary logic, shared by tests/run.gd (one Godot process per run) and the
## resident job runner tools/daemon.gd (in-process runs). No class_name on purpose: a new global class needs an
## editor import before a running Godot knows it, so both callers load this file by path.
##   var r: Dictionary = load("res://tests/suite_runner.gd").run(filter)
##   r.text   → "", the FAIL lines, then "---- N passed, M failed (K test methods in F files)" (print it as is)
##   r.failed → number of failed test methods (exit code 1 when > 0); also r.passed, r.methods, r.files
## Runs every test_* method of every res://tests/test_*.gd (TestCase subclasses). A test script that does not
## compile counts as one failure ("could not load (parse error?)"). A GDScript runtime error inside a test prints
## an error (see the log) but the run continues.

static func run(filter: String = "") -> Dictionary:
	var files := find_tests("res://tests")
	files.sort()
	var passed := 0
	var failed := 0
	var failures: Array[String] = []
	var ran_methods := 0
	for path in files:
		if filter != "" and not path.get_file().contains(filter) and not has_method_matching(path, filter):
			continue
		var script = load(path)
		# a script that was loaded before and no longer compiles stays cached but cannot instantiate
		if script == null or not (script as Script).can_instantiate():
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
	var lines: Array[String] = [""]
	for f in failures: lines.append("FAIL  " + f)
	lines.append("---- %d passed, %d failed (%d test methods in %d files)" % [passed, failed, ran_methods, files.size()])
	return {"text": "\n".join(lines), "failed": failed, "passed": passed, "methods": ran_methods, "files": files.size()}

static func find_tests(dir: String) -> Array[String]:
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

static func has_method_matching(path: String, filter: String) -> bool:
	var s = load(path)
	if s == null: return false
	for m in s.get_script_method_list():
		if String(m.name).contains(filter): return true
	return false
