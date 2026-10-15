extends SceneTree
func _initialize() -> void:
	for m in ["Archer", "Slime Glutton", "Base"]:
		var inst = load("res://art/models/%s.fbx" % m).instantiate()
		var rig := EntityRig.new(inst.find_child("AnimationPlayer", true, false))
		print("%s: Attack impact %.3f s (key %.1f, table %.3f, clip %.2f) · Cast %.3f" % [m, rig.impact_time("Attack"), rig.impact_key_time("Attack"), rig.impact_table_time("Attack"), rig.clip_length("Attack", 0.5), rig.impact_time("Cast")])
		inst.free()
	quit(0)
