extends "res://tools/qa/qa_base.gd"
## In-level UI QA tour with real input (qa_base.gd has the checks). One scenario per run (each is a few minutes of
## llvmpipe frames):
##   /home/ubuntu/godot/jobs.sh --render shot [--resolution 1280x720] tools/qa/level_tour.gd -- <out dir> <scenario> [prefix]
##   scenarios: hud (chapter 1-1: hovers, placing, aiming, cancel, refusals) · turns (End turn, enemy card, Info,
##   pause and its sub-screens, Skip) · camera (zoom / pan / rotate limits, drag-to-pan, plates at both zooms, HP bar
##   speed, Always Show Health) · end (a real win and a loss: end screens) · tutorial (every guided step the allowed
##   way plus a wrong action at each, Skip) · ch2 (The Drummer: enemy abilities, statuses) · mission (GameApp.play_mission
##   through SceneFlow, its end screen) · coop (stub relay: Pass, tracker, wait reasons) · intro (a level intro in the box)
##   · edge (wrong inputs: keys 1–9 past the last ability, double clicks on a piece / tile / ability / End turn,
##   Esc and right-click chains, Enter and P in the enemy phase, the wheel at its limits while placing and over the
##   HUD, the window resized to 1280×720 and back mid-level)
## Uses its own save (user://qa_tour.json); the real save is untouched.

var scenario := "hud"
var level_id := "chapter1-1"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "user://qa"
	scenario = args[1] if args.size() > 1 else "hud"
	var p := args[2] if args.size() > 2 else scenario
	qa_setup(dir, p)
	_run.call_deferred()

func _save(always_health := false) -> void:
	var sd = root.get_node_or_null("SaveData")
	if sd == null: return
	sd.path = "user://qa_tour.json"
	sd.data = GameData.new()
	sd.data.profile.create("Tester")
	sd.data.settings.always_show_health = always_health

## A hand of towers with one formed tower (its badge on the piece): archer (Fire Archer), archer, mage, cannon, priest.
func _hand_save() -> void:
	var sd = root.get_node_or_null("SaveData")
	var t: TowerCollection = sd.data.towers
	t.hand.clear()
	var types := ["archer", "archer", "mage", "cannon", "priest"]
	for i in types.size():
		var o: OwnedTower = t.add(types[i])
		if i == 0:
			o.form = "archer-fire"
			o.forms = ["archer-fire"]
		t.hand.append(o.id)

func _start_level(id: String, hand := true) -> bool:
	if hand: _hand_save()
	var scene: PackedScene = load("res://game/level/level.tscn")
	level = scene.instantiate()
	level.test_level_id = id
	level.instant_override = false
	root.add_child(level)
	await frames(4)
	if level.setup_error != null:
		find("g-stuck", "level " + id, "setup error: %s" % level.setup_error)
		return false
	hud = level.hud as Hud
	level.message_changed.connect(func(t): if str(t) != "": said.append(t))
	park()
	await frames(10)
	return true

## Every refusal / message the controller said (the hint line shows it 3 s, real time: on a slow render the step's
## screenshot may come after it faded).
var said: Array = []

func _run() -> void:
	match scenario:
		"hud": await s_hud()
		"turns": await s_turns()
		"camera": await s_camera()
		"end": await s_end()
		"tutorial": await s_tutorial()
		"ch2": await s_ch2()
		"mission": await s_mission()
		"coop": await s_coop()
		"intro": await s_intro()
		"edge": await s_edge()
		_: print("unknown scenario ", scenario)
	_flush_log()
	print("QA DONE %s: %d findings, %d shots" % [prefix, _found.size(), _shot_n])
	quit(0)

# ------------------------------------------------------------------ helpers on the level

func tile_screen(p: Vector2i) -> Vector2:
	return level.camera.unproject_position(GridSpace.to_world(p))

func piece_for(type_id: String, nth := 0) -> HudHandPiece:
	var k := 0
	for p in hud.tray._pieces:
		var t: TowerDef = level.session.tower(p.tower_id)
		if t != null and t.type != null and t.type.id == type_id:
			if k == nth: return p
			k += 1
	return null

func build_tiles(n: int, tower_id: String) -> Array:
	var s := level.session
	var path: Array = s.state.grid.paths[0].tiles if s.state.grid.paths.size() > 0 else []
	var options := []
	for x in s.state.grid.width:
		for y in s.state.grid.height:
			var p := Vector2i(x, y)
			if not s.can_place(tower_id, p): continue
			var best := 999
			for t in path: best = mini(best, absi(t.x - p.x) + absi(t.y - p.y))
			options.append([best, -y, x, p])
	options.sort()
	var out := []
	for o in options:
		if out.size() >= n: break
		out.append(o[3])
	return out

func idle() -> bool:
	return level.placing == null and level.aiming == null and not level.ui_panel_open

func ability_named(e: Entity, attack: bool) -> AbilityDef:
	for a in e.abilities:
		if a.targeting.is_movement != attack: return a
	return null

func has_target(unit: Entity, a: AbilityDef) -> bool:
	if a == null: return false
	for aim in Targeting.valid_aims(level.session.state, unit.id, a):
		var t: Entity = Instinct.target_of(level.session.state, a, aim)
		if t != null and level.session.enemies.has(t): return true
	return false

func end_turn_click() -> void:
	await click_control(hud.top_bar.end_turn)
	park()
	await settle()

func fast_rounds(n: int, until: Callable = Callable()) -> void:
	level.instant_override = true
	for i in n:
		if level.session.is_over: break
		if until.is_valid() and until.call(): break
		level.end_round()
		await settle()
	level.instant_override = false
	await frames(4)

func hover_all_hud(tag: String) -> void:
	var tb := hud.top_bar
	await hover(tb.get("_hp_pill"), tag + " hp pill")
	await hover(tb.get("_energy_pill"), tag + " energy pill")
	await hover(tb.get("_tracker"), tag + " tracker")
	await hover(tb.get("_skip"), tag + " skip")
	await hover(tb.get("_pause"), tag + " pause")
	await hover(tb.end_turn, tag + " end turn")

func hover_tray(tag: String) -> void:
	for i in hud.tray._pieces.size():
		await hover(hud.tray._pieces[i], "%s piece %d" % [tag, i])

func hover_bar(tag: String) -> void:
	if not hud.action_bar.visible: return
	for i in hud.action_bar.get("_buttons").size():
		await hover(hud.action_bar.button(i), "%s ability %d" % [tag, i])
	for i in hud.action_bar.get("_passives").size():
		await hover(hud.action_bar.get("_passives")[i], "%s passive %d" % [tag, i])

func hover_inspector(tag: String) -> void:
	if not hud.inspector.visible: return
	var list: VBoxContainer = hud.inspector.get("_list")
	for i in list.get_child_count():
		await hover(list.get_child(i), "%s row %d" % [tag, i])
	await hover(hud.inspector.get("_info"), tag + " info button")
	var sell: TdButton = hud.inspector.get("_sell")
	if sell.is_visible_in_tree(): await hover(sell, tag + " sell")
	var bar: TdIconBar = hud.inspector.get("_statuses")
	if bar.is_visible_in_tree():
		var chips := bar.find_children("*", "TdIconChip", true, false)
		for i in mini(chips.size(), 3): await hover(chips[i], "%s status %d" % [tag, i])

