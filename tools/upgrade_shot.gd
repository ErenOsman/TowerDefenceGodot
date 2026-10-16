extends SceneTree
## Dev script: screenshots the Upgrade screens (Upgrades — Design; UI/UX mockups screens-b/upgrade*.html, lv-chip,
## end-screen-tasks) under Xvfb.
##   ~/godot/run.sh --daemon projects/td --resolution 1280x720 -s tools/upgrade_shot.gd -- /srv/wiki-art/godot/renders/upgrade
## Uses its own save (user://upgrade_shot.json, deleted first): Chapters 1–2 won (the Blacksmith is open) and the
## mockup's ten towers (4 Archers, 2 Guardians, 2 Mages, 2 Priests) at mixed levels, five of them ready.
## PNGs <out dir>/upgrade_<n>_<frame>.png: picker, picker_ready (the "Ready to upgrade" toggle), view (Archer Lv 2,
## 42 / 60 damage: disabled), view_ready, confirm, beat (after the upgrade: level 4, the gold line), form (wearing
## Fire Archer: its ladder, ready), form_blocked (wearing Fire Archer Lv 2: "Raise Archer to level 3 first"), max (an
## Archer at level 5), codex (Archer's Overview: Levels and the header chip), lv_hand (the hand editor's tiles),
## lv_hud (tray, the placed medallion, the inspector and the selected tower's full plate), end_tasks (a won level's
## end screen with task rows and a ready line; the advances are posed in memory).

