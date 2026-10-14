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
