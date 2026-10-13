extends SceneTree
## Headless-render proof of the battle HUD over the level (like level_shot.gd): the intro dialogue, the idle turn with
## the hand, placing, a selected tower (action bar, inspector, an ability tooltip), aiming, an enemy selected (its
## "Next" line), End turn hovered, the pause menu, the Info window and the end screen. Saves PNGs.
##   ~/godot/run.sh projects/td -s tools/hud_shot.gd -- <level id> <out dir> [prefix]
##   ~/godot/run.sh projects/td --resolution 1280x720 -s tools/hud_shot.gd -- chapter1-1 /tmp/shots small
## The save is pointed at user://hud_shot.json (the real save is untouched).

var level_id := "chapter1-1"
var out_dir := "user://shots"
var prefix := "hud"
var level: LevelController
var hud: Hud

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: level_id = args[0]
	if args.size() > 1: out_dir = args[1]
	if args.size() > 2: prefix = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	var sd = root.get_node_or_null("SaveData")
	if sd != null:
		sd.path = "user://hud_shot.json"
		sd.data = GameData.new()
		sd.data.profile.create("Tester")
		sd.data.settings.always_show_health = false
	var scene: PackedScene = load("res://game/level/level.tscn")
	level = scene.instantiate()
	level.test_level_id = level_id
	level.test_hand = PackedStringArray(["archer", "archer", "mage", "cannon", "priest"])
	level.instant_override = false
	root.add_child(level)
	await _frames(4)
	if level.setup_error != null:
		print("SETUP ERROR: ", level.setup_error)
		quit(1)
		return
	hud = level.hud as Hud
	if hud == null:
		print("NO HUD")
		quit(1)
		return
	_park_mouse()
	await _frames(30)
	await _shot("0_intro")
	if level.is_tutorial:
		await _tutorial()
		return
	level.skip_sequence()
	await _settle()
	await _frames(20)
	await _shot("1_idle")

	# placing: the piece lifts, the bar shows the tower's abilities without casting, the card shows it
	var hand: Array = level.session.hand
	level.toggle_placing(hand[0].id)
	await _frames(20)
	await _shot("2_placing")
	var tiles := _build_tiles_near_path(2)
	level.click_tile(tiles[0])
	await _settle()
	level.toggle_placing(hand[1].id)
	level.click_tile(tiles[1])
	await _settle()

	# a selected tower: action bar, inspector, and the first ability's tooltip above the bar
	var archer: Entity = level.session.placed_tower(hand[0].id)
	level.select(archer.id)
	await _frames(10)
	var b: TdButton = hud.action_bar.button(0)
	if b != null:
		_hover_control(b)
		await _until_tooltip()
		_report_tail("ability 1", b)
	await _shot("3_selected_tooltip")
	_park_mouse()
	await _frames(5)

	# hover a hand piece that cannot be afforded and click it (shake + reason)
	var poor := _piece_for("cannon")
	if poor != null:
		_hover_control(poor)
		await _until_tooltip()
		_report_tail("piece", poor)
		await _shot("4_piece_tooltip")
		poor._gui_input(_release())
		await _frames(6)
		await _shot("4b_piece_denied")
	_park_mouse()

	# fast-forward rounds with Instant on until an enemy is in an archer's range
	var shoot: AbilityDef = null
	for a in archer.abilities:
		if not a.targeting.is_movement: shoot = a
	for i in 8:
		if _has_target(archer, shoot): break
		level.instant_override = true
		level.end_round()
		await _settle()
	level.instant_override = false
	await _frames(4)

	# aiming: the ability's look, the hint line under the bar
	level.select(archer.id)
	level.toggle_aim(shoot)
	var aims: Array = Targeting.valid_aims(level.session.state, archer.id, shoot)
	if aims.size() > 0: _hover_tile(aims[0].tile)
	await _frames(10)
	await _shot("5_aiming")
	level.toggle_aim(shoot)
	# two abilities on cooldown: cast both, then look at the bar
	level.select(archer.id)
	level.quick_cast(shoot)
	await _settle()
	for ab in archer.abilities:
		if ab.targeting.is_movement:
			level.select(archer.id)
			var walks: Array = Targeting.valid_aims(level.session.state, archer.id, ab)
			if walks.size() > 0:
				level.toggle_aim(ab)
				level.click_tile(walks[walks.size() - 1].tile)
				await _settle()
	level.select(archer.id)
	_hover_tile(Vector2i(-5, -5))
	level.hover_override = null
	await _frames(10)
	await _shot("5b_cooldowns")
	_hover_tile(Vector2i(-5, -5))
	level.hover_override = null

	# an enemy selected: the enemy card with its abilities and the Next line
	var enemies: Array = level.session.enemies
	if enemies.size() > 0:
		level.select(enemies[0].id)
		await _frames(10)
		await _shot("6_enemy")
		hud.open_info(enemies[0].id)
		await _wait(0.5)
		await _shot("6b_enemy_info")
		hud.info.close()
		await _wait(0.4)
	level.select(-1)
	await _frames(5)

	# End turn hovered: the enemy phase on the board, the tooltip
	_hover_control(hud.top_bar.end_turn)
	await _until_tooltip()
	await _shot("7_end_turn_hover")
	_park_mouse()
	await _frames(5)

	# Skip with nothing to skip: the denied reason opens below it
	_hover_control(hud.top_bar._skip)
	await _frames(3)
	hud.top_bar._skip.simulate_click()
	await _wait(0.5)
	await _shot("7b_skip_denied")
	_park_mouse()
	await _frames(5)

	# the enemy phase: three frames in a row of the End turn button (it must not flicker)
	level.select(-1)
	Engine.time_scale = 0.3
	level.end_round()
	await _frames(20)
	var et := hud.top_bar.end_turn.get_global_rect().grow(30)
	for k in 3:
		await _frames(1)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var r := Rect2i(Vector2i(et.position * Vector2(root.size) / root.get_visible_rect().size), Vector2i(et.size * Vector2(root.size) / root.get_visible_rect().size))
		img.get_region(r).save_png(out_dir.path_join("%s_7c_enemy_end_turn_%d.png" % [prefix, k]))
		print("enemy frame ", k, " phase ", level.shown.phase, " busy ", level.director.busy, " key ", hud.top_bar.end_turn.get("_key").visible)
	Engine.time_scale = 1.0
	await _settle()

	# the tower's Info window
	if archer.alive:
		hud.open_info(archer.id)
		await _wait(0.5)
		await _shot("8_tower_info")
		hud.info.close()
		await _wait(0.4)

	# pause
	level.select(archer.id if archer.alive else -1)
	hud.open_pause()
	await _wait(0.5)
	await _shot("9_pause")
	print("time scale while paused: ", Engine.time_scale)
	hud.pause.close()
	await _wait(0.4)
	print("time scale after: ", Engine.time_scale)

	# play to the end with Instant on
	level.select(-1)
	level.instant_override = true
	for i in 60:
		if level.session.is_over: break
		level.end_round()
		await _settle()
	await _wait(1.0)
	await _shot("10_end_screen")
	print("outcome ", level.session.outcome, " round ", level.session.round, " panel open ", level.ui_panel_open)
	quit(0)

