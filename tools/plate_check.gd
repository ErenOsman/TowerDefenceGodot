extends SceneTree
## Headless check (no rendering) of what needs a live scene tree: the board plate's HP bar animation against Unity's
## UI_HealthBar numbers (fill 0.3 s smoothstep at once; ghost white 35 % waits 0.3 s then drains in 0.6 s; heal:
## green ghost jumps ahead, fill follows after 0.3 s), the plate anchor following a unit, and the camera's turn rule
## with a real projection (zoom and pan kept, reference tile kept).
##   godot --headless --path . -s tools/plate_check.gd
## Prints PLATE OK / PLATE FAIL lines and "PLATE SUMMARY n/m"; exit code 1 on a failure.

var _ok := 0
var _all := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, what: String) -> void:
	_all += 1
	if cond: _ok += 1
	print(("PLATE OK   " if cond else "PLATE FAIL ") + what)

func _frame(hp: int) -> EntityFrame:
	var f := EntityFrame.new()
	f.has_hp = true
	f.hp = hp
	f.max_hp = 20
	f.life = LifeState.Alive
	return f

## Shows the frame every step (as PlateLayer does) and advances the bar by dt (its own _process is off: fixed steps).
func _steps(p: KitPlate, hp: int, n: int, dt := 0.05) -> void:
	for i in n:
		p.show_frame(_frame(hp))
		p.status.health_bar._process(dt)

func _run() -> void:
	# ---- the bar's animation
	var p := KitPlate.new()
	root.add_child(p)
	await process_frame
	p.set_form(false, 90.0, 1.0, false)
	p.show_frame(_frame(20))
	var bar := p.status.health_bar
	bar.set_process(false)
	_steps(p, 10, 1)
	_steps(p, 10, 4) # 0.25 s
	_check(bar.get_display_fill() < 0.55, "0.25 s after a hit the fill is nearly down (%.3f)" % bar.get_display_fill())
	_check(is_equal_approx(bar._ghost_v, 1.0) and bar._ghost.visible, "the ghost holds the old HP behind the fill (%.3f)" % bar._ghost_v)
	_check(bar._ghost.self_modulate == Color(1, 1, 1, 0.35), "the ghost is Unity's white at 35 %% (%s)" % bar._ghost.self_modulate)
	_steps(p, 10, 2) # 0.35 s
	_check(is_equal_approx(bar.get_display_fill(), 0.5), "the fill is down in 0.3 s (%.3f)" % bar.get_display_fill())
	_steps(p, 10, 6) # 0.65 s: the ghost half way (waited 0.3, 0.35 of 0.6 drained)
	_check(bar._ghost_v < 0.95 and bar._ghost_v > 0.5, "the ghost drains after its 0.3 s wait (%.3f)" % bar._ghost_v)
	_steps(p, 10, 8) # 1.05 s
	_check(is_equal_approx(bar._ghost_v, 0.5) and not bar._ghost.visible, "the ghost is gone after 0.9 s (%.3f)" % bar._ghost_v)
	_steps(p, 18, 1)
	_check(bar._ghost.visible and bar._ghost.self_modulate == Color(0.3, 1, 0.5, 0.35) and is_equal_approx(bar._ghost_v, 0.9), "a heal: the green ghost jumps ahead")
	_steps(p, 18, 5) # 0.3 s: the fill still waiting
	_check(bar.get_display_fill() < 0.55, "the healed fill waits 0.3 s (%.3f)" % bar.get_display_fill())
	_steps(p, 18, 8)
	_check(is_equal_approx(bar.get_display_fill(), 0.9), "then fills in 0.3 s (%.3f)" % bar.get_display_fill())
	var c: Color = bar._fill.self_modulate
	_check(c.is_equal_approx(TdHealthBar.gradient_for(0.9, Color(0.9, 0.15, 0.15), Color(0.95, 0.85, 0.15), Color(0.2, 0.85, 0.3))), "the fill colour is Unity's gradient (%s)" % c)
	p.set_health_preview(6)
	_check(bar._preview.visible, "a previewed hit stripes the lost part")
	p.free()

	# ---- the camera turn with a real projection
	var world := Node3D.new()
	root.add_child(world)
	var cam := BoardCamera.new()
	world.add_child(cam)
	cam.set_process(false)
	cam.init(12, 6)
	await process_frame
	var ref := WorldUi.reference_tile
	cam.distance_target = cam.max_distance * 0.6
	cam.distance = cam.distance_target
	cam.apply()
	var zoom_before := WorldUi.zoom(cam, cam.focus)
	cam.rotate_step(1)
	_check(is_equal_approx(cam.distance_target, cam.distance), "a turn keeps the zoom distance")
	_check(is_equal_approx(WorldUi.reference_tile, ref), "a turn keeps the reference tile (plates keep their size)")
	cam.set_hud_insets(96.0, 308.0, 0.0)
	_check(absf(WorldUi.reference_tile - ref) < ref * 0.4, "the HUD changing while zoomed in measures the default framing (%.1f vs %.1f)" % [WorldUi.reference_tile, ref])
	_check(WorldUi.zoom(cam, cam.focus) > 1.2, "zoomed in, the plates stay bigger after it (zoom %.2f, was %.2f)" % [WorldUi.zoom(cam, cam.focus), zoom_before])

	# ---- the anchor follows the unit
	var f := EntityFrame.new()
	f.id = 1
	f.kind = EntityKind.Unit
	f.pos = Vector2i(3, 2)
	var view := EntityView.create(world, f, null)
	var a := view.plate_screen_position(cam)
	var centre := cam.unproject_position(view.global_position + Vector3.UP * view.height * 0.5)
	var top := cam.unproject_position(view.global_position + Vector3.UP * view.height)
	_check(a.z > 0.0 and is_equal_approx(a.x, centre.x) and a.y < top.y, "the anchor is over the head, on the body's screen x")
	var off := Vector2(a.x, a.y) - centre
	view.position += Vector3(0.37, 0, 0)
	var a2 := view.plate_screen_position(cam)
	var centre2 := cam.unproject_position(view.global_position + Vector3.UP * view.height * 0.5)
	_check((Vector2(a2.x, a2.y) - centre2).distance_to(off) < 1.0, "mid-step the anchor keeps its offset over the head (no jump)")
	world.free()

	print("PLATE SUMMARY %d/%d" % [_ok, _all])
	quit(0 if _ok == _all else 1)
