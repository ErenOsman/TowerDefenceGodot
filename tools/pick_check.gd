extends SceneTree
## Checks board picking: warps the real pointer to known tile centres and asserts the level's hovered tile (and
## GridSpace.tile_under at the pointer) is that tile; then renders one PNG with the pointer over a tile and a
## crosshair drawn where the pointer is. Run at sizes other than the project's 1920×1080:
##   ~/godot/run.sh projects/td --resolution 1600x900 -s tools/pick_check.gd -- <out.png> [hud]
## Prints PICK OK / PICK FAIL lines and "PICK SUMMARY n/m".

var level: LevelController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://pick.png"
	var sd = root.get_node_or_null("SaveData")
	if sd != null:
		sd.path = "user://pick_check.json"
		sd.data = GameData.new()
		sd.data.profile.create("Tester")
	level = (load("res://game/level/level.tscn") as PackedScene).instantiate()
	level.test_level_id = "chapter1-1"
	if not args.has("hud"): level.hud_scene_path = ""
	root.add_child(level)
	for i in 6: await process_frame
	level.skip_sequence()
	for i in 90: await process_frame # banners and the camera settle
	var cam := level.camera
	var grid := level.session.state.grid
	print("window ", DisplayServer.window_get_size(), " visible rect ", root.get_visible_rect().size, " frustum offset ", cam.frustum_offset)
	var tiles := [Vector2i(0, 0), Vector2i(grid.width - 1, 0), Vector2i(0, grid.height - 1), Vector2i(grid.width - 1, grid.height - 1),
		Vector2i(grid.width / 2, grid.height / 2), Vector2i(2, 1), Vector2i(grid.width - 3, grid.height - 2)]
	var ok := 0
	for t in tiles:
		var s := cam.unproject_position(GridSpace.to_world(t))
		root.warp_mouse(s)
		for i in 3: await process_frame
		var mouse := root.get_mouse_position()
		var under = GridSpace.tile_under(cam, mouse, grid)
		var direct = GridSpace.tile_under(cam, s, grid)
		var good: bool = level.hover == t and under == t and direct == t
		if good: ok += 1
		print("PICK %s tile %s screen %s mouse %s -> hover %s, at mouse %s, at screen point %s" % ["OK" if good else "FAIL", t, s, mouse, level.hover, under, direct])
	print("PICK SUMMARY %d/%d" % [ok, tiles.size()])
	# points near tile edges (0.4 from the centre): the refined ground point vs Godot's plain ray (which ignores
	# the frustum offset)
	var edge_ok := 0
	var edge_n := 0
	var worst_plain := 0.0
	var worst := 0.0
	for t in tiles:
		for off in [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]:
			var w: Vector3 = GridSpace.to_world(t) + off
			var s := cam.unproject_position(w)
			var g = GridSpace.ground_under(cam, s)
			var o := cam.project_ray_origin(s)
			var n := cam.project_ray_normal(s)
			var plain := o + n * ((0.0 - o.y) / n.y)
			worst_plain = maxf(worst_plain, plain.distance_to(w))
			worst = maxf(worst, (g as Vector3).distance_to(w) if g != null else 99.0)
			edge_n += 1
			if GridSpace.tile_under(cam, s, grid) == t: edge_ok += 1
	print("PICK EDGES %d/%d  worst error: refined %.4f tiles, Godot's plain ray %.4f tiles" % [edge_ok, edge_n, worst, worst_plain])
	# the picture: pointer over a tile, a crosshair where the pointer is
	var target := Vector2i(2, 1)
	root.warp_mouse(cam.unproject_position(GridSpace.to_world(target)))
	var layer := CanvasLayer.new()
	layer.layer = 100
	var mark := Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		var p := root.get_mouse_position()
		mark.draw_line(p - Vector2(24, 0), p + Vector2(24, 0), Color.MAGENTA, 3)
		mark.draw_line(p - Vector2(0, 24), p + Vector2(0, 24), Color.MAGENTA, 3)
		mark.draw_arc(p, 8, 0, TAU, 24, Color.MAGENTA, 2))
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(mark)
	root.add_child(layer)
	for i in 4: await process_frame
	mark.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out, " hover ", level.hover)
	quit()
