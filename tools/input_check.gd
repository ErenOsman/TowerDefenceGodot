extends SceneTree
## Proofs for the board's input and plates (prints CHECK lines; PNG crops for the decals):
##   ~/godot/run.sh projects/td [--resolution 1600x900] -s tools/input_check.gd -- <out dir>
##  1. plate centring: a unit's plate x before hovering it, while hovered (full), after (compact again) — equal.
##  2. drag: a scripted left-drag (warp + synthetic button / motion events) moves the camera focus; a press and
##     release without moving is still a click (it selects the unit under it).
##  3. HP bars (Unity's rule): idle none; hovered → bar; a hit → bar for 1.5 s, then none; a death → drains, gone.
##  4. decals: the same aimed shot with the plain kit outlines and with the reinforced ones (before / after crops).

var level: LevelController
var out_dir := "user://checks"
var fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1
	print("CHECK %s %s" % ["OK" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n: await process_frame

func _settle() -> void:
	for i in 900:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _wait_seconds(sec: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < sec: await process_frame

func _run() -> void:
	var sd = root.get_node_or_null("SaveData")
	if sd != null:
		sd.path = "user://input_check.json"
		sd.data = GameData.new()
		sd.data.profile.create("Tester")
		sd.data.settings.always_show_health = false
		sd.data.settings.drag_to_pan = true
	level = (load("res://game/level/level.tscn") as PackedScene).instantiate()
	level.test_level_id = "chapter2-1"
	level.test_hand = PackedStringArray(["archer", "archer"])
	level.hud_scene_path = "" # the board alone: nothing over it takes the pointer
	root.add_child(level)
	await _frames(6)
	level.skip_sequence()
	await _settle()
	await _wait_seconds(2.0) # opening banners go
	var s := level.session
	var cam := level.camera
	# place the archers
	var tiles := []
	for x in s.state.grid.width:
		for y in s.state.grid.height:
			if tiles.size() < 2 and s.can_place(s.hand[0].id, Vector2i(x, y)) and (tiles.is_empty() or absi(tiles[0].x - x) + absi(tiles[0].y - y) == 1 or tiles.size() == 0):
				tiles.append(Vector2i(x, y))
	for i in tiles.size():
		level.toggle_placing(s.hand[i].id)
		level.click_tile(tiles[i])
		await _settle()
	level.select(-1)
	level.hover_override = Vector2i(-9, -9)
	await _frames(4)
	var archer: Entity = s.placed_tower(s.hand[0].id)

	# ---- 3a. idle: no HP bars (rocks, bases, towers)
	var any_bar := false
	for id in level.views.all: any_bar = any_bar or level.overlay.plates.bar_shown(id)
	_check(not any_bar, "idle: no HP bar on any unit or rock")

	# ---- 1. plate centring before / hovered / after
	var plate = level.overlay.plates.plate_of(archer.id)
	var before_centre := _plate_centre(plate)
	level.hover_override = archer.pos
	await _frames(4)
	var during := _plate_centre(plate)
	_check(level.overlay.plates.bar_shown(archer.id), "hovered: its HP bar shows")
	level.hover_override = Vector2i(-9, -9)
	await _frames(4)
	var after := _plate_centre(plate)
	print("plate centre x: before %.1f, hovered %.1f, after %.1f (the unit's plate point %.1f)" % [before_centre.x, during.x, after.x, level.view_of(archer.id).plate_screen_position(cam).x])
	_check(absf(before_centre.x - after.x) < 0.5 and absf(before_centre.x - during.x) < 0.5, "plate stays centred on the unit (compact → full → compact)")

	# ---- 2. drag: a press that moves pans; a press that does not is a click (the real pointer picks the tile)
	level.hover_override = null
	var focus0 := cam.focus
	var a := cam.unproject_position(GridSpace.to_world(Vector2i(s.state.grid.width / 2, 1)))
	await _mouse_button(a, true)
	for k in 12:
		var p := a + Vector2(-14.0 * (k + 1), -4.0 * (k + 1))
		root.warp_mouse(p)
		var ev := InputEventMouseMotion.new()
		ev.position = p
		ev.global_position = p
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(ev)
		await _frames(2)
	await _mouse_button(a + Vector2(-168, -48), false)
	await _frames(20)
	var moved := cam.focus.distance_to(focus0)
	print("drag moved the focus %.3f tiles (%s → %s), left_dragged %s" % [moved, focus0, cam.focus, cam.left_dragged])
	_check(moved > 0.3, "a left-drag pans the camera at the default zoom")
	_check(level.selected < 0, "the drag's release did not click (nothing selected)")
	var at := cam.unproject_position(level.view_of(archer.id).global_position)
	await _mouse_button(at, true)
	await _frames(2)
	await _mouse_button(at, false)
	await _frames(4)
	_check(level.selected == archer.id, "a press and release without moving still clicks (selects the archer)")
	level.select(-1)
	level.hover_override = Vector2i(-9, -9)

	# ---- 3b. a hit on a rock: bar for health_bar_after_hit seconds of overlay time, then gone. (The overlay counts
	# unscaled frame time capped at 0.1 s per frame, so on this slow software renderer it runs behind the wall clock:
	# the check reads the plate layer's own timer.)
	level.hover_override = Vector2i(-9, -9)
	var plates := level.overlay.plates
	var rock: Entity = null
	for e in s.state.entities:
		if e.alive and e.has_hp and not s.is_commanded(e) and e.hp > 3: rock = e
	if rock != null:
		var fx := DamageEffect.new()
		fx.amount = Formula.new("1")
		fx.target_id = rock.id
		fx.source = 0
		s.resolver.run(fx)
		await _settle()
		await _frames(2)
		_check(plates.bar_shown(rock.id), "after a hit on %s: its bar shows" % rock.name)
		var start := Time.get_ticks_msec()
		while plates.bar_shown(rock.id) and Time.get_ticks_msec() - start < 30000: await process_frame
		var timer: float = plates._since_hit.get(rock.id, -1.0)
		print("the bar went after %.2f s of overlay time" % timer)
		_check(not plates.bar_shown(rock.id) and timer >= PresentationTimings.get_timings().health_bar_after_hit and timer < PresentationTimings.get_timings().health_bar_after_hit + 0.3, "the bar goes %.1f s after the hit" % PresentationTimings.get_timings().health_bar_after_hit)
	# ---- 3c. a death (an enemy: its corpse stays a Dead frame): the bar drains, then the plate goes
	for r in 6:
		if s.enemies.size() > 0: break
		level.instant_override = true
		level.end_round()
		await _settle()
		level.instant_override = false
	var foe: Entity = s.enemies[0] if s.enemies.size() > 0 else null
	if foe == null: print("no enemy came")
	else:
		await _wait_seconds(0.5)
		var kill := DamageEffect.new()
		kill.amount = Formula.new("9999")
		kill.target_id = foe.id
		kill.source = 0
		s.resolver.run(kill)
		var saw_dying := false
		var start2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start2 < 30000:
			await process_frame
			var f: EntityFrame = level.shown.get_frame(foe.id)
			if f != null and f.life == LifeState.Dead and plates.bar_shown(foe.id): saw_dying = true
			if saw_dying and plates.plate_of(foe.id) == null: break
		_check(saw_dying, "dying %s: its bar shows, draining" % foe.name)
		_check(plates.plate_of(foe.id) == null, "after the drain: its plate is gone")

	# ---- 4. decals before / after
	var shoot: AbilityDef = null
	for ab in archer.abilities:
		if not ab.targeting.is_movement: shoot = ab
	await _settle()
	level.select(archer.id)
	level.preview_ability(archer, shoot) # its range and valid targets, as when its button is hovered
	level.hover_override = Vector2i(-9, -9)
	var centre := cam.unproject_position(level.view_of(archer.id).global_position)
	var crop := Rect2i(Vector2i(centre) - Vector2i(380, 230), Vector2i(760, 400))
	level.reinforce_outlines = false
	await _frames(4)
	await _save_crop("decals_before", crop)
	level.reinforce_outlines = true
	await _frames(4)
	await _save_crop("decals_after", crop)
	# a walk's reach and route (the move decals)
	var walk: AbilityDef = null
	for ab in archer.abilities:
		if ab.targeting.is_movement: walk = ab
	level.preview_ability(null, null)
	if walk != null:
		level.toggle_aim(walk)
		var reach := AimPreview.range(s.state, archer.id, walk)
		if reach.size() > 0: level.hover_override = reach[reach.size() - 1]
		level.reinforce_outlines = false
		await _frames(4)
		await _save_crop("move_before", crop)
		level.reinforce_outlines = true
		await _frames(4)
		await _save_crop("move_after", crop)
	print("CHECK SUMMARY %s (%d failed)" % ["OK" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)

func _plate_centre(plate) -> Vector2:
	var c: Control = plate.status if "status" in plate else plate
	var w: float = 164.0 if ("status" in plate and plate.status.full) else (plate.status.plate_width if "status" in plate else 0.0)
	return c.global_position + Vector2(w * plate.scale.x * 0.5, 0)

func _mouse_button(p: Vector2, pressed: bool) -> void:
	root.warp_mouse(p)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)
	await _frames(2)

func _save_crop(n: String, r: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var size := img.get_size()
	var scale := Vector2(size) / root.get_visible_rect().size
	var rr := Rect2i(Vector2i(Vector2(r.position) * scale), Vector2i(Vector2(r.size) * scale)).intersection(Rect2i(Vector2i.ZERO, size))
	var path := out_dir.path_join(n + ".png")
	img.get_region(rr).save_png(path)
	print("saved ", path)