## Hovers a unit on the board with the real pointer; checks its plate goes full with the bar and back afterwards.
func hover_unit(e: Entity, what: String) -> void:
	if e == null or e.position == null: return
	var p := tile_screen(e.pos)
	move(p)
	await frames(6)
	await wait(0.3)
	var plates: PlateLayer = level.overlay.plates
	expect(level.hover == e.pos, "h-plate", what, "the board did not take the hover (hover %s, unit at %s)" % [level.hover, e.pos])
	expect(plates.bar_shown(e.id), "h-plate", what, "hovered unit's HP bar not shown")
	var pl = plates.plate_of(e.id)
	if pl != null: expect(pl.get("_scale") != null, "h-plate", what, "no plate scale")
	await step("board_hover_" + what.replace(" ", "_"), true)
	park()
	await frames(6)
	await wait(1.8) # past health_bar_after_hit
	if not level.always_show_health and level.selected != e.id:
		var f: EntityFrame = level.shown.get_frame(e.id)
		var full: bool = f != null and f.hp >= f.max_hp
		if full: expect(not plates.bar_shown(e.id), "h-plate", what, "HP bar still shown after the pointer left an undamaged unit")

# ------------------------------------------------------------------ scenario: hud (placing, aiming, cancel)

func s_hud() -> void:
	_save()
	if not await _start_level(level_id): return
	await wait(1.5)
	await step("intro_box", true)
	# the intro: click through it with real clicks on the box
	for i in 8:
		if level.sequence == null or not hud.sequence.box_shown(): break
		await click_control(hud.sequence.dialogue)
		await wait(0.8)
		await step("intro_click_%d" % i)
	if level.sequence != null: level.skip_sequence()
	await settle()
	park()
	await wait(0.5)
	await step("idle", true)
	await hover_all_hud("idle")
	await hover_tray("idle")

	# placing: click the formed archer's piece; right click cancels; Esc cancels; click again places
	var arch := piece_for("archer")
	await click_control(arch)
	await wait(0.4)
	expect(level.placing != null, "g-stuck", "piece click", "clicking the archer piece did not start placing")
	await step("placing", true)
	await hover_bar("placing")
	await hover_inspector("placing")
	await click(Vector2(960, 600), MOUSE_BUTTON_RIGHT)
	await wait(0.3)
	expect(level.placing == null, "g-stuck", "right click", "right click did not cancel placing")
	await step("placing_right_cancel")
	await click_control(arch)
	await wait(0.3)
	await key(KEY_ESCAPE)
	await wait(0.3)
	expect(level.placing == null, "g-stuck", "Esc", "Esc did not cancel placing")
	expect(not hud.pause.is_open(), "g-stuck", "Esc", "Esc while placing opened the pause menu")
	await step("placing_esc_cancel")
	# clicking the picked piece again puts it back
	await click_control(arch)
	await wait(0.2)
	await click_control(arch)
	await wait(0.3)
	expect(level.placing == null, "g-stuck", "piece toggle", "clicking the picked piece again did not stop placing")
	# a wrong tile while placing: refusal on the hint line, still placing
	await click_control(arch)
	await wait(0.2)
	var tiles := build_tiles(3, arch.tower_id)
	var bad := Vector2i(0, 0)
	for x in level.session.state.grid.width:
		if not level.session.can_place(arch.tower_id, Vector2i(x, 0)) and level.session.state.entity_at(Vector2i(x, 0)) == null:
			bad = Vector2i(x, 0)
			break
	await click(tile_screen(bad))
	await wait(0.3)
	await step("placing_bad_tile", true)
	expect(said.size() > 0 and not str(said[-1]).begins_with("Click a free tile"), "c-text", "hint line", "a refused tile gave no reason (said %s)" % [said.slice(-1)])
	note("refused tile said: %s" % [said.slice(-1)])
	expect(level.placing != null, "g-stuck", "bad tile", "a refused tile ended placing")
	move(tile_screen(tiles[0]))
	await frames(6)
	await step("placing_hover_tile", true)
	await click(tile_screen(tiles[0]))
	park()
	await settle()
	await wait(0.4)
	var archer: Entity = level.session.placed_tower(arch.tower_id)
	expect(archer != null, "g-stuck", "place", "the archer was not placed by a real click on a lit tile")
	if archer == null: return
	expect(level.selected == archer.id, "g-stuck", "place", "the placed tower is not selected")
	await step("placed_selected", true)
	await hover_tray("placed")
	await hover_bar("selected")
	await hover_inspector("selected")

	# Shoot with no enemy in range: a denied shake and the reason, no aiming
	var shoot := ability_named(archer, true)
	await click_control(hud.action_bar.button(archer.abilities.find(shoot)))
	await wait(0.3)
	expect(level.aiming == null, "g-stuck", "Shoot no target", "Shoot aimed with no enemy in range")
	expect(said.size() > 0, "c-text", "hint line", "a refused Shoot gave no reason on the hint line")
	note("refused Shoot said: %s" % [said.slice(-1)])
	await step("shoot_refused", true)
	park()
	await wait(0.5)
	# aiming (Tower Walk, castable now): click; Esc cancels (selection kept); right click cancels; the key toggles
	var aim_ab := ability_named(archer, false)
	var bi := archer.abilities.find(aim_ab)
	var sb := hud.action_bar.button(bi)
	await click_control(sb)
	await wait(0.3)
	expect(level.aiming == aim_ab, "g-stuck", "ability click", "clicking Tower Walk did not aim")
	await step("aiming", true)
	await key(KEY_ESCAPE)
	await wait(0.3)
	expect(level.aiming == null and level.selected == archer.id, "g-stuck", "Esc aiming", "Esc did not cancel aiming (or dropped the selection)")
	expect(not hud.pause.is_open(), "g-stuck", "Esc aiming", "Esc while aiming opened the pause menu")
	await back_to_idle("after Esc aiming")
	await click_control(sb)
	await wait(0.3)
	park()
	await click(Vector2(1300, 700), MOUSE_BUTTON_RIGHT)
	await wait(0.3)
	expect(level.aiming == null, "g-stuck", "right click aiming", "right click did not cancel aiming")
	await key(KEY_1 + bi)
	await wait(0.3)
	var keyed := level.aiming == aim_ab
	await key(KEY_1 + bi)
	await wait(0.3)
	expect(keyed and level.aiming == null, "g-stuck", "ability key", "the ability key did not toggle aiming (on %s, then %s)" % [keyed, level.aiming])
	await step("aim_key_toggle")
	# the walk: aim it, hover a tile, cancel
	var walk := ability_named(archer, false)
	if walk != null:
		await click_control(hud.action_bar.button(archer.abilities.find(walk)))
		await wait(0.3)
		var aims: Array = Targeting.valid_aims(level.session.state, archer.id, walk)
		if aims.size() > 0:
			move(tile_screen(aims[0].tile))
			await frames(6)
			await step("walk_aim_hover", true)
		await key(KEY_ESCAPE)
		await wait(0.3)
	# right click on empty board deselects; right click over the HUD does not
	await click(centre_of(hud.tray), MOUSE_BUTTON_RIGHT)
	await wait(0.2)
	expect(level.selected == archer.id, "g-stuck", "right click HUD", "right click over the HUD deselected")
	await click(tile_screen(Vector2i(0, 0)), MOUSE_BUTTON_RIGHT)
	await wait(0.3)
	expect(level.selected == -1, "g-stuck", "right click board", "right click on the board did not deselect")
	await step("deselected")

	# a piece you cannot afford: shake + the reason
	var poor := piece_for("cannon")
	if poor != null:
		await hover(poor, "poor piece")
		await click_control(poor)
		await wait(0.3)
		await step("poor_denied", true)
		expect(said.size() > 0 and str(said[-1]).contains("energy"), "c-text", "hint line", "the unaffordable piece gave no reason (said %s)" % [said.slice(-1)])
		expect(level.placing == null, "g-stuck", "poor piece", "an unaffordable piece started placing")
		park()
		await wait(2.0)
		check_unhovered("after the denied piece")
	# click the placed piece: selects its tower
	await click_control(arch)
	await wait(0.4)
	expect(level.selected == archer.id, "g-stuck", "placed piece", "clicking a placed piece did not select its tower")
	# Sell (real click), the piece comes back
	var sell: TdButton = hud.inspector.get("_sell")
	if sell.is_visible_in_tree():
		await click_control(sell)
		await settle()
		await wait(0.4)
		await step("sold", true)
		expect(level.session.placed_tower(arch.tower_id) == null, "g-stuck", "sell", "Sell did not take the tower off")
	park()
	await wait(0.4)
	check_unhovered("end of hud")
	await back_to_idle("end of hud")

