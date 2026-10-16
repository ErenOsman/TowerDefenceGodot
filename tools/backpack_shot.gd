extends SceneTree
## Dev script: screenshots the Backpack and the gold screens (Backpack — Design; UI/UX mockups screens-b/backpack.html,
## backpack-button.html, upgrade-pay.html, upgrade-pay-nogold.html) under Xvfb.
##   cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot --resolution 1280x720 tools/backpack_shot.gd -- /srv/wiki-art/godot/renders/backpack
## Uses its own save (user://backpack_shot.json, deleted first): Chapters 1–2 won (Camp, Guild and Blacksmith open,
## every welcome seen), 240 gold, tokens Fire Arrow ×2, Arcane Shard ×3, Ember Core ×1, Poison Gland ×1 and Yew Bow
## earned then spent (×0, dimmed); Steel Plate never earned (hidden). An Archer at level 2 with 42 / 60 damage and
## 25 / 40 gold paid.
## PNGs <out dir>/backpack_<n>_<frame>.png: camp (the button top-right), backpack (the popup over the Camp), guild,
## mission_board (cards with gold in Each win / First win), mission_detail (Patrol's Drops), blacksmith,
## workshop_picker, upgrade_picker (the button left of ×), upgrade_pay (25 / 40, "Pay 15"), upgrade_paid (after Pay:
## 40 / 40, gold 225), upgrade_pay_partial (10 gold: "Pay 10", "You have 10: pays what you can."),
## upgrade_pay_nogold (0 gold: disabled, the red line), end_gold (Patrol won: the rewards row with "+40 gold").
## The screens are untyped here: their classes name the GameApp autoload, which a SceneTree script cannot compile.

var out_dir := "user://backpack"
var _n := 0
var save
var app

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("SaveData")
	app = root.get_node("GameApp")
	var flow = root.get_node("SceneFlow")
	save.path = "user://backpack_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", false)
	app.ensure_loaded()
	await _until(func(): return not flow.is_loading, 30.0)
	if current_scene != null: current_scene.queue_free() # the boot's menu would draw over the places
	save.towers.hand.clear()
	var archers := []
	for i in 3: archers.append(save.towers.add("archer"))
	for id in ["guardian", "mage", "priest"]: save.towers.add_to_hand(save.towers.add(id).id)
	for a in archers: save.towers.add_to_hand(a.id)
	for pair in [["fire-arrow", 2], ["arcane-shard", 3], ["ember-core", 1], ["poison-gland", 1], ["yew-bow", 1]]:
		SaveTools.run("add_tokens", save.data, app.catalog, pair)
	save.tokens.spend({"yew-bow": 1})
	_win_main(1)
	_win_main(2)
	var p = save.profile
	p.camp_seen = true
	p.guild_seen = true
	for f in ["guild_tour_seen", "blacksmith_seen"]:
		if f in p: p.set(f, true)
	save.data.gold = 240
	var a1: OwnedTower = archers[0]
	a1.level = 2
	var t: TowerType = app.tower_type("archer")
	var step := TowerLevels.step_for(a1, t, "")
	var counts := []
	for i in step.tasks.size(): counts.append(0)
	counts[0] = 1
	if step.tasks.size() > 2: counts[1] = 42
	var gi := TowerTasks.gold_task_index(step)
	counts[gi] = 25
	a1.task_progress[TowerLevels.step_key("", step.to)] = counts
	save.save()
	print("camp ", app.camp_unlocked(), " guild ", app.guild_unlocked(), " blacksmith ", app.blacksmith_unlocked(), " gold ", app.gold())
	# the Camp with the button, then the popup
	var camp = load("res://game/ui/screens/camp.tscn").instantiate()
	root.add_child(camp)
	await _frames(40)
	camp.end_tour()
	await _frames(4)
	await _shot("camp")
	var bp = camp.backpack_button.open_backpack()
	await _frames(25)
	print("backpack rows: ", bp.rows.map(func(r): return "%s %s%s" % [r.name, r.count_text, " (dim)" if r.dim else ""]))
	await _shot("backpack")
	bp.close()
	await _frames(15)
	print("closed: open=", is_instance_valid(bp) and bp.is_open, " button count ", camp.backpack_button.count)
	camp.queue_free()
	await _frames(4)
	# the Guild: the button, the board's cards and Patrol's detail with gold
	var guild = load("res://game/ui/screens/guild.tscn").instantiate()
	root.add_child(guild)
	await _frames(40)
	if guild.welcome_card.visible: guild.close_welcome()
	await _frames(10)
	await _shot("guild")
	var board = guild.open_missions()
	await _frames(60)
	await _shot("mission_board")
	board.open_detail("patrol")
	await _frames(60)
	await _shot("mission_detail")
	guild.queue_free()
	await _frames(4)
	# the Blacksmith, the Workshop picker, the Upgrade picker and view
	var smith = load("res://game/ui/screens/blacksmith.tscn").instantiate()
	root.add_child(smith)
	await _frames(40)
	if smith.welcome_card.visible: smith.close_welcome()
	if smith.has_method("end_tour"): smith.end_tour()
	await _frames(10)
	await _shot("blacksmith")
	var ws: TdPopup = smith.open_modify()
	await _frames(40)
	await _shot("workshop_picker")
	ws.close()
	await _frames(20)
	var up = smith.open_upgrade()
	await _frames(40)
	await _shot("upgrade_picker")
	up.open_view(a1.id)
	await _frames(40)
	print("pay button: '", up.pay_button.text if up.pay_button != null else "none", "'")
	await _shot("upgrade_pay")
	var got: int = up.pay()
	await _frames(15)
	print("paid ", got, " gold left ", app.gold(), " view button ", up.backpack_button.count, " place button ", smith.backpack_button.count,
		" progress ", a1.task_progress)
	await _shot("upgrade_paid")
	a1.task_progress[TowerLevels.step_key("", step.to)][gi] = 25
	save.data.gold = 10
	up.refresh_view()
	smith.backpack_button.refresh_all(self)
	await _frames(10)
	await _shot("upgrade_pay_partial")
	save.data.gold = 0
	up.refresh_view()
	smith.backpack_button.refresh_all(self)
	await _frames(10)
	print("no gold: pay interactable ", up.pay_button.interactable if up.pay_button != null else "none")
	await _shot("upgrade_pay_nogold")
	smith.queue_free()
	await _frames(4)
	# a won mission's end screen with its gold
	save.data.gold = 0
	save.missions.rest_all()
	await _end_screen("patrol", "end_gold")
	print("BACKPACK SHOT DONE")
	quit()

## Wins every level of main chapter n (results only, no rewards).
func _win_main(n: int) -> void:
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

func _end_screen(mission_id: String, label: String) -> void:
	var m: MissionDef = app.mission(mission_id)
	LevelLaunch.request(app.mission_level(m), mission_id)
	var level = load("res://game/level/level.tscn").instantiate()
	level.instant_override = false
	root.add_child(level)
	await _frames(6)
	if level.setup_error != null and str(level.setup_error) != "":
		print("SETUP ERROR: ", level.setup_error)
		level.queue_free()
		return
	level.skip_sequence()
	await _settle(level)
	level.instant_override = true
	for rr in 80:
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
	print(label, ": drops ", level.drops, " gold ", level.gold_drop, " '", level.gold_text, "' saved gold ", app.gold())
	await _shot(label)
	level.queue_free()
	await _frames(6)

func _settle(level) -> void:
	for i in 900:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _until(cond: Callable, seconds: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < seconds * 1000.0:
		await process_frame

func _frames(n: int) -> void:
	for i in n: await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/backpack_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
