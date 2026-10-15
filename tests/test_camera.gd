extends TestCase
## The board camera's turn rule (user, 2026-10-14): a 90° turn keeps the zoom distance and the pan, only clamping
## them to the new angle's limits (zoom-out limit = the fit for that angle). The fit is the board centred, whatever
## the pan; the reference tile (board UI size) is the default framing's and a turn leaves it alone. Headless, no
## rendering (the camera's projection maths only).

var _world: Node3D
var _keep_ref := 104.0

func setup() -> void:
	_keep_ref = WorldUi.reference_tile
	_world = Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world)

func teardown() -> void:
	_world.free()
	WorldUi.reference_tile = _keep_ref

func _cam(w: int, h: int) -> BoardCamera:
	var cam := BoardCamera.new()
	_world.add_child(cam)
	cam.init(w, h)
	return cam

func test_camera_rotated_distance_rule() -> void:
	assert_num(BoardCamera.rotated_distance(8.0, 3.0, 12.0), 8.0, "inside the new limit: untouched")
	assert_num(BoardCamera.rotated_distance(12.0, 3.0, 15.0), 12.0, "a farther new limit never zooms out")
	assert_num(BoardCamera.rotated_distance(15.0, 3.0, 12.0), 12.0, "beyond the new limit: clamped to it")
	assert_num(BoardCamera.rotated_distance(2.0, 3.0, 12.0), 3.0, "never closer than the closest zoom")

func test_camera_turn_keeps_zoom_and_pan() -> void:
	var cam := _cam(12, 6)
	var fit0 := cam.max_distance
	assert_num(cam.distance_target, fit0, "starts at the fit")
	var fit90 := cam.fit_distance(90.0)
	assert_true(fit90 > fit0 + 0.1, "a long board seen lengthwise needs more distance (%.2f vs %.2f)" % [fit90, fit0])
	# zoomed in and panned by the player
	cam.distance_target = fit0 * 0.6
	cam._free_pan = true
	cam.focus_target = Vector3(8.0, 0.0, -2.0)
	var ref := WorldUi.reference_tile
	cam.rotate_step(1)
	assert_num(cam.yaw_target, 90.0)
	assert_num(cam.distance_target, fit0 * 0.6, "the turn keeps the zoom")
	assert_eq(cam.focus_target, Vector3(8.0, 0.0, -2.0), "the turn keeps the pan")
	assert_num(snappedf(cam.max_distance, 0.0001), snappedf(fit90, 0.0001), "the zoom-out limit is the new angle's fit")
	assert_num(WorldUi.reference_tile, ref, "plates keep their size across a turn")
	cam.rotate_step(-1)
	assert_num(cam.distance_target, fit0 * 0.6, "and back: still the same zoom")

func test_camera_turn_at_the_fit_only_clamps() -> void:
	var cam := _cam(12, 6)
	var fit0 := cam.max_distance
	cam.rotate_step(1)
	assert_num(cam.distance_target, fit0, "zoomed out at 0°: the farther 90° limit does not zoom out")
	cam.distance_target = cam.max_distance # zoomed all the way out at 90°
	cam.rotate_step(1)
	assert_num(snappedf(cam.distance_target, 0.0001), snappedf(cam.fit_distance(180.0), 0.0001), "beyond the 180° limit: clamped to it")
	assert_true(cam.distance_target < cam.fit_distance(90.0), "pulled in")

func test_camera_strict_pan_clamped_to_the_new_limits() -> void:
	var cam := _cam(12, 6)
	cam.distance_target = cam.max_distance * 0.8
	var d := cam.distance_target
	cam.focus_target = cam.clamp_strict(Vector3(100.0, 0.0, 100.0)) # a glide as far as the zoom allows
	cam.rotate_step(1)
	assert_eq(cam.focus_target, cam.clamp_strict(cam.focus_target), "the focus inside the new angle's pan limits")
	assert_num(cam.distance_target, d, "zoom untouched")

func test_camera_fit_ignores_the_pan() -> void:
	var cam := _cam(10, 7)
	var fit := cam.fit_distance()
	cam.focus = Vector3(9.0, 0.0, -6.0)
	assert_num(snappedf(cam.fit_distance(), 0.0001), snappedf(fit, 0.0001), "the fit is the board centred, wherever the focus is")