# ------------------------------------------------------------------ scenario: turns (enemy phase, cards, pause)

func s_turns() -> void:
	_save()
	if not await _start_level(level_id): return
	level.skip_sequence()
	await settle()
	var hand: Array = level.session.hand
	var tiles := build_tiles(2, hand[0].id)
	for i in 2:
		level.toggle_placing(hand[i].id)
		level.click_tile(tiles[i])
		await settle()
	level.select(-1)
	park()
	await wait(0.3)
	# End turn with a real click; during the enemy phase: clicks on pieces / End turn / abilities are refused
	Engine.time_scale = 0.5
	await click_control(hud.top_bar.end_turn)
	await frames(8)
	await step("enemy_phase", true)
	await click_control(hud.top_bar.end_turn)
	await click_control(hud.tray._pieces[2])
	await frames(4)
	await step("enemy_phase_clicks", true)
	expect(level.placing == null, "g-stuck", "enemy phase", "a piece started placing during the enemy phase")
	# Skip while an action plays
	if level.director.busy:
		await click_control(hud.top_bar.get("_skip"))
		await frames(4)
		await step("skip_pressed")
	Engine.time_scale = 1.0
	park()
	await settle()
	await step("after_enemy_phase", true)
	# Skip with nothing playing: the reason below the button
	await click_control(hud.top_bar.get("_skip"))
	await wait(0.4)
	await step("skip_denied", true)
	park()
	await wait(2.0)
	check_unhovered("after skip denied")

	var archer: Entity = level.session.placed_tower(hand[0].id)
	var shoot := ability_named(archer, true)
	await fast_rounds(10, func(): return has_target(archer, shoot))
	# select the archer with a real click on its tile, aim Shoot, hover the enemy: the HP preview on its plate
	await click(tile_screen(archer.pos))
	await wait(0.4)
	expect(level.selected == archer.id, "g-stuck", "board click", "a real click on the archer did not select it")
	await click_control(hud.action_bar.button(archer.abilities.find(shoot)))
	await wait(0.3)
	var target: Entity = null
	for aim in Targeting.valid_aims(level.session.state, archer.id, shoot):
		var t: Entity = Instinct.target_of(level.session.state, shoot, aim)
		if t != null and level.session.enemies.has(t):
			target = t
			break
	if target != null:
		move(tile_screen(target.pos))
		await frames(8)
		var plates: PlateLayer = level.overlay.plates
		expect(plates.health_preview.has(target.id), "h-plate", "aim preview", "aiming at an enemy shows no HP preview")
		expect(plates.bar_shown(target.id), "h-plate", "aim preview", "the aimed enemy's HP bar is hidden")
		await step("aim_enemy_preview", true)
		var hp_before := target.hp
		await click(tile_screen(target.pos))
		park()
		# the bar after a hit (Unity: fill 0.3 s smoothstep, ghost waits 0.3 s then drains 0.6 s, bar visible 1.5 s):
		# wait for the hit to show (the shown frame's HP drops), then sample in real time
		var t_hit := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t_hit < 20000:
			await process_frame
			var sf: EntityFrame = level.shown.get_frame(target.id)
			if sf == null or sf.hp < hp_before: break
		var samples := []
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2600:
			await process_frame
			var pl = plates.plate_of(target.id)
			if pl == null: break
			var bar: TdHealthBar = pl.status.health_bar
			var row := [Time.get_ticks_msec() - t0, snappedf(bar.get_display_fill(), 0.01), snappedf(bar._ghost_v, 0.01), plates.bar_shown(target.id), bar._ghost.visible]
			if samples.is_empty() or row[0] - samples[-1][0] >= 90 or row[3] != samples[-1][3]: samples.append(row)
		note("hit samples (ms after the hit showed, fill, ghost, bar shown, ghost visible): %s" % str(samples))
		var target_fill := float(target.hp) / float(maxi(1, target.max_hp))
		# timing is only meaningful at a real frame rate (llvmpipe renders ~1 frame a second; the bar's dt is clamped
		# per frame); the headless run checks it
		var real_rate: bool = samples.size() > 10
		if not real_rate: note("hp bar timing not checked: %d samples in 2.6 s (frame-bound render)" % samples.size())
		for sm in (samples if real_rate else []):
			if sm[0] >= 450 and sm[0] <= 700: expect(absf(sm[1] - target_fill) < 0.05, "h-plate", "hp bar speed", "fill not down 0.45 s after the hit (%.2f, want %.2f)" % [sm[1], target_fill])
			if sm[0] <= 1300: expect(sm[3], "h-plate", "hp bar after hit", "bar hidden %d ms after a hit (Unity shows it 1.5 s)" % sm[0])
			if sm[0] >= 1900: expect(not sm[3] or level.selected == target.id, "h-plate", "hp bar after hit", "bar still shown %d ms after the hit" % sm[0])
		note("enemy hp %d → %d" % [hp_before, target.hp])
		await step("after_hit", true)
	await settle()
	# hover an enemy on the board (nothing selected) and a tower
	level.select(-1)
	await frames(4)
	var foe: Entity = null
	for e in level.session.enemies:
		if e.alive and e.position != null: foe = e
	await hover_unit(foe, "enemy")
	await hover_unit(archer, "tower")
	# the enemy card: select by a real click, hover its rows (the board previews its ability)
	if foe != null and foe.alive:
		await click(tile_screen(foe.pos))
		await wait(0.5)
		expect(level.selected == foe.id, "g-stuck", "enemy click", "a real click on the enemy did not select it")
		await step("enemy_card", true)
		await hover_inspector("enemy")
		# Info: the I key, then close with its × ; double click on the board opens it too
		await key(KEY_I)
		await wait(0.6)
		expect(hud.info.is_open(), "g-stuck", "I key", "I did not open the Info window")
		await step("info_enemy", true)
		var sc := hud.info.find_children("*", "ScrollContainer", true, false)
		if sc.size() > 0:
			(sc[0] as ScrollContainer).scroll_vertical = 10000
			await frames(4)
			await step("info_enemy_scrolled", true)
		if hud.info.close_button != null:
			await click_control(hud.info.close_button)
		else:
			await key(KEY_ESCAPE)
		await wait(0.5)
		expect(not hud.info.is_open(), "g-stuck", "info close", "the Info window did not close")
		var fp := tile_screen(foe.pos)
		move(fp)
		await frames(3)
		button(fp, MOUSE_BUTTON_LEFT, true)
		await frames(1)
		button(fp, MOUSE_BUTTON_LEFT, false)
		await frames(1)
		button(fp, MOUSE_BUTTON_LEFT, true, true)
		await frames(1)
		button(fp, MOUSE_BUTTON_LEFT, false)
		await wait(0.6)
		await step("info_double_click", hud.info.is_open())
		if hud.info.is_open():
			await click(Vector2(60, 540), MOUSE_BUTTON_RIGHT) # right click on the scrim closes
			await wait(0.5)
			expect(not hud.info.is_open(), "g-stuck", "info scrim", "right click on the scrim did not close Info")
		await back_to_idle("info")
	# the tower card with statuses and its Info
	if archer.alive:
		await click(tile_screen(archer.pos))
		await wait(0.4)
		await click_control(hud.inspector.get("_info"))
		await wait(0.6)
		await step("info_tower", true)
		await key(KEY_ESCAPE)
		await wait(0.5)
		expect(not hud.info.is_open(), "g-stuck", "info Esc", "Esc did not close the tower Info")
		expect(not hud.pause.is_open(), "g-stuck", "info Esc", "Esc closing Info also opened pause")
	# pause: the button, each sub-screen and back
	await click_control(hud.top_bar.get("_pause"))
	await wait(0.6)
	expect(hud.pause.is_open(), "g-stuck", "pause button", "the pause button did not open the menu")
	await step("pause", true)
	for b in [hud.pause.continue_button, hud.pause.settings_button, hud.pause.codex_button, hud.pause.leave_button, hud.pause.quit_button]:
		if b.is_visible_in_tree(): await hover(b, "pause " + b.text, false)
	await click_control(hud.pause.settings_button)
	await wait(0.8)
	await step("pause_settings", true)
	await _tour_settings()
	await key(KEY_ESCAPE)
	await wait(0.8)
	expect(hud.pause.is_open(), "g-stuck", "settings Esc", "Esc in Settings closed the pause menu too (or nothing)")
	expect(not is_instance_valid(hud.pause.get("_sub")), "g-stuck", "settings Esc", "Esc did not close Settings")
	await step("pause_after_settings", true)
	if hud.pause.codex_button.is_visible_in_tree():
		await click_control(hud.pause.codex_button)
		await wait(1.2)
		await step("pause_codex", true)
		await _tour_codex()
		var sub = hud.pause.get("_sub")
		var back := _find_button(sub, ["Back", "Close", "×"]) if is_instance_valid(sub) else null
		if back != null: await click_control(back)
		else: await key(KEY_ESCAPE)
		await wait(0.8)
		expect(not is_instance_valid(hud.pause.get("_sub")), "g-stuck", "codex back", "Codex did not close")
		expect(hud.pause.is_open(), "g-stuck", "codex back", "closing Codex closed pause too")
		await step("pause_after_codex", true)
	await click_control(hud.pause.continue_button)
	await wait(0.6)
	expect(not hud.pause.is_open() and Engine.time_scale > 0.0, "g-stuck", "continue", "Continue did not resume (open %s, time %.2f)" % [hud.pause.is_open(), Engine.time_scale])
	# P opens and closes; Esc with nothing to cancel opens
	level.select(-1)
	await key(KEY_P)
	await wait(0.6)
	var p_open := hud.pause.is_open()
	await key(KEY_P)
	await wait(0.6)
	expect(p_open and not hud.pause.is_open(), "g-stuck", "P key", "P did not open then close pause (%s, %s)" % [p_open, hud.pause.is_open()])
	await key(KEY_ESCAPE)
	await wait(0.6)
	expect(hud.pause.is_open(), "g-stuck", "Esc idle", "Esc with nothing to cancel did not open pause")
	await click(Vector2(100, 900), MOUSE_BUTTON_RIGHT)
	await wait(0.6)
	expect(not hud.pause.is_open(), "g-stuck", "pause scrim", "right click on the scrim did not continue")
	park()
	await wait(0.4)
	check_unhovered("end of turns")
	await step("end_turns", true)

