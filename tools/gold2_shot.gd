extends SceneTree
## Dev script: screenshots the gold / tier / Rewards changes of 2026-10-16 (Upgrades — Design § Gold, Missions & Guild —
## Design § Tier / Rewards popup, Backpack — Design; UI/UX mockup screens-b/mission-rewards.html) under Xvfb.
##   cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot --resolution 1280x720 tools/gold2_shot.gd -- /srv/wiki-art/godot/renders/gold2
## Own save (user://gold2_shot.json, deleted first): Chapters 1–2 won, 240 gold, a few tokens, Night Watch won once
## (its first-win drop claimed). Render-only fake: Night Watch gets a chance drop (30% Ember Core) in memory so the
## popup's Chance row shows (the content has no chanceDrops yet).
## PNGs <out dir>/gold2_<n>_<frame>.png: mission_board (tier diamonds + Rewards), rewards_popup (Night Watch over the
## board), mission_detail (Night Watch: tier + Rewards, no note line), detail_rewards (the popup over the detail),
## lobby_create (Create room with Hold the Gate: tier + Rewards), backpack (no found-in / gold sub-line),
## upgrade_pay (base Archer level 2 → 3: "Pay 175", the "+5" chip inside the Max HP tile), upgrade_pay_nogold (0 gold:
## Pay disabled, no line), upgrade_form (an Archer wearing Fire Archer: the form ladder, no gold row).
## The screens are untyped here: their classes name the GameApp autoload, which a SceneTree script cannot compile.

var out_dir := "user://gold2"
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
	save.path = "user://gold2_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", false)
	app.ensure_loaded()
	await _until(func(): return not flow.is_loading, 30.0)
	if current_scene != null: current_scene.queue_free()
	save.towers.hand.clear()
	var archers := []
	for i in 3: archers.append(save.towers.add("archer"))
	for id in ["guardian", "mage", "priest"]: save.towers.add_to_hand(save.towers.add(id).id)
	for a in archers: save.towers.add_to_hand(a.id)
	for pair in [["fire-arrow", 2], ["arcane-shard", 3], ["ember-core", 1], ["poison-gland", 1]]:
		SaveTools.run("add_tokens", save.data, app.catalog, pair)
	_win_main(1)
	_win_main(2)
	var p = save.profile
	p.camp_seen = true
	p.guild_seen = true
	for f in ["guild_tour_seen", "blacksmith_seen"]:
		if f in p: p.set(f, true)
	save.data.gold = 240
	# Night Watch won once: its first-win drop is claimed
	var nw: MissionDef = app.mission("night-watch")
	var r := LevelResult.new()
	r.level_id = nw.level_id
	r.won = true
	r.rounds = 9
	r.base_hp_pct = 80
	save.missions.record(r, nw.id)
	nw.chance_drops = [{"token": "ember-core", "chance": 0.3}] # render-only fake (see the header)
	# Archer 1: level 2, step 3 with the win and 42 / 60 damage done, 25 / 200 gold paid
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
	# Archer 2: level 3, wearing Fire Archer (form level 1, its step to 2 half done)
	var a2: OwnedTower = archers[1]
	a2.level = 3
	a2.forms = ["archer-fire"]
	a2.form = "archer-fire"
	save.save()
	# the fake relay (connected: the lobby opens online with Create room)
	var relay := FakeRelay.new()
	relay.shared_pool_of = func(l): return CoopLevels.shared_pool(l)
	var net = root.get_node("Net")
	net.player_name_override = "Eren"
	net.connect_fake(relay)
	net.practice = false
	net.auto_poll = true
	relay.player_pings = {}
	net._rtt_in = 1e9
	print("gold ", app.gold(), " tiers ", app.missions().map(func(m): return "%s:%d/%d" % [m.id, m.tier, m.win_gold]))
	# the Guild: board, Rewards popup, detail, Rewards over the detail, the co-op create popup
	var guild = load("res://game/ui/screens/guild.tscn").instantiate()
	root.add_child(guild)
	await _frames(40)
	if guild.welcome_card.visible: guild.close_welcome()
	await _frames(10)
	var board = guild.open_missions()
	await _frames(60)
	await _shot("mission_board")
	var rw = board.open_rewards("night-watch")
	await _frames(25)
	print("rewards rows: ", rw.rows.map(func(x): return x.kind))
	await _shot("rewards_popup")
	rw.close()
	await _frames(15)
	var det = board.open_detail("night-watch")
	await _frames(60)
	await _shot("mission_detail")
	var rw2 = load("res://game/ui/screens/rewards.gd").show_over(det._popups, "night-watch")
	await _frames(25)
	await _shot("detail_rewards")
	rw2.close()
	await _frames(10)
	det.close()
	await _frames(15)
	board.close()
	await _frames(15)
	var lobby = guild.open_multiplayer("hold-the-gate")
	await _frames(60)
	await _shot("lobby_create")
	lobby.close()
	await _frames(10)
	guild.queue_free()
	await _frames(4)
	# the Backpack (over the Camp)
	var camp = load("res://game/ui/screens/camp.tscn").instantiate()
	root.add_child(camp)
	await _frames(40)
	camp.end_tour()
	await _frames(4)
	var bp = camp.backpack_button.open_backpack()
	await _frames(25)
	print("backpack rows: ", bp.rows)
	await _shot("backpack")
	bp.close()
	await _frames(10)
	camp.queue_free()
	await _frames(4)
	# the Blacksmith's Upgrade view: base with gold, no gold, a form
	var smith = load("res://game/ui/screens/blacksmith.tscn").instantiate()
	root.add_child(smith)
	await _frames(40)
	if smith.welcome_card.visible: smith.close_welcome()
	if smith.has_method("end_tour"): smith.end_tour()
	await _frames(10)
	var up = smith.open_upgrade()
	await _frames(40)
	up.open_view(a1.id)
	await _frames(40)
	print("pay button: '", up.pay_button.text if up.pay_button != null else "none", "'")
	await _shot("upgrade_pay")
	save.data.gold = 0
	up.refresh_view()
	smith.backpack_button.refresh_all(self)
	await _frames(10)
	print("no gold: pay interactable ", up.pay_button.interactable if up.pay_button != null else "none")
	await _shot("upgrade_pay_nogold")
	up.back_to_picker()
	await _frames(30)
	up.open_view(a2.id)
	await _frames(40)
	print("form view: ladder '", up.ladder, "' pay button ", up.pay_button)
	await _shot("upgrade_form")
	smith.queue_free()
	await _frames(4)
	print("GOLD2 SHOT DONE")
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

func _until(cond: Callable, seconds: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < seconds * 1000.0:
		await process_frame

func _frames(n: int) -> void:
	for i in n: await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/gold2_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
