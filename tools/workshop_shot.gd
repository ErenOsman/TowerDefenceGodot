extends SceneTree
## Dev script: screenshots the Workshop (Workshop — Design; mockups workshop-*.html) under Xvfb.
##   flock /home/ubuntu/godot/.td.lock ~/godot/run.sh projects/td -s tools/workshop_shot.gd [-- <out dir>]
##   … --resolution 1280x720 -s tools/workshop_shot.gd -- user://workshop720 workshop   (workshop: only the Workshop frames)
## Uses its own save (user://workshop_shot.json, deleted first): the mockup's collection (6 Archers, 5 Guardians, 4
## Mages…; "Archer #1 · tower 3" is the one modified) and its tokens (Fire Arrow 2, Poison Gland 0, Yew Bow 1, Ember
## Core 0, Steel Plate 1, Arcane Shard 3, seeded with SaveTools add_tokens).
## PNGs <out dir>/workshop_<n>_<step>.png: modify (Archer, Fire Archer selected: can unlock), confirm, unlocked,
## used (Use this form), inferno (needs tokens), poison, guardian (Bastion: can unlock), slide (mid-slide), picker
## (Fire Archer and Storm Mage formed), hand (badges in the hand editor), codex_* (the Archer's Forms page with Fire Archer picked, its Overview and
## Abilities, the Guardian's empty Forms page, an enemy page with the disabled Immunities tab), hud_tray and
## hud_placed (chapter1-2 with the Fire Archer in hand: tray badge, board medallion, inspector), victory (token row).