func _find_button(n: Node, texts: Array) -> TdButton:
	if n == null: return null
	for b in n.find_children("*", "TdButton", true, false):
		if not (b as TdButton).is_visible_in_tree(): continue
		for t in texts:
			if (b as TdButton).text.begins_with(t) or String(b.name).to_lower().contains(t.to_lower()): return b
	return null

func _tour_settings() -> void:
	var sub = hud.pause.get("_sub")
	if not is_instance_valid(sub): return
	var tabs: Array = []
	for b in sub.find_children("*", "TdButton", true, false):
		if (b as TdButton).style == TdButton.Style.TAB and (b as TdButton).is_visible_in_tree(): tabs.append(b)
	for b in tabs:
		await click_control(b)
		await wait(0.5)
		await step("settings_tab_" + (b as TdButton).text.to_lower(), true)

func _tour_codex() -> void:
	var sub = hud.pause.get("_sub")
	if not is_instance_valid(sub): return
	var tabs: Array = []
	for b in sub.find_children("*", "TdButton", true, false):
		if (b as TdButton).style == TdButton.Style.TAB and (b as TdButton).is_visible_in_tree(): tabs.append(b)
	for b in tabs.slice(0, 3):
		await click_control(b)
		await wait(0.5)
		await step("codex_tab_" + (b as TdButton).text.to_lower(), false)

# ------------------------------------------------------------------ scenario: camera and plates