## The guided tutorial (GuidedTutorial, data/tutorial.json): the piece (t2), the lit tiles (t3), the archer (t5),
## Tower Walk (t6a) and its tile (t6b), Shoot (t8a), the slime (t8b) and a refused click (t8c).
## tools/tutorial_shot.gd runs this with the tutorial level; `tutorial_short` stops after t6b.
var tutorial_short := false

func _tutorial() -> void:
	var g: GuidedTutorial = level.guided
	if g == null:
		print("NO GUIDED TUTORIAL")
		quit(1)
		return
	level.continue_sequence()
	await _frames(20)
	await _shot("t1b_castle")
	level.continue_sequence()
	await _frames(40)
	await _shot("t2_piece")
	level.toggle_placing(level.session.hand[0].id)
	_hover_tile(Vector2i(10, 3))
	await _frames(40)
	await _shot("t3_tiles")
	level.click_tile(Vector2i(10, 1))
	_hover_tile(Vector2i(-5, -5))
	level.hover_override = null
	_park_mouse()
	await _settle()
	await _frames(10)
	level.end_round()
	await _settle()
	await _frames(50)
	print("step ", g.index, " selected ", level.selected)
	await _shot("t5_select")
	var archer := g.archer()
	level.click_tile(archer.pos)
	await _settle()
	await _frames(40)
	await _shot("t6a_walk_button")
	level.toggle_aim(g.ability("Tower Walk"))
	var walk = g.walk_tile()
	_hover_tile(walk)
	await _frames(40)
	print("step ", g.index, " (7 = the walk tile)")
	await _shot("t6b_walk_tile")
	if tutorial_short:
		quit(0)
		return
	level.click_tile(walk)
	_hover_tile(Vector2i(-5, -5))
	level.hover_override = null
	await _settle()
	# End turn until the slime is in range (Instant on to get there)
	level.instant_override = true
	for i in 20:
		if g.index != 8: break
		level.end_round()
		await _settle()
		await _frames(3)
	level.instant_override = false
	level.select(archer.id)
	await _frames(50)
	print("step ", g.index, " (9 = Click Shoot)")
	await _shot("t8a_shoot_button")
	level.toggle_aim(g.ability("Shoot"))
	var slime := g.first_enemy()
	if slime != null: _hover_tile(slime.pos)
	await _frames(40)
	await _shot("t8b_shoot_target")
	level.click_tile(Vector2i(8, 0)) # not the slime: refused, the bubble says what was wrong and shakes
	await _frames(3)
	await _shot("t8c_refused")
	print("refusals ", g.refusals, " says '", g.last_hint, "'")
	quit(0)

