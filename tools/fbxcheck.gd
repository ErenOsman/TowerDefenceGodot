extends SceneTree
func _initialize() -> void:
	var bad := []
	var ok := 0
	for dir in ["res://art/models", "res://art/tiles", "res://art/camp"]:
		var d := DirAccess.open(dir)
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".fbx"):
				var s = load(dir + "/" + f)
				if s == null: bad.append(f)
				else:
					ok += 1
					var n = s.instantiate()
					var anims := []
					for c in n.find_children("*", "AnimationPlayer", true, false): anims.append_array(c.get_animation_list())
					if dir.ends_with("models"): print(f, " anims=", anims.size(), " muzzle=", n.find_child("Muzzle", true, false) != null)
			f = d.get_next()
	print("OK ", ok, " BAD ", bad)
	quit()