func s_camera() -> void:
	_save()
	if not await _start_level("chapter1-3"): return
	level.skip_sequence()
	await settle()
	var hand: Array = level.session.hand
	var tiles := build_tiles(2, hand[0].id)
	for i in 2:
		level.toggle_placing(hand[i].id)
		level.click_tile(tiles[i])
		await settle()
	level.select(-1)
	await fast_rounds(3, func(): return level.session.enemies.size() > 2)
	park()
	await wait(0.5)
	var cam: BoardCamera = level.camera
	note("camera start: distance %.2f (min %.2f, max %.2f) yaw %.0f" % [cam.distance, cam.min_distance, cam.max_distance, cam.yaw])
	await step("camera_start", true)
	var centre := Vector2(860, 560)
	# zoom in to the limit with the wheel
	var last := -1.0
	for i in 40:
		await wheel(centre, true, 2)
		await frames(3)
		if absf(cam.distance_target - last) < 0.001: break
		last = cam.distance_target
	await wait(0.8)
	note("zoomed in: distance %.2f target %.2f min %.2f" % [cam.distance, cam.distance_target, cam.min_distance])
	expect(cam.distance_target >= cam.min_distance - 0.01, "camera", "zoom in", "zoom went past the near limit")
	_plate_sizes("zoomed in")
	await _hover_any_enemy("zoom_in")
	await step("camera_zoom_in", true)
	# drag to pan (left drag; must not click a tile)
	var sel_before := level.selected
	var f0 := cam.focus_target
	await drag(Vector2(900, 600), Vector2(500, 500))
	await wait(0.6)
	note("left drag: focus %s → %s; drag_to_pan %s" % [f0, cam.focus_target, cam.drag_to_pan])
	expect(cam.focus_target.distance_to(f0) > 0.2, "camera", "drag pan", "left drag did not pan (drag_to_pan %s)" % cam.drag_to_pan)
	expect(level.selected == sel_before and level.placing == null, "camera", "drag pan", "a drag clicked a tile")
	await step("camera_drag", true)
	# drag far: the pan stays within the limits
	for i in 4: await drag(Vector2(300, 300), Vector2(1600, 900))
	await wait(0.6)
	note("pan limit: focus %s bounds %s" % [cam.focus_target, cam.bounds])
	await step("camera_pan_limit", true)
	for i in 4: await drag(Vector2(1600, 900), Vector2(300, 300))
	await wait(0.6)
	await step("camera_pan_limit_other", true)
	# middle drag pans too
	var f1 := cam.focus_target
	await drag(Vector2(900, 600), Vector2(1100, 650), MOUSE_BUTTON_MIDDLE)
	await wait(0.4)
	note("middle drag: focus %s → %s" % [f1, cam.focus_target])
	# zoom out to the limit
	for i in 60:
		await wheel(centre, false, 2)
		await frames(3)
		if absf(cam.distance_target - last) < 0.001: break
		last = cam.distance_target
	await wait(0.8)
	note("zoomed out: distance %.2f target %.2f max %.2f" % [cam.distance, cam.distance_target, cam.max_distance])
	expect(cam.distance_target <= cam.max_distance + 0.01, "camera", "zoom out", "zoom went past the far limit")
	expect(cam.focus_target.distance_to(cam.board_centre()) < 0.3, "camera", "zoom out", "zoomed out after a pan to the edge, the board is not whole (focus %s, centre %s)" % [cam.focus_target, cam.board_centre()])
	_plate_sizes("zoomed out")
	await _hover_any_enemy("zoom_out")
	await step("camera_zoom_out", true)
	# rotate with E and Q (four turns back to the start)
	for i in 4:
		await key(KEY_E)
		await wait(0.9)
		await step("camera_rot_e_%d" % i, i == 0)
		note("after E: yaw %.0f distance %.2f max %.2f" % [cam.yaw_target, cam.distance_target, cam.max_distance])
	await key(KEY_Q)
	await wait(0.9)
	await step("camera_rot_q", true)
	# keyboard pan
	var f2 := cam.focus_target
	await key(KEY_W, false, 12)
	await key(KEY_D, false, 12)
	note("WASD: focus %s → %s" % [f2, cam.focus_target])
	# Always Show Health on: every unit's bar shows
	level.always_show_health_override = true
	await wait(0.4)
	var plates: PlateLayer = level.overlay.plates
	var hidden := 0
	for e in level.session.enemies:
		if e.alive and e.position != null and not plates.bar_shown(e.id): hidden += 1
	expect(hidden == 0, "h-plate", "always show", "%d enemy bars hidden with Always Show Health" % hidden)
	await step("plates_always", true)
	level.always_show_health_override = false
	await wait(0.4)
	# drag-to-pan off: a left drag does nothing (no pan, no click)
	cam.drag_to_pan = false
	var f3 := cam.focus_target
	await drag(Vector2(900, 600), Vector2(600, 500))
	await wait(0.4)
	note("drag_to_pan off: focus %s → %s" % [f3, cam.focus_target])
	cam.drag_to_pan = true
	# Camera Follows Selection: zoomed in, selecting a tower at the far end glides to it; with the setting off it stays
	var sd = root.get_node_or_null("SaveData")
	var towers: Array = []
	for t in level.session.hand:
		var e: Entity = level.session.placed_tower(t.id)
		if e != null: towers.append(e)
	if sd != null and towers.size() > 0:
		for i in 20: await wheel(Vector2(860, 560), true, 1)
		await wait(0.6)
		for on in [true, false]:
			sd.data.settings.follow_selection = on
			level.select(-1)
			var before := cam.focus_target
			level.select(towers[0].id)
			await frames(3)
			var moved := cam.focus_target.distance_to(before) > 0.05 or cam.gliding
			note("follow selection %s: focus %s → %s (moved %s)" % [on, before, cam.focus_target, moved])
			expect(moved == on or before.distance_to(GridSpace.to_world(towers[0].pos)) < 0.3, "camera", "follow selection", "Camera Follows Selection %s, the camera %s" % ["on" if on else "off", "moved" if moved else "stayed"])
			await wait(1.0)
			await step("follow_selection_%s" % ("on" if on else "off"), true)
		sd.data.settings.follow_selection = true

func _plate_sizes(where: String) -> void:
	var plates: PlateLayer = level.overlay.plates
	for e in level.session.enemies:
		if not e.alive or e.position == null: continue
		var pl = plates.plate_of(e.id)
		if pl == null: continue
		var tile := WorldUi.tile_width(level.camera, GridSpace.to_world(e.pos))
		note("%s: enemy %d plate rect %s scale %.2f tile %.1f ref %.1f" % [where, e.id, _rs(pl.plate_rect()), pl.get("_scale"), tile, WorldUi.reference_tile])
		break

func _hover_any_enemy(tag: String) -> void:
	for e in level.session.enemies:
		if not e.alive or e.position == null: continue
		var p := tile_screen(e.pos)
		if not root.get_visible_rect().grow(-100).has_point(p): continue
		move(p)
		await frames(6)
		var pl = level.overlay.plates.plate_of(e.id)
		if pl != null: note("%s hovered plate rect %s (full plate, readable scale)" % [tag, _rs(pl.plate_rect())])
		expect(level.overlay.plates.bar_shown(e.id), "h-plate", tag, "hovered enemy bar hidden")
		return

# ------------------------------------------------------------------ scenario: end screens

func s_end() -> void:
	_save()
	if not await _start_level(level_id): return
	level.skip_sequence()
	await settle()
	var hand: Array = level.session.hand
	var tiles := build_tiles(2, hand[0].id)
	for i in 2:
		level.toggle_placing(hand[i].id)
		level.click_tile(tiles[i])
		await settle()
	level.instant_override = true
	for r in 60:
		if level.session.is_over: break
		for e in level.session.enemies:
			if not e.alive: continue
			var fx := DamageEffect.new()
			fx.amount = Formula.new("999")
			fx.target_id = e.id
			fx.source = 0
			level.session.resolver.run(fx)
		level.session.after_command()
		level.version += 1
		await settle()
		if level.session.is_over: break
		level.end_round()
		await settle()
	for i in 600:
		if hud.end_screen.visible: break
		await process_frame
	await wait(1.0)
	await step("victory", true)
	for b in [hud.end_screen.next_button, hud.end_screen.retry_button, hud.end_screen.leave_button]:
		if b != null and b.is_visible_in_tree(): await hover(b, "victory " + b.text, false)
	await key(KEY_ESCAPE)
	await wait(0.5)
	expect(hud.end_screen.visible, "g-stuck", "end screen", "Esc closed the end screen")
	expect(not hud.pause.is_open(), "g-stuck", "end screen", "Esc on the end screen opened pause")
	# a loss: a fresh level where the base takes lethal damage
	level.queue_free()
	await frames(3)
	_save()
	if not await _start_level(level_id): return
	level.skip_sequence()
	await settle()
	for b in level.session.bases:
		var fx := DamageEffect.new()
		fx.amount = Formula.new("9999")
		fx.target_id = b
		fx.source = 0
		level.session.resolver.run(fx)
	level.session.after_command()
	level.version += 1
	await settle()
	for i in 600:
		if hud.end_screen.visible: break
		await process_frame
	await wait(1.0)
	await step("defeat", true)
	for b in [hud.end_screen.retry_button, hud.end_screen.leave_button]:
		if b != null and b.is_visible_in_tree(): await hover(b, "defeat " + b.text, false)

# ------------------------------------------------------------------ scenario: tutorial

