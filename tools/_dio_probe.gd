extends SceneTree
func _initialize(): _run.call_deferred()
func _run():
	var app = root.get_node("GameApp")
	var vp := SubViewport.new(); vp.size = Vector2i(1600, 500); vp.own_world_3d = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var r := Node3D.new(); vp.add_child(r)
	TdDiorama._add_light(r, Color(0.3,0.3,0.3))
	var names = ["Campfire", "Codex Lectern", "Miniature Shelf", "Signal Post", "Supplies", "Tent", "Tower Workshop", "War Table"]
	for i in names.size():
		var sc = app.camp_scene(names[i])
		var m: Node3D = sc.instantiate(); r.add_child(m); m.position = Vector3(i * 3.0 - 10.5, 0, 0)
		var aabb := AABB(); var first := true
		for n in m.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = n.global_transform * n.get_aabb()
			aabb = b if first else aabb.merge(b); first = false
		print(names[i], " ", aabb)
	var cam := Camera3D.new(); r.add_child(cam); cam.position = Vector3(0, 3, 10); cam.look_at(Vector3(0, 0.3, 0)); cam.fov = 70; cam.current = true
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("/tmp/claude-1001/-home-ubuntu-claude/6782c35d-6c38-58ad-9ee3-e8ad88840f64/scratchpad/menus/props.png")
	quit()
