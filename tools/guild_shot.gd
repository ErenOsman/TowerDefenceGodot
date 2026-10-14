extends SceneTree
## Dev script: screenshots the Missions & Guild screens (Missions & Guild — Design; mockups screens-b/camp-signpost*,
## guild*, mission-board, mission-detail*, hand-select-mission, lobby-mission-picker, lobby-list-mission,
## lobby-auto-left, lobby-room-tired, end-screen-mission*) under Xvfb, 1920×1080.
##   flock /home/ubuntu/godot/.td.lock ~/godot/run.sh /home/ubuntu/godot/projects/td -s tools/guild_shot.gd -- <out dir>
## Uses its own save (user://guild_shot.json, deleted first): the mockup's collection and tokens, a 5-tower hand
## (Archer, Archer, Guardian, Priest, Mage). Night Watch is won and played today (Done today, first win claimed);
## for the board's locked card The Glutton Returns is given "Win Hold the Gate first" IN MEMORY only (the content opens
## every mission with the Guild). Co-op screens run against an in-process FakeRelay with bots (no network).
## PNGs <out dir>/guild_<n>_<step>.png: camp_signpost_locked, camp_signpost, guild_welcome, guild, mission_board,
## detail, detail_tired, detail_all_tired, detail_done, detail_coop, hand_editor_mission, lobby_mission_picker,
## lobby_list, lobby_auto_left, room_tired, end_mission, end_mission_last.

var out_dir := "user://guild"
## Argument "guild": only the Guild's welcome and ring frames (no camp, board, details…).
## Second argument "720" (with --resolution 1280x720): only the board and the details (normal, all tired, co-op).
var small := false
var _n := 0
var save
var app
var net: RelayClient
var relay: FakeRelay

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	small = args.has("720")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("SaveData")
	app = root.get_node("GameApp")
	var flow = root.get_node("SceneFlow")
	save.path = "user://guild_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", false)
	app.ensure_loaded()
	await _until(func(): return not flow.is_loading, 30.0)
	# the collection and the hand
	var counts := {"archer": 6, "guardian": 5, "mage": 4, "priest": 5, "wisp": 4, "ballista": 3, "alchemist": 3}
	var by_type := {}
	save.towers.hand.clear()
	for t in app.catalog.tower_types:
		by_type[t.get_id()] = []
		for i in counts.get(t.get_id(), 2):
			by_type[t.get_id()].append(save.towers.add(t.get_id()))
	for pick in [["archer", 0], ["archer", 1], ["guardian", 0], ["priest", 0], ["mage", 0]]:
		save.towers.add_to_hand(by_type[pick[0]][pick[1]].id)
	for pair in [["fire-arrow", 2], ["yew-bow", 1], ["steel-plate", 1], ["arcane-shard", 3]]:
		SaveTools.run("add_tokens", save.data, app.catalog, pair)
	# Chapter 1 and half of Chapter 2 won (results only: the collection stays the mockup's)
	_win_main(1, 99)
	_win_main(2, 2)
	save.profile.camp_seen = true
	save.save()
	var camp_scene: PackedScene = load("res://game/ui/screens/camp.tscn")
	var camp
	if not small:
		camp = camp_scene.instantiate()
		root.add_child(camp)
		await _frames(40)
		await _shot("camp_signpost_locked")
		camp.queue_free()
		await _frames(4)
	_win_main(2, 99)
	save.save()
	print("guild unlocked: ", app.guild_unlocked())
	if not small:
		camp = camp_scene.instantiate()
		root.add_child(camp)
		await _frames(40)
		await _shot("camp_signpost")
		camp.queue_free()
		await _frames(4)
	# Night Watch: won once and played today (Done today, first win claimed)
	var nw: MissionDef = app.mission("night-watch")
	var r := LevelResult.new()
	r.level_id = nw.level_id
	r.won = true
	r.rounds = 9
	r.base_hp_pct = 80
	save.missions.record(r, nw.id)
	MissionBoard.record_play(nw, save.missions, [])
	# the board's locked card (render only)
	app.mission("glutton-returns").requires = ["hold-the-gate"]
	save.save()
	# the fake relay (connected now: the lobby opens online)
	relay = FakeRelay.new()
	relay.shared_pool_of = func(l): return CoopLevels.shared_pool(l)
	net = root.get_node("Net")
	net.player_name_override = "Eren"
	net.connect_fake(relay)
	net.practice = false
	net.auto_poll = true
	relay.player_pings = {}
	net._rtt_in = 1e9
	# the Guild: the welcome card, then the ring
	var guild = load("res://game/ui/screens/guild.tscn").instantiate()
	root.add_child(guild)
	await _frames(40) # the guild hall loads and the station buttons settle
	if not small: await _shot("guild_welcome")
	guild.close_welcome()
	await _frames(10)
	if not small: await _shot("guild")
	if OS.get_cmdline_user_args().has("guild"): # only the Guild frames (welcome + ring)
		print("GUILD SHOT DONE")
		quit()
		return
	# the mission board
	var board = guild.open_missions()
	await _boards()
	await _shot("mission_board")
	# details
	var hand: Array = save.towers.hand
	var d = board.open_detail("patrol")
	await _boards()
	await _shot("detail")
	save.missions.tire(hand[1], MissionBoard.day_of())
	d.refresh()
	await _frames(10)
	if not small: await _shot("detail_tired")
	for id in hand: save.missions.tire(id, MissionBoard.day_of())
	d.refresh()
	await _frames(10)
	await _shot("detail_all_tired")
	save.missions.tired.clear()
	d.select_mission("night-watch")
	await _boards()
	if not small: await _shot("detail_done")
	d.select_mission("hold-the-gate")
	await _boards()
	await _shot("detail_coop")
	if small:
		print("GUILD SHOT DONE")
		quit()
		return
	# the hand editor for a mission: a 6th tower, the Guardian and an Archer tired
	save.towers.add_to_hand(by_type["wisp"][0].id)
	save.missions.tire(hand[1], MissionBoard.day_of())
	save.missions.tire(hand[2], MissionBoard.day_of())
	d.select_mission("patrol")
	await _frames(20)
	var he = d.open_hand_editor()
	await _frames(40)
	await _shot("hand_editor_mission")
	# its detail card scrolled down to Tower Walk (the hourglass "Tired" line and the action under it)
	he._select(hand[1])
	await _frames(6)
	var sc: ScrollContainer = he._detail.get_child(0)
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await _frames(6)
	await _shot("hand_editor_scrolled")
	he.close()
	d.close()
	await _frames(20)
	board.close()
	await _frames(20)
	# co-op: the lobby from Find a room (Create room with Hold the Gate picked)
	var lobby: CoopLobby = guild.open_multiplayer("hold-the-gate")
	await _boards()
	await _shot("lobby_mission_picker")
	for c in lobby._popups.get_children():
		if c is TdPopup: c.close()
	await _frames(10)
	var mert := _bot("Mert")
	_say(mert, NetProtocol.create("Quick slimes", "chapter2-2", 2, "", ["cannon"]))
	var ayla := _bot("Ayla")
	_say(ayla, NetProtocol.create("Herkes gelsin!", "chapter2-1", 6, "", ["wisp", "archer"]))
	var cagri := _bot("Çağrı")
	_say(cagri, NetProtocol.create("Akşam savunması", "chapter1-3", 4, "gizli", ["archer", "cannon", "mage"]))
	var sule := _bot("Şule")
	_say(sule, NetProtocol.join(cagri.room_id, "gizli", ["priest"]))
	_say(_bot("Cem"), NetProtocol.join(ayla.room_id, "", ["archer"]))
	_say(_bot("Deniz"), NetProtocol.join(ayla.room_id, "", ["mage"]))
	net.list_rooms()
	await _frames(10)
	lobby.select_room(ayla.room_id)
	await _boards()
	await _shot("lobby_list")
	# auto-leave: in Mert's room (Hold the Gate) when he switches it to Night Watch (done today)
	lobby.select_room(mert.room_id)
	lobby.join_selected()
	await _frames(20)
	print("in room: ", net.in_room)
	_say(mert, NetProtocol.set_level("chapter2-1"))
	await _frames(40)
	print("after switch in room: ", net.in_room)
	await _shot("lobby_auto_left")
	for c in lobby._popups.get_children():
		if c is TdPopup and c.is_open: c.close()
	await _frames(10)
	# your own room (Patrol) with a tired tower in the first three
	save.towers.hand.erase(by_type["wisp"][0].id)
	save.missions.tired.clear()
	save.missions.tire(hand[1], MissionBoard.day_of())
	net.create_room("Akşam savunması", "chapter1-3", 4, "gizli", CoopLevels.my_hand_types(CoopLevels.hand_cap("chapter1-3")))
	await _frames(10)
	var b1 := _bot("Şule")
	_say(b1, NetProtocol.join(net.room.id, "gizli", ["mage", "archer", "wisp"]))
	_say(b1, NetProtocol.ready(true))
	var b2 := _bot("Mert")
	_say(b2, NetProtocol.join(net.room.id, "gizli", ["guardian", "ballista"]))
	await _boards()
	await _shot("room_tired")
	net.leave_room()
	await _frames(10)
	lobby.close()
	await _frames(10)
	guild.queue_free()
	await _frames(4)
	# end screens: Drum Line (2 plays a day: "1 play left today"), Patrol (its only play: "Done today")
	if current_scene != null: current_scene.queue_free() # the boot's menu would draw over the level
	# more towers in the hand: Drum Line takes its cap, the rest stay rested (Retry shows)
	for extra in [by_type["wisp"][1], by_type["ballista"][0], by_type["alchemist"][0]]: save.towers.add_to_hand(extra.id)
	save.missions.rest_all()
	await _end_screen("drum-line", "end_mission")
	save.missions.rest_all()
	await _end_screen("patrol", "end_mission_last")
	print("GUILD SHOT DONE")
	quit()