func s_tutorial() -> void:
	_save()
	var sd = root.get_node_or_null("SaveData")
	if not await _start_level("tutorial", false): return
	var g: GuidedTutorial = level.guided
	if g == null:
		find("g-stuck", "tutorial", "no guided tutorial")
		return
	await wait(1.6)
	var seen := {}
	for guard in 60:
		if g.finished or level.session.is_over: break
		var i := g.index
		var first := not seen.has(i)
		seen[i] = true
		await step("t%02d" % (i + 1), first)
		note("step %d/%d '%s' docked %s, note '%s'" % [i + 1, g.steps.size(), g.step.line.text.left(40), "top" if hud.sequence.get("_dock_top") else "bottom", (hud.sequence.dialogue.get("_hint") as RichTextLabel).get_parsed_text()])
		if first: await _tutorial_wrong(g)
		await _tutorial_right(g)
		await wait(0.6)
		if g.index == i and not g.finished:
			note("step %d did not advance yet" % (i + 1))
	await step("tutorial_free_play", true)
	await wait(1.5)
	await step("tutorial_end_screen", true)
	# Skip on a fresh run: the button in the box
	level.queue_free()
	await frames(3)
	await step("tutorial_freed")
	_save()
	if not await _start_level("tutorial", false): return
	await step("tutorial_second_start")
	await wait(1.2)
	var skip: TdButton = hud.sequence.dialogue.get("_skip")
	await hover(skip, "tutorial skip", true)
	await click_control(skip)
	await wait(0.8)
	expect(level.guided == null or level.guided.finished, "g-stuck", "tutorial skip", "Skip did not end the guided tutorial")
	await step("tutorial_skipped", true)
	# after Skip everything works: place and End turn
	var arch := piece_for("archer")
	if arch != null:
		await click_control(arch)
		await wait(0.3)
		expect(level.placing != null, "g-stuck", "after skip", "the piece does not work after Skip")
		await key(KEY_ESCAPE)

## A wrong action for the current step: expect a refusal (refusals +1 or nothing changed), never a stuck state.
func _tutorial_wrong(g: GuidedTutorial) -> void:
	var before := g.refusals
	var idx := g.index
	if g.step.get("allow", []).has("all"): return # free play: nothing is wrong
	var tried := ""
	var arch := piece_for("archer")
	if g.talking:
		tried = "End turn on a talk line"
		await click_control(hud.top_bar.end_turn)
	elif level.placing != null:
		tried = "a tile that is not lit"
		await click(tile_screen(Vector2i(0, 0)))
	elif level.aiming != null:
		tried = "a wrong tile while aiming"
		await click(tile_screen(Vector2i(0, 4)))
	elif g.allows("end_turn"):
		tried = "clicking the castle"
		await click(tile_screen(Vector2i(6, 2)))
	else:
		tried = "End turn"
		await click_control(hud.top_bar.end_turn)
	await wait(0.4)
	var refused := g.refusals > before
	await step("t%02d_wrong" % (idx + 1), true)
	note("wrong action at step %d (%s): refused %s, hint '%s'" % [idx + 1, tried, refused, g.last_hint])
	if not str(g.step.get("advance", "")).begins_with("seconds") and g.index != idx and not str(steps_advance(g, idx)).begins_with("seconds"):
		find("g-stuck", "tutorial step %d" % (idx + 1), "a wrong action (%s) moved the tutorial on" % tried)
	expect(refused, "g-stuck", "tutorial step %d" % (idx + 1), "a wrong action (%s) was not refused visibly" % tried)
	expect(level.session.phase == Phase.Player or g.allows("end_turn"), "g-stuck", "tutorial step %d" % (idx + 1), "the wrong action ended the turn")
	park()
	await wait(0.3)

func steps_advance(g: GuidedTutorial, i: int) -> String:
	return str(g.steps[i].get("advance", "")) if i >= 0 and i < g.steps.size() else ""

## The allowed action for the current step, with real input.
func _tutorial_right(g: GuidedTutorial) -> void:
	var l := g.display_line()
	if g.talking:
		await click_control(hud.sequence.dialogue)
		await wait(0.4)
		if g.talking and g.index >= 0 and str(g.step.get("advance", "")).begins_with("seconds"): await wait(2.0)
		return
	match l.point_at:
		SequencePointAt.UI:
			if l.ui_element == "@piece":
				await click_control(piece_for("archer"))
			elif l.ui_element == "EndTurnButton":
				await click_control(hud.top_bar.end_turn)
				park()
				await settle()
			elif l.ui_element.begins_with("@ability:"):
				var a := g.line_ability()
				var b := hud.action_bar.button(g.archer().abilities.find(a))
				if g.allows("quick_cast", a) and g.step.get("allow", []).has("quick_cast"):
					await _key_raw(KEY_SHIFT, true)
					await click_control(b)
					await _key_raw(KEY_SHIFT, false)
					await settle()
				else:
					await click_control(b)
		SequencePointAt.Tile:
			await click(tile_screen(Vector2i(l.tile_x, l.tile_y)))
			park()
			await settle()
		SequencePointAt.FirstTower:
			await click(tile_screen(g.archer().pos))
		SequencePointAt.FirstEnemy:
			await click(tile_screen(g.first_enemy().pos))
			park()
			await settle()
		_:
			if g.step.get("allow", []).has("all"):
				# free play: click the box away, then End turn until won
				await click_control(hud.sequence.dialogue)
				await fast_rounds(30)
	await wait(0.3)

# ------------------------------------------------------------------ scenario: chapter 2 (enemy abilities, statuses)

func s_ch2() -> void:
	_save()
	if not await _start_level("chapter2-3"): return
	await wait(1.0)
	await step("ch2_intro", true)
	level.skip_sequence()
	await settle()
	var hand: Array = level.session.hand
	var tiles := build_tiles(3, hand[0].id)
	for i in 3:
		if level.session.can_place(hand[i].id, tiles[i]):
			level.toggle_placing(hand[i].id)
			level.click_tile(tiles[i])
			await settle()
	level.select(-1)
	await fast_rounds(6, func(): return level.session.enemies.size() >= 3)
	park()
	await wait(0.5)
	await step("ch2_board", true)
	await hover_all_hud("ch2")
	for e in level.session.enemies.slice(0, 3):
		if not e.alive or e.position == null: continue
		await hover_unit(e, "ch2 enemy %d" % e.id)
		await click(tile_screen(e.pos))
		await wait(0.5)
		await step("ch2_enemy_card_%d" % e.id, true)
		await hover_inspector("ch2 enemy %d" % e.id)
	await back_to_idle("ch2")
	# a tower with statuses
	var t: Entity = level.session.placed_tower(hand[0].id)
	if t != null and t.alive:
		_apply_statuses(t, [["burn", "3", "3"], ["shield", "2", ""], ["slow", "1", "2"], ["poison", "2", "3"]])
		await settle()
		await click(tile_screen(t.pos))
		await wait(0.5)
		await step("ch2_tower_statuses", true)
		await hover_inspector("ch2 tower")
		await hover_unit(t, "ch2 tower statuses")
		await hover_bar("ch2 tower")

func _apply_statuses(unit: Entity, specs: Array) -> void:
	var app = root.get_node_or_null("GameApp")
	var lib: ContentLibrary = app.lib
	for spec in specs:
		var asset: StatusAsset = null
		for a in lib.all_of("StatusAsset"):
			if a.get_id().to_lower() == spec[0] or a.name.get_file().to_lower() == spec[0]: asset = a
		if asset == null: continue
		var fx := ApplyStatusEffect.new()
		fx.status = level.converter.status(asset)
		fx.stacks = Formula.new(spec[1])
		if spec[2] != "": fx.duration = Formula.new(spec[2])
		fx.target_id = unit.id
		fx.source = 0
		level.session.resolver.run(fx)
	level.version += 1