## Where the 8 board corners (ground and model height) land on screen, in canvas pixels, at the camera's frame now.
## Projected by hand from the camera's pose (focus, distance, pitch, yaw) and its off-centre frustum, as apply() sets
## them: the direct test run (tests/run.gd) runs before the root window is in the tree, where unproject_position fails.
func _corners_on_screen(cam: BoardCamera) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var size := cam._view_size()
	var aspect := size.x / size.y
	var b := Basis.from_euler(Vector3(deg_to_rad(-cam.pitch), deg_to_rad(cam.yaw), 0.0))
	var inv := Transform3D(b, cam.focus + b.z * cam.distance).affine_inverse()
	var h := 2.0 * cam.near * tan(deg_to_rad(cam.fov) * 0.5)
	var free := cam.free_area()
	var off := Vector2((0.5 - free.get_center().x) * h * aspect, (0.5 - (1.0 - free.get_center().y)) * h)
	for i in 8:
		var cx := cam.bounds.position.x if (i & 1) == 0 else cam.bounds.end.x
		var cz := -cam.bounds.position.y if (i & 2) == 0 else -cam.bounds.end.y
		var v: Vector3 = inv * Vector3(cx, 0.0 if (i & 4) == 0 else BoardCamera.MODEL_HEIGHT, cz)
		var n := Vector2(v.x, v.y) * cam.near / -v.z # on the near plane
		var ndc := Vector2((n.x - off.x) / (h * aspect * 0.5), (n.y - off.y) / (h * 0.5))
		out.append(Vector2((ndc.x + 1.0) * 0.5 * size.x, (1.0 - ndc.y) * 0.5 * size.y))
	return out

## Settles the smoothing at once (the targets become the frame).
func _settle(cam: BoardCamera) -> void:
	cam.yaw = cam.yaw_target
	cam.distance = cam.distance_target
	cam.focus = cam.focus_target

## 2026-10-15: a tall board turned 90° — the zoom-out limit's frame keeps the whole board inside the free area
## (clear of the top bar, the tray and End turn), with no refit on the turn itself.
func test_camera_tall_board_turned_limit_keeps_board_clear_of_hud() -> void:
	var cam := _cam(5, 14)
	cam.set_hud_insets(HudLayout.TOP_BAR, HudLayout.TRAY_H, 0.0) # what the HUD sends
	var d0 := cam.distance_target
	cam.rotate_step(1)
	assert_num(cam.distance_target, minf(d0, cam.max_distance), "the turn does not refit (only clamps)")
	cam.distance_target = cam.max_distance # zoomed all the way out at 90°
	cam.focus_target = cam.clamp_focus(cam.focus_target)
	_settle(cam)
	var size := cam._view_size()
	var free := cam.free_area()
	var box := Rect2(free.position * size, free.size * size).grow(1.0)
	for p in _corners_on_screen(cam):
		assert_true(box.has_point(p), "corner %s inside the free area %s" % [p, box])
	# the end-turn button's rect and the tray stay clear of the board
	if cam.is_inside_tree(): # the hand projection agrees with Godot's (in the resident runner, where the tree is up)
		cam.apply()
		var mine := _corners_on_screen(cam)
		for i in 8:
			var cx := cam.bounds.position.x if (i & 1) == 0 else cam.bounds.end.x
			var cz := -cam.bounds.position.y if (i & 2) == 0 else -cam.bounds.end.y
			var g := cam.unproject_position(Vector3(cx, 0.0 if (i & 4) == 0 else BoardCamera.MODEL_HEIGHT, cz))
			assert_true(g.distance_to(mine[i]) < 1.0, "corner %d: %s by hand, %s by Godot" % [i, mine[i], g])
	var end_turn := HudLayout.end_turn_rect(size)
	for p in _corners_on_screen(cam):
		assert_true(p.y < end_turn.position.y + 0.5 or p.x < end_turn.position.x, "corner %s clear of End turn" % p)

## A free pan at the zoom-out limit: a turn that clamps the zoom to the new limit brings the board back to the centre
## (the limit's frame), so nothing of it stays under the HUD.
func test_camera_turn_clamped_to_limit_recentres_a_free_pan() -> void:
	var cam := _cam(5, 14)
	cam.distance_target = cam.max_distance
	cam._free_pan = true
	cam.focus_target = cam.clamp_focus(Vector3(4.5, 0.0, -13.5))
	assert_true(cam.fit_distance(90.0) < cam.max_distance, "the tall board seen across needs less distance")
	cam.rotate_step(1)
	assert_num(cam.distance_target, cam.max_distance, "clamped to the new limit")
	assert_eq(cam.focus_target, cam.board_centre(), "at the new limit: centred")
	# zoomed in and panned, a turn keeps the pan
	cam.distance_target = cam.max_distance * 0.5
	cam._free_pan = true
	cam.focus_target = Vector3(4.5, 0.0, -13.5)
	cam.rotate_step(1)
	assert_eq(cam.focus_target, Vector3(4.5, 0.0, -13.5), "inside the new limit: the pan is kept")