var out_dir := "user://upgrade"
var _n := 0
## Only these frames are saved (2nd arg, comma separated, e.g. "view,view_ready,form_blocked,max"); [] = all. The
## numbering stays the full run's; the level part is skipped when none of its frames is asked for.
var only: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: only = Array(args[1].split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveData")
	var app = root.get_node("GameApp")
	save.path = "user://upgrade_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	# Chapters 1 and 2 won (results only): the Blacksmith is open, levels show
	var k := 0
	for ch in app.catalog.chapters:
		if ch == null or ch.kind != ChapterKind.Main: continue
		k += 1
		if k > 2: continue
		for e in ch.levels:
			var r := LevelResult.new()
			r.level_id = e.level.get_id()
			r.won = true
			save.progress.record(r)
	save.profile.camp_seen = true
	var t := {}
	for pair in [["archer", 4], ["guardian", 2], ["mage", 2], ["priest", 2]]:
		t[pair[0]] = []
		for i in pair[1]: t[pair[0]].append(save.towers.add(pair[0]))
	var a1: OwnedTower = t.archer[0]   # Lv 2, 42 / 60 damage; Fire Archer Lv 1 ready
	a1.level = 2
	a1.task_progress["3"] = [1, 42]
	a1.task_progress["4"] = [1, 4]
	a1.forms.append("archer-fire")
	a1.task_progress["archer-fire:2"] = [1]
	var a2: OwnedTower = t.archer[1]   # Lv 1, ready
	a2.task_progress["2"] = [1]
	var a3: OwnedTower = t.archer[2]   # Lv 2 with Fire Archer Lv 2 waiting for the base (form blocked)
	a3.level = 2
	a3.forms.append("archer-fire")
	a3.form_levels["archer-fire"] = 2
	a3.task_progress["archer-fire:3"] = [80]
	var a4: OwnedTower = t.archer[3]   # Lv 5
	a4.level = 5
	t.guardian[0].level = 2
	t.guardian[0].task_progress["3"] = [1, 40]
	t.mage[0].level = 3
	t.mage[1].task_progress["2"] = [1]
	t.priest[1].level = 2
	t.priest[1].task_progress["3"] = [1, 99]
	for o in [a1, t.guardian[0], t.mage[0], t.priest[1]]: save.towers.add_to_hand(o.id)
	save.save()
	print("blacksmith open: ", app.blacksmith_unlocked(), " ready: ", app.upgrade_ready_count())
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	TdMenu.menu_background(host)
	var up: TdPopup = load("res://game/ui/screens/upgrade.tscn").instantiate() # opens on the first tower (a1)
	up.free_on_close = true
	host.add_child(up)
	up.open()
	await _frames(40)
	await _shot("picker")
	up.collection.filter["ready"] = true
	up.collection.refresh()
	await _frames(10)
	await _shot("picker_ready")
	up.collection.filter["ready"] = false
	up.collection.refresh()
	up.open_view(a1.id)
	await _frames(40)
	await _shot("view")
	a1.task_progress["3"] = [1, 60]
	up.refresh_view()
	await _frames(10)
	await _shot("view_ready")
	up.open_confirm()
	await _frames(25)
	await _shot("confirm")
	print("upgrade: ", up.confirm_upgrade(), " level ", a1.level, " saved progress ", a1.task_progress)
	await _frames(25)
	await _shot("beat")
	# the view works on the CURRENT form (Eren 2026-10-16): wearing Fire Archer shows its ladder
	a1.form = "archer-fire"
	save.save()
	up.refresh_view()
	await _frames(12)
	await _shot("form")
	up.back_to_picker()
	await _frames(20)
	a3.form = "archer-fire"
	up.open_view(a3.id)
	await _frames(30)
	await _shot("form_blocked")
	up.back_to_picker()
	await _frames(20)
	up.open_view(a4.id)
	await _frames(30)
	await _shot("max")
	if not only.is_empty() and not (only.has("codex") or only.has("lv_hand") or only.has("lv_hud") or only.has("end_tasks")):
		print("UPGRADE SHOT DONE")
		quit()
		return
	# Esc steps back one step: view → picker → closed
	up.back()
	await _frames(6)
	print("esc 1 → view '", up.view, "' open ", up.is_open)
	up.back()
	await _frames(20)
	print("esc 2 → open ", is_instance_valid(up) and up.is_open)
	# the Codex: Archer's Overview with its Levels and the header chip (best Archer level 5)
	save.codex.discover(CodexSection.Towers, "archer")
	var cx: TdPopup = load("res://game/ui/screens/codex.tscn").instantiate()
	host.add_child(cx)
	cx.open()
	await _frames(30)
	cx.show_section(CodexSection.Towers)
	for e in cx.entries:
		if e.id == "archer": cx.select(e)
	cx.show_page_tab("overview")
	await _frames(20)
	await _shot("codex")
	cx.close()
	await _frames(20)
	# the hand editor: Lv chips on the tiles
	var he: TdPopup = load("res://game/ui/screens/hand_editor.tscn").instantiate()
	host.add_child(he)
	he.open()
	await _frames(40)
	await _shot("lv_hand")
	he.close()
	await _frames(20)
	host.queue_free()
	# a level: the tray with Lv chips, one placed and selected (medallion, inspector name row, full plate), then a win
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
		await _frames(30)
		await _shot("lv_hud")
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
		print("counted advances: ", level.task_advances)
		# posed: the mockup's two rows and the ready line
		level.task_advances = [
			{"tower": a1.id, "index": 3, "name": "Archer", "form": "", "to": 4, "task": 1, "kind": TowerTaskKind.Kills,
				"text": "Defeat 10 enemies with it", "noun": "kills", "before": 5, "after": 8, "gain": 3, "count": 10, "done": false, "ready": false},
			{"tower": t.guardian[0].id, "index": 7, "name": "Guardian", "form": "", "to": 3, "task": 0, "kind": TowerTaskKind.WinMission,
				"text": "Win a mission with this tower", "noun": "missions won", "before": 0, "after": 1, "gain": 1, "count": 1, "done": true, "ready": true},
		]
		level.hud.end_screen.show_outcome(Outcome.Won)
		await create_timer(0.8, true, false, true).timeout
		await _shot("end_tasks")
	print("UPGRADE SHOT DONE")
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
	if not only.is_empty() and not only.has(label): return
	var p := "%s/upgrade_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