## Wins the first `count` levels of main chapter n (results only, no rewards).
func _win_main(n: int, count: int) -> void:
	var k := 0
	for ch in app.catalog.chapters:
		if ch == null or ch.kind != ChapterKind.Main: continue
		k += 1
		if k != n: continue
		var i := 0
		for e in ch.levels:
			if i >= count: break
			var r := LevelResult.new()
			r.level_id = e.level.get_id()
			r.won = true
			save.progress.record(r)
			i += 1

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
	print(label, ": drops ", level.drops, " can_retry ", level.can_retry, " leave ", level.leave_label)
	await _shot(label)
	level.queue_free()
	await _frames(6)

func _bot(n: String) -> FakeRelay.Link:
	var l := relay.connect_client()
	l.send_text(NetProtocol.encode(NetProtocol.hello(CoopLevels.content_version(), n)))
	return l

func _say(l: FakeRelay.Link, msg: Dictionary) -> void:
	l.send_text(NetProtocol.encode(msg))

func _settle(level) -> void:
	for i in 900:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _until(cond: Callable, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame

func _frames(n: int) -> void:
	for i in n: await process_frame

## Waits until every queued board picture is rendered (then a few frames for the layout).
func _boards() -> void:
	await _frames(3)
	await _until(func(): return CoopBoardPic._queue.is_empty() and not CoopBoardPic._busy, 120.0)
	await _frames(4)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("t=", Time.get_ticks_msec() / 1000.0)
	_n += 1
	var p := "%s/guild_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
