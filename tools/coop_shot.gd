extends SceneTree
## Dev script: screenshots the co-op lobby screens at 1920×1080 under Xvfb, against an in-process FakeRelay with bot
## players (no network). Opens them from the Camp's Multiplayer station.
##   ~/godot/run.sh projects/td -s tools/coop_shot.gd [-- <out dir>]
## PNGs: <out dir>/coop_<n>_<step>.png — list (3 rooms), list_empty, list_offline, create, create_refused, join_wrong,
## room_host (4 slots, 3 players… 2 ready), room_guest, room_changed (level banner), settings_lower.
## A second argument limits the steps saved (comma list, e.g. "list,room_host"); later steps are skipped.

var out_dir := "user://coop"
var _n := 0
var net: RelayClient
var relay: FakeRelay
var bots := {}   # name → FakeRelay.Link
var only: PackedStringArray = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: only = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _bot(n: String) -> FakeRelay.Link:
	var l := relay.connect_client()
	l.send_text(NetProtocol.encode(NetProtocol.hello(CoopLevels.content_version(), n)))
	bots[n] = l
	return l

func _say(l: FakeRelay.Link, msg: Dictionary) -> void:
	l.send_text(NetProtocol.encode(msg))

func _run() -> void:
	var save = root.get_node("SaveData")
	var flow = root.get_node("SceneFlow")
	var app = root.get_node("GameApp")
	net = root.get_node("Net")
	save.path = "user://coop_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Çağrı", false)
	app.ensure_loaded()
	app.complete_chapter1()
	save.profile.camp_seen = true
	save.save()
	relay = FakeRelay.new()
	relay.shared_pool_of = func(l): return CoopLevels.shared_pool(l)
	net.player_name_override = "Çağrı"
	net.connect_fake(relay)
	net.practice = false # shown as online (the fake relay stands in for the server)
	net.auto_poll = true
	relay.player_pings = {}
	net._rtt_in = 1e9 # no round-trip probe against the in-process relay (it would measure frame time)
	await _until(func(): return not flow.is_loading, 30.0)
	await _frames(4)
	flow.go(flow.Camp)
	await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 30.0)
	await _frames(8)
	var camp = current_scene
	# --- empty lobby
	var lobby: CoopLobby = camp.open_multiplayer()
	await _frames(12)
	await _shot("list_empty")
	# --- three rooms from bots
	var ids := CoopLevels.list().level_ids()
	var mert := _bot("Mert")
	relay.player_pings[mert.player_id] = 180
	_say(mert, NetProtocol.create("Quick slimes", ids[1], 2, "", ["cannon"]))
	var ayla := _bot("Ayla")
	relay.player_pings[ayla.player_id] = 42
	_say(ayla, NetProtocol.create("Herkes gelsin!", ids[0], 6, "", ["mage", "archer"]))
	var sule := _bot("Şule")
	_say(sule, NetProtocol.create("Akşam savunması", ids[2], 4, "gizli", ["archer", "cannon", "mage"]))
	var eren := _bot("Eren")
	_say(eren, NetProtocol.join(sule.room_id, "gizli", ["mage"]))
	var cem := _bot("Cem")
	_say(cem, NetProtocol.join(ayla.room_id, "", ["archer"]))
	net.list_rooms()
	await _frames(4)
	lobby.select_room(sule.room_id)
	await _frames(8)
	await _until(func(): return _boards_ready(lobby), 300.0)
	await _frames(6)
	await _shot("list")
	# --- join with a wrong password
	lobby.join_selected()
	await _frames(4)
	var join: CoopJoinPopup = _top(CoopJoinPopup)
	join._password.text = "yanlış"
	join._password.caret_column = join._password.text.length()
	join.join()
	await _frames(10)
	await _shot("join_wrong")
	join.close()
	await _frames(6)
	# --- create, then a refused name
	var create := lobby.open_create()
	create.room_name = "Akşam savunması"
	create._name.text = create.room_name
	create.count = 4
	for b in create._picker_buttons(): b.set_selected(b.text == "4")
	create.level_id = ids[2]
	create._refresh()
	await _frames(10)
	await _shot("create")
	create._name.text = "Kötü İsim"
	create._name.text_changed.emit(create._name.text)
	create.create()
	await _frames(6)
	await _shot("create_refused")
	# --- our own room (host view): 4 slots, Mert and Ayla join, 2 ready
	create._name.text = "Akşam savunması"
	create._name.text_changed.emit(create._name.text)
	create._password.text = "gizli"
	create.create()
	await _frames(8)
	var room: CoopRoom = lobby.room_popup
	_say(mert, NetProtocol.leave())
	_say(mert, NetProtocol.join(net.room.id, "gizli", ["archer", "cannon", "mage"]))
	_say(ayla, NetProtocol.leave())
	_say(ayla, NetProtocol.join(net.room.id, "gizli", ["cannon", "archer"]))
	await _frames(4)
	net.set_ready(true)
	_say(mert, NetProtocol.ready(true))
	_say(mert, NetProtocol.chat("hi! which road do you want?"))
	net.chat("I take the left road.")
	_say(mert, NetProtocol.chat("ok, Mage on the right then"))
	await _frames(12)
	net.rtt_ms = 42 # the fake relay answers in-process: a typical round trip for the picture
	room.refresh()
	await _until(func(): return _boards_ready(room), 300.0)
	await _frames(6)
	await _shot("room_host")
	if not only.is_empty() and not only.has("room_changed"): quit(0); return
	# --- the level changes (banner + everyone not ready)
	net.set_level(ids[1])
	await _frames(10)
	await _shot("room_changed")
	# --- settings, lowering below the players present
	var settings := room.open_settings()
	await _frames(4)
	settings.count = 1
	for b in settings._picker: b.set_selected(b.text == "1")
	settings._refresh()
	await _frames(8)
	await _shot("settings_lower")
	settings.close()
	await _frames(4)
	# --- guest view: leave, join Şule's room
	room.leave_room()
	await _frames(6)
	net.join_room(sule.room_id, "gizli", CoopLevels.my_hand_types(3))
	await _frames(4)
	_say(sule, NetProtocol.ready(true))
	_say(sule, NetProtocol.chat("Guardian goes near the base"))
	await _frames(12)
	await _shot("room_guest")
	# --- offline
	if lobby.room_popup != null: lobby.room_popup.leave_room()
	await _frames(4)
	net.disconnect_relay()
	net.auto_reconnect = false
	lobby.refresh()
	await _frames(10)
	await _shot("list_offline")
	quit(0)

func _top(type) -> TdPopup:
	var top = TdPopup.open_popups.back() if not TdPopup.open_popups.is_empty() else null
	return top if is_instance_of(top, type) else null

func _frames(n: int) -> void:
	for i in n: await process_frame

func _until(cond: Callable, timeout: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > timeout * 1000.0:
			print("TIMEOUT waiting; scene=", current_scene)
			return
		await process_frame

func _shot(label: String) -> void:
	if not only.is_empty() and not only.has(label): return
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/coop_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p), " t=", Time.get_ticks_msec())

## Every board picture under a node has its rendered board up (not the minimap).
func _boards_ready(n: Node) -> bool:
	for p in n.find_children("*", "CoopBoardPic", true, false):
		if p.is_visible_in_tree() and not p.is_board_shown(): return false
	return true
