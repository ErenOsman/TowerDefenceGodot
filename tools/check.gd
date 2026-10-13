extends SceneTree
## Loads every .gd under res://sim, res://tests, res://game and res://tools so parse errors show up.
## godot --headless --path . -s tools/check.gd   → prints "CHECK OK <n> scripts" or the failing paths; exit 1 on errors.

func _initialize() -> void:
	var bad: Array[String] = []
	var n := 0
	for root in ["res://sim", "res://tests", "res://game", "res://tools"]:
		for p in _scripts(root):
			n += 1
			var s = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
			if s == null or not (s as GDScript).can_instantiate() and not _is_abstract_ok(s):
				bad.append(p)
	if bad.is_empty():
		print("CHECK OK %d scripts" % n)
		quit(0)
	else:
		for p in bad: print("CHECK FAIL " + p)
		quit(1)

func _is_abstract_ok(s) -> bool:
	# a script that fails to compile cannot instantiate; one that compiled can (RefCounted/Object based)
	return s != null and (s as GDScript).reload() == OK

func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null: return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."): out.append_array(_scripts(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = d.get_next()
	return out