## Waits until the hover tooltip shows (up to 8 s; slow machines), then a few frames for its fade.
func _until_tooltip() -> void:
	var until := Time.get_ticks_msec() + 8000
	while not TdTooltip.is_visible() and Time.get_ticks_msec() < until: await process_frame
	await _wait(0.4)

func _report_tail(what: String, c: Control) -> void:
	var box := TdTooltip.box()
	var tail: Control = box.get("_tail")
	var t := tail.get_global_rect().get_center().x if tail != null and tail.visible else -1.0
	print("%s: anchor centre %.1f  tail centre %.1f  box %.1f..%.1f" % [what, c.get_global_rect().get_center().x, t, box.get_global_rect().position.x, box.get_global_rect().end.x])

func _frames(n: int) -> void:
	for i in n: await process_frame

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func _settle() -> void:
	for i in 900:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join("%s_%s.png" % [prefix, n])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

## Moves the pointer onto a control (canvas → window coordinates) and tells the GUI.
func _hover_control(c: Control) -> void:
	_move_mouse(c.get_global_rect().get_center())

func _park_mouse() -> void:
	_move_mouse(Vector2(960, 300))

## Canvas (1920×1080 reference) → window pixels.
func _to_window(p: Vector2) -> Vector2:
	return p * Vector2(root.size) / root.get_visible_rect().size

## Moves the pointer to a canvas point: warp in viewport coordinates, the motion event in window pixels.
func _move_mouse(p: Vector2) -> void:
	root.warp_mouse(p)
	var win := _to_window(p)
	var ev := InputEventMouseMotion.new()
	ev.position = win
	ev.global_position = win
	Input.parse_input_event(ev)

func _release() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = Vector2(60, 60)
	return ev

func _piece_for(tower_type: String) -> HudHandPiece:
	for p in hud.tray._pieces:
		var t: TowerDef = level.session.tower(p.tower_id)
		if t != null and t.type != null and t.type.id == tower_type: return p
	return null

func _build_tiles_near_path(n: int) -> Array:
	var s := level.session
	var path: Array = s.state.grid.paths[0].tiles if s.state.grid.paths.size() > 0 else []
	var options := []
	for x in s.state.grid.width:
		for y in s.state.grid.height:
			var p := Vector2i(x, y)
			if not s.can_place(s.hand[0].id, p): continue
			var best := 999
			for t in path: best = mini(best, absi(t.x - p.x) + absi(t.y - p.y))
			options.append([best, -y, x, p])
	options.sort()
	var out := []
	for o in options:
		if out.size() >= n: break
		out.append(o[3])
	return out

func _has_target(unit: Entity, a: AbilityDef) -> bool:
	if a == null: return false
	for aim in Targeting.valid_aims(level.session.state, unit.id, a):
		var t: Entity = Instinct.target_of(level.session.state, a, aim)
		if t != null and level.session.enemies.has(t): return true
	return false

func _hover_tile(p: Vector2i) -> void:
	level.hover_override = p
	root.warp_mouse(level.camera.unproject_position(GridSpace.to_world(p)))