var out_dir := "user://workshop"
var _n := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveData")
	var app = root.get_node("GameApp")
	save.path = "user://workshop_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	var counts := {"archer": 6, "guardian": 5, "mage": 4, "priest": 5, "wisp": 4, "ballista": 3, "alchemist": 4, "drummer": 3, "cannon": 3}
	var by_type := {}
	for t in app.catalog.tower_types:
		by_type[t.get_id()] = []
		for i in counts.get(t.get_id(), 2):
			var o: OwnedTower = save.towers.add(t.get_id())
			by_type[t.get_id()].append(o)
			if save.towers.hand.size() < 4 and i == 2 and t.get_id() in ["archer", "guardian", "mage", "priest"]: save.towers.add_to_hand(o.id)
	for pair in [["fire-arrow", 2], ["yew-bow", 1], ["steel-plate", 1], ["arcane-shard", 3]]:
		print(SaveTools.run("add_tokens", save.data, app.catalog, pair))
	save.save()
	# the Camp: the Workshop station locked ("Opens after Chapter 2"), then open once Chapter 2 is won (results
	# recorded without rewards, so the collection and tokens stay the mockup's)
	if not OS.get_cmdline_user_args().has("workshop"):
		save.profile.camp_seen = true
		save.save()
		var camp_scene: PackedScene = load("res://game/ui/screens/camp.tscn")
		var camp = camp_scene.instantiate()
		root.add_child(camp)
		await _frames(40)
		await _shot("camp_locked")
		camp.queue_free()
		await _frames(4)
		for n in [1, 2]:
			var k := 0
			for ch in app.catalog.chapters:
				if ch == null or ch.kind != ChapterKind.Main: continue
				k += 1
				if k != n: continue
				for e in ch.levels:
					var r := LevelResult.new()
					r.level_id = e.level.get_id()
					r.won = true
					save.progress.record(r)
		save.save()
		camp = camp_scene.instantiate()
		root.add_child(camp)
		await _frames(40)
		await _shot("camp_unlocked")
		camp.queue_free()
		await _frames(4)
	var archer: OwnedTower = by_type["archer"][2]
	var guardian: OwnedTower = by_type["guardian"][1]
	var mage: OwnedTower = by_type["mage"][1]
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	TdMenu.menu_background(host)
	var ws: TdPopup = load("res://game/ui/screens/workshop.tscn").instantiate()
	host.add_child(ws)
	ws.tower_id = archer.id
	ws.open()
	await _frames(30)
	# modify: Archer, Fire Archer selected (Can unlock)
	ws.open_modify(archer.id)
	ws.select_node("archer-fire")
	await _frames(40)
	await _shot("modify")
	ws.card_action() # Unlock → the confirm
	await _frames(20)
	await _shot("confirm")
	ws.confirm_unlock()
	await _frames(4)
	await _shot("unlocked")
	print("after unlock: fire-arrow ", save.tokens.count("fire-arrow"), " forms ", archer.forms, " form '", archer.form, "'")
	ws.card_action() # Use this form
	await _frames(12)
	await _shot("used")
	print("after use: form '", archer.form, "' saved: ", FileAccess.get_file_as_string(save.path).contains("\"form\": \"archer-fire\"") or FileAccess.get_file_as_string(save.path).contains("\"form\":\"archer-fire\""))
	ws.select_node("archer-inferno")
	await _frames(12)
	await _shot("inferno")
	ws.select_node("archer-poison")
	await _frames(12)
	await _shot("poison")
	# arrows: from Poison Archer left goes to the root
	var ev := InputEventKey.new()
	ev.keycode = KEY_LEFT; ev.pressed = true
	print("focus owner: ", root.get_viewport().gui_get_focus_owner())
	Input.parse_input_event(ev)
	await _frames(6)
	print("arrow left from poison → '", ws.node_id, "'")
	var up := InputEventKey.new()
	up.keycode = KEY_UP; up.pressed = true
	ws.select_node("archer-fire")
	Input.parse_input_event(up)
	await _frames(6)
	print("arrow up from fire → '", ws.node_id, "'")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER; enter.pressed = true
	ws.select_node("")
	Input.parse_input_event(enter)
	await _frames(6)
	print("enter on Archer (unlocked, not current: Use this form) → form '", archer.form, "'")
	ws.select_node("archer-fire")
	Input.parse_input_event(enter)
	await _frames(6)
	print("enter on Fire Archer → form '", archer.form, "'")
	ws.back_to_picker()
	await _frames(30)
	ws.open_modify(guardian.id)
	ws.select_node("guardian-bastion")
	await _frames(40)
	await _shot("guardian")
	# mid-slide back to the picker
	# mid-slide back to the picker (posed: on llvmpipe the grid rebuild eats the 0.35 s in one frame)
	ws.back_to_picker()
	await _frames(2)
	if ws._slide_tween != null: ws._slide_tween.kill()
	ws._slider.position.x = ws._slide_x() - ws._pane_step() * 0.45
	await _frames(2)
	await _shot("slide")
	# the picker: Fire Archer and Storm Mage formed
	mage.forms.append("mage-storm")
	mage.form = "mage-storm"
	save.save()
	ws.close()
	await _frames(20)
	ws.tower_id = archer.id
	ws.open()
	await _frames(40)
	await _shot("picker")
	if OS.get_cmdline_user_args().has("workshop"):
		print("WORKSHOP SHOT DONE")
		quit()
		return
	ws.close()
	await _frames(20)
	# the hand editor shows the badges and form names
	var he: TdPopup = load("res://game/ui/screens/hand_editor.tscn").instantiate()
	host.add_child(he)
	save.towers.hand[0] = archer.id
	he.open()
	await _frames(40)
	await _shot("hand")
	he.close()
	await _frames(20)
	# the Codex: the Archer's page, scrolled to its forms (Fire Archer unlocked: normal; the others desaturated)
	save.codex.discover(CodexSection.Towers, "archer")
	var cx: TdPopup = load("res://game/ui/screens/codex.tscn").instantiate()
	host.add_child(cx)
	cx.open()
	await _frames(30)
	cx.show_section(CodexSection.Towers)
	for e in cx.entries:
		if e.id == "archer": cx.select(e)
	cx.show_page_tab("forms")
	cx.show_form("archer-fire")
	await _frames(10)
	await _shot("codex_forms")
	cx.show_page_tab("overview")
	await _frames(10)
	await _shot("codex_overview_form")
	cx.show_page_tab("abilities")
	await _frames(10)
	await _shot("codex_abilities_form")
	save.codex.discover(CodexSection.Towers, "guardian")
	cx.show_section(CodexSection.Towers)
	for e in cx.entries:
		if e.id == "guardian": cx.select(e)
	cx.show_page_tab("forms")
	await _frames(10)
	await _shot("codex_forms_empty")
	cx.show_section(CodexSection.Enemies)
	var first = cx.entries[0]
	save.codex.discover(CodexSection.Enemies, first.id)
	cx.show_section(CodexSection.Enemies)
	for e in cx.entries:
		if e.id == first.id: cx.select(e)
	await _frames(10)
	await _shot("codex_enemy")
	cx.close()
	await _frames(20)
	host.queue_free()
	# a level: the Fire Archer in the tray (badge on the miniature), placed (badge on the medallion) and selected
	# (inspector), then a win: the end screen's token row
	save.save()
	var scene: PackedScene = load("res://game/level/level.tscn")
	var level = scene.instantiate()
	level.test_level_id = "chapter1-2"
	level.instant_override = false
	root.add_child(level)
	await _frames(6)
	if level.setup_error != null:
		print("SETUP ERROR: ", level.setup_error)
	else:
		level.skip_sequence()
		await _settle(level)
		await _frames(20)
		await _shot("hud_tray")
		var hand: Array = level.session.hand
		var placed := false
		for x in level.session.state.grid.width:
			for y in level.session.state.grid.height:
				if placed: break
				var p := Vector2i(x, y)
				if level.session.can_place(hand[0].id, p):
					level.toggle_placing(hand[0].id)
					level.click_tile(p)
					placed = true
		await _settle(level)
		var e: Entity = level.session.placed_tower(hand[0].id)
		if e != null: level.select(e.id)
		await _frames(20)
		await _shot("hud_placed")
		level.instant_override = true
		for r in 60:
			if level.session.is_over: break
			for en in level.session.enemies:
				if not en.alive: continue
				var fx := DamageEffect.new()
				fx.amount = Formula.new("999")
				fx.target_id = en.id
				fx.source = 0
				level.session.resolver.run(fx)
			level.session.after_command()
			level.version += 1
			await _settle(level)
			if level.session.is_over: break
			level.end_round()
			await _settle(level)
		for i in 600:
			if level.hud.end_screen.visible: break
			await process_frame
		await create_timer(0.8, true, false, true).timeout
		print("victory drops: ", level.drops)
		await _shot("victory")
	print("WORKSHOP SHOT DONE")
	quit()

func _settle(level) -> void:
	for i in 900:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/workshop_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