# ------------------------------------------------------------------ scenario: mission (through SceneFlow)

func s_mission() -> void:
	_save()
	var app = root.get_node_or_null("GameApp")
	app.complete_chapter2()
	_hand_save()
	var ok: bool = app.play_mission("patrol")
	expect(ok, "g-stuck", "play_mission", "GameApp.play_mission refused: %s" % MissionBoard.last_reason)
	if not ok: return
	for i in 1200:
		await process_frame
		if current_scene is LevelController and (current_scene as LevelController).hud != null: break
	level = current_scene as LevelController
	if level == null:
		find("g-stuck", "mission", "the level scene never came up")
		return
	hud = level.hud as Hud
	await wait(2.0)
	await step("mission_start", true)
	level.skip_sequence()
	await settle()
	await step("mission_idle", true)
	await hover_tray("mission")
	await hover_all_hud("mission")
	# pause shows the mission's leave label
	await click_control(hud.top_bar.get("_pause"))
	await wait(0.6)
	await step("mission_pause", true)
	await click_control(hud.pause.continue_button)
	await wait(0.5)
	# lose it: the mission end screen (Retry takes … / tired note)
	for b in level.session.bases:
		var fx := DamageEffect.new()
		fx.amount = Formula.new("9999")
		fx.target_id = b
		fx.source = 0
		level.session.resolver.run(fx)
	level.session.after_command()
	level.version += 1
	await settle()
	for i in 600:
		if hud.end_screen.visible: break
		await process_frame
	await wait(1.0)
	await step("mission_defeat", true)
	for b in [hud.end_screen.retry_button, hud.end_screen.leave_button, hud.end_screen.next_button]:
		if b != null and b.is_visible_in_tree(): await hover(b, "mission end " + b.text, false)

# ------------------------------------------------------------------ scenario: a level intro in the dialogue box

func s_intro() -> void:
	_save()
	# only the tutorial level has an intro: play it as the plain SequenceRun (the non-guided path every other intro
	# and entrance takes), in the same dialogue box
	if not await _start_level("tutorial", false): return
	if level.guided != null:
		level.guided.skip()
		level.guided = null
	level.call("_play", level.level.intro, null, "")
	await wait(1.6)
	for i in 10:
		if level.sequence == null or not hud.sequence.box_shown(): break
		await step("intro_line_%d" % i, true)
		var skip: TdButton = hud.sequence.dialogue.get("_skip")
		if i == 0 and skip != null and skip.is_visible_in_tree(): await hover(skip, "intro skip", true)
		await key(KEY_SPACE)
		await wait(1.0)
	await step("intro_done", true)
	expect(level.sequence == null or not hud.sequence.box_shown(), "g-stuck", "intro", "the intro never ended with Space")

# ------------------------------------------------------------------ scenario: co-op (stub relay)

class StubRelay extends RefCounted:
	signal cmd_received(player: String, round: int, seq: int, cmd: Dictionary)
	signal player_left(player: String)
	signal desync(round: int, hashes: Dictionary)
	signal chat_received(from: String, name: String, text: String)
	signal kicked
	var player_id := ""
	var reopen_lobby := false
	var sent: Array = []
	var _seq := 0
	func send_cmd(round: int, cmd: Dictionary) -> int:
		_seq += 1
		sent.append(cmd)
		(func(): cmd_received.emit(player_id, round, _seq, JSON.parse_string(JSON.stringify(cmd)))).call_deferred()
		return _seq
	func send_checksum(_round: int, _hash: String) -> void: pass
	func chat(text: String) -> void:
		(func(): chat_received.emit(player_id, "Tester", text)).call_deferred()
	func leave_room() -> void: pass

const ME := "eren0001"
const OTHER := "sule0002"

func s_coop() -> void:
	_save()
	var net := StubRelay.new()
	net.player_id = ME
	CoopLaunch.request({"seed": 7, "level": "chapter1-3", "shared_pool": false, "local_player": ME,
		"players": [{"id": ME, "name": "Eren", "hand": ["archer", "cannon", "mage"], "slot": 0},
			{"id": OTHER, "name": "Şule", "hand": ["archer", "priest"], "slot": 1}]}, net)
	var scene: PackedScene = load("res://game/level/level.tscn")
	level = scene.instantiate()
	level.instant_override = false
	root.add_child(level)
	await frames(4)
	if level.setup_error != null:
		find("g-stuck", "coop", "setup error %s" % level.setup_error)
		return
	hud = level.hud as Hud
	park()
	await settle()
	await wait(0.5)
	await step("coop_my_turn", true)
	await hover_all_hud("coop")
	await hover(hud.coop_hud.dial, "coop pass")
	for c in hud.coop_hud.order_row.get_children():
		if c is Control: await hover(c, "coop tracker %s" % c.name)
	await hover_tray("coop")
	# place with real clicks
	var mine: Array = level.hand_towers
	var tiles := []
	for x in level.session.state.grid.width:
		for y in level.session.state.grid.height:
			if tiles.size() < 2 and level.coop.coop.can_place(level.coop.me, mine[0].id, Vector2i(x, y)): tiles.append(Vector2i(x, y))
	await click_control(hud.tray._pieces[0])
	await wait(0.3)
	if tiles.is_empty():
		find("g-stuck", "coop", "no tile to place on: %s" % level.coop.coop.last_reason)
		return
	await click(tile_screen(tiles[0]))
	park()
	await settle()
	await wait(0.5)
	await step("coop_placed", true)
	# Pass: the turn goes to the other player; everything waits
	await click_control(hud.coop_hud.dial)
	await settle()
	await wait(0.6)
	await step("coop_passed", true)
	note("after Pass: current %s my turn %s wait '%s'" % [level.current_player, level.is_my_turn, level.wait_reason])
	await hover(hud.top_bar.end_turn, "coop end turn waiting")
	await click_control(hud.tray._pieces[1])
	await wait(0.4)
	await step("coop_piece_waiting", true)
	expect(level.placing == null, "g-stuck", "coop", "a piece started placing on the other player's turn")
	# the other player ends their turn → our turn back
	net.cmd_received.emit(OTHER, level.session.round, 99, {"k": "end_turn"})
	await settle()
	await wait(0.6)
	await step("coop_back", true)
	note("after the other ends: current %s my turn %s" % [level.current_player, level.is_my_turn])
	park()
	await frames(6)
	await wait(0.4)
	check_unhovered("coop")

# ------------------------------------------------------------------ scenario: wrong inputs (keys, double clicks, chains, resize)

func s_edge() -> void:
	_save()
	if not await _start_level(level_id): return
	level.skip_sequence()
	await settle()
	park()
	# keys 1–9 with nothing selected, then with a tower with fewer abilities
	for k in 9: await key(KEY_1 + k)
	await wait(0.3)
	expect(level.aiming == null, "g-stuck", "keys 1-9 idle", "an ability key with nothing selected aimed something")
	await step("keys_idle", true)
	await back_to_idle("keys idle")
	var arch := piece_for("archer")
	var tiles := build_tiles(2, arch.tower_id)
	# rapid double click on a piece: must not leave placing half-on
	var ap := centre_of(arch)
	move(ap)
	await frames(2)
	button(ap, MOUSE_BUTTON_LEFT, true); await frames(1)
	button(ap, MOUSE_BUTTON_LEFT, false); await frames(1)
	button(ap, MOUSE_BUTTON_LEFT, true, true); await frames(1)
	button(ap, MOUSE_BUTTON_LEFT, false)
	await wait(0.4)
	note("double click on a piece: placing %s" % level.placing)
	expect(level.placing != null, "g-stuck", "piece double click", "a double click on a piece left nothing picked")
	await step("piece_double_click", true)
	if level.placing == null: await click_control(arch)
	await wait(0.2)
	# double click on a lit tile: one placement, no Info opened over it, no error
	var tp := tile_screen(tiles[0])
	move(tp)
	await frames(3)
	button(tp, MOUSE_BUTTON_LEFT, true); await frames(1)
	button(tp, MOUSE_BUTTON_LEFT, false); await frames(1)
	button(tp, MOUSE_BUTTON_LEFT, true, true); await frames(1)
	button(tp, MOUSE_BUTTON_LEFT, false)
	park()
	await settle()
	await wait(0.6)
	var archer: Entity = level.session.placed_tower(arch.tower_id)
	expect(archer != null, "g-stuck", "tile double click", "a double click on a lit tile placed nothing")
	await step("tile_double_click", true)
	note("after double click on a tile: info open %s, selected %d" % [hud.info.is_open(), level.selected])
	await back_to_idle("tile double click")
	if archer == null: return
	await click(tile_screen(archer.pos))
	await wait(0.3)
	var n_ab := archer.abilities.size()
	for k in range(n_ab, 9):
		await key(KEY_1 + k)
	await wait(0.3)
	expect(level.aiming == null, "g-stuck", "keys beyond", "a key past the last ability aimed something")
	expect(level.selected == archer.id, "g-stuck", "keys beyond", "a key past the last ability dropped the selection")
	await step("keys_beyond_abilities", true)
	note("keys %d-9 with %d abilities: aiming %s, said %s" % [n_ab + 1, n_ab, level.aiming, said.slice(-1)])
	# Shift+N and Ctrl+N with too-high N
	await key(KEY_9, true)
	await wait(0.3)
	await step("shift9")
	# a double click on an ability button: aims (once), does not toggle back off
	var walk_b := ability_named(archer, false)
	if walk_b != null:
		var bp := centre_of(hud.action_bar.button(archer.abilities.find(walk_b)))
		move(bp)
		await frames(2)
		button(bp, MOUSE_BUTTON_LEFT, true); await frames(1)
		button(bp, MOUSE_BUTTON_LEFT, false); await frames(1)
		button(bp, MOUSE_BUTTON_LEFT, true, true); await frames(1)
		button(bp, MOUSE_BUTTON_LEFT, false)
		await wait(0.3)
		expect(level.aiming == walk_b, "g-stuck", "ability double click", "a double click on an ability button left it not aiming (%s)" % level.aiming)
		await step("ability_double_click", true)
		await key(KEY_ESCAPE)
		await wait(0.3)
	# Esc / right click chains: aiming → Esc → Esc (deselect? pause?) → Esc
	var walk := ability_named(archer, false)
	if walk != null:
		await key(KEY_1 + archer.abilities.find(walk))
		await wait(0.2)
	var chain := []
	for i in 4:
		await key(KEY_ESCAPE)
		await wait(0.4)
		chain.append("aim %s sel %d pause %s" % [level.aiming != null, level.selected, hud.pause.is_open()])
	note("Esc chain from aiming: %s" % str(chain))
	await step("esc_chain", true)
	await back_to_idle("esc chain")
	await click(tile_screen(archer.pos))
	await wait(0.3)
	if walk != null:
		await key(KEY_1 + archer.abilities.find(walk))
		await wait(0.2)
	chain = []
	for i in 4:
		await click(Vector2(1300, 650), MOUSE_BUTTON_RIGHT)
		await wait(0.3)
		chain.append("aim %s sel %d pause %s" % [level.aiming != null, level.selected, hud.pause.is_open()])
	note("right click chain from aiming: %s" % str(chain))
	await step("right_chain", true)
	# pause open: right click chains and Esc
	await key(KEY_ESCAPE)
	await wait(0.5)
	await key(KEY_ESCAPE)
	await wait(0.5)
	note("Esc twice from idle: pause %s" % hud.pause.is_open())
	await back_to_idle("esc twice")
	# rapid double click on End turn: one enemy phase only
	var r0 := level.session.round
	var ep := centre_of(hud.top_bar.end_turn)
	move(ep)
	await frames(2)
	button(ep, MOUSE_BUTTON_LEFT, true); await frames(1)
	button(ep, MOUSE_BUTTON_LEFT, false); await frames(1)
	button(ep, MOUSE_BUTTON_LEFT, true, true); await frames(1)
	button(ep, MOUSE_BUTTON_LEFT, false)
	await frames(6)
	await step("end_turn_double", true)
	park()
	await settle()
	note("End turn double click: round %d → %d" % [r0, level.session.round])
	expect(level.session.round <= r0 + 1, "g-stuck", "End turn double click", "a double click ended two rounds (%d → %d)" % [r0, level.session.round])
	# Enter pressed during the enemy phase
	Engine.time_scale = 0.4
	var r1 := level.session.round
	await key(KEY_ENTER)
	await frames(4)
	await key(KEY_ENTER)
	await key(KEY_P)
	await wait(0.4)
	await step("enter_enemy_phase_pause", true)
	note("Enter twice + P during the enemy phase: round %d → %d, pause %s" % [r1, level.session.round, hud.pause.is_open()])
	await back_to_idle("enemy phase pause")
	Engine.time_scale = 1.0
	await settle()
	# wheel at the limits while placing (zoom must not place / cancel)
	var arch2 := piece_for("archer", 1)
	if arch2 != null and level.session.energy >= 1:
		await click_control(arch2)
		await wait(0.2)
		await wheel(Vector2(900, 500), true, 30)
		await wheel(Vector2(900, 500), true, 6)
		await wait(0.5)
		await step("wheel_in_limit_placing", true)
		await wheel(Vector2(900, 500), false, 50)
		await wait(0.8)
		await step("wheel_out_limit_placing", true)
		note("wheel while placing: placing %s distance %.2f" % [level.placing != null, level.camera.distance_target])
		await back_to_idle("wheel placing")
	# wheel over the HUD (tray / card) must not zoom
	var d0 := level.camera.distance_target
	await click(tile_screen(archer.pos))
	await wait(0.3)
	await wheel(centre_of(hud.tray), true, 4)
	if hud.inspector.visible: await wheel(centre_of(hud.inspector), true, 4)
	await wait(0.3)
	note("wheel over the HUD: distance %.2f → %.2f" % [d0, level.camera.distance_target])
	expect(absf(level.camera.distance_target - d0) < 0.01, "camera", "wheel over HUD", "the wheel over the tray / card zoomed the board")
	# resize mid-level: 1280×720 and back
	var orig := DisplayServer.window_get_size()
	for sz in [Vector2i(1280, 720), orig]:
		DisplayServer.window_set_size(sz)
		await frames(12)
		await wait(1.0)
		note("window %s → root %s visible %s" % [sz, root.size, root.get_visible_rect().size])
		await step("resized_%dx%d" % [sz.x, sz.y], true)
		await hover(hud.top_bar.end_turn, "resized end turn %d" % sz.x)
	await back_to_idle("end of edge")
