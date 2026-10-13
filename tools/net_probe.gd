extends SceneTree
## Two real RelayClients (WebSocketPeer) against a live relay: hello, create, join (wrong password first), ready,
## start, two lockstep matches of commands with checksums, chat, leave. Prints PROBE OK / PROBE FAIL.
##   godot --headless --path . -s tools/net_probe.gd -- [ws://127.0.0.1/ws/relay]

var a: RelayClient
var b: RelayClient
var log_lines: Array = []

func _initialize() -> void:
	var url := "ws://127.0.0.1/ws/relay"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: url = args[0]
	_run(url)

func _make(n: String, url: String) -> RelayClient:
	var c := RelayClient.new()
	c.auto_poll = false
	c.auto_reconnect = false
	c.player_name_override = n
	root.add_child(c)
	c.connect_relay(url)
	return c

func _wait(cond: Callable, seconds := 5.0) -> bool:
	var t := 0.0
	while t < seconds:
		a.poll(0.02)
		b.poll(0.02)
		if cond.call(): return true
		await process_frame
		OS.delay_msec(20)
		t += 0.02
	return false

func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: log_lines.append(what)

func _run(url: String) -> void:
	await process_frame
	a = _make("Çağrı", url)
	b = _make("Şule", url)
	_check(await _wait(func(): return a.is_online and b.is_online), "both welcomed (%s, %s)" % [a.player_id, b.player_id])
	var errors := []
	b.error_received.connect(func(code, _t): errors.append(code))
	a.create_room("Probe odası", "chapter1-1", 2, "gizli", ["archer", "mage"])
	_check(await _wait(func(): return a.in_room), "room created " + str(a.room.get("id", "")))
	_check(await _wait(func(): return b.rooms.any(func(r): return r.id == a.room.id)), "listed in b's lobby")
	b.join_room(a.room.id, "nope", ["cannon"])
	_check(await _wait(func(): return errors.has("wrong_password")), "wrong password refused")
	b.join_room(a.room.id, "gizli", ["cannon"])
	_check(await _wait(func(): return b.in_room and a.room.players.size() == 2), "joined")
	var chats := []
	a.chat_received.connect(func(_f, n, t): chats.append(n + ": " + t))
	b.chat("merhaba")
	_check(await _wait(func(): return chats.size() == 1), "chat " + str(chats))
	var infos := {}
	a.match_started.connect(func(i): infos["a"] = i)
	b.match_started.connect(func(i): infos["b"] = i)
	a.set_ready(true)
	b.set_ready(true)
	await _wait(func(): return NetProtocol.all_ready(a.room))
	a.start_match()
	_check(await _wait(func(): return infos.size() == 2), "match_start on both")
	if infos.size() == 2:
		var lib := ContentLibrary.load("res://data/content")
		var ma := CoopMode.create(infos["a"], a, lib, AssetConverter.new(), a.player_id)
		var mb := CoopMode.create(infos["b"], b, lib, AssetConverter.new(), b.player_id)
		ma.start()
		mb.start()
		var desyncs := []
		a.desync.connect(func(r, _h): desyncs.append(r))
		# three rounds: each player ends their turn when it is theirs (the first passes once)
		_check(ma.pass_turn(), "a passes")
		await _wait(func(): return ma.awaiting == 0)
		for r in 3:
			for i in 2:
				var m := ma if ma.my_turn else mb
				m.end_turn()
				await _wait(func(): return ma.awaiting == 0 and mb.awaiting == 0)
		await _wait(func(): return false, 0.5)
		_check(ma.coop.round == 4 and mb.coop.round == 4, "round 4 on both (%d, %d)" % [ma.coop.round, mb.coop.round])
		_check(ma.coop.checksum() == mb.coop.checksum(), "same checksum " + ma.coop.checksum())
		_check(desyncs.is_empty() and not ma.desync and not mb.desync, "no desync")
		var lefts := []
		a.player_left.connect(func(p): lefts.append(p))
		b.leave_room()
		_check(await _wait(func(): return lefts.size() == 1), "player_left after leave")
	a.disconnect_relay()
	b.disconnect_relay()
	print("PROBE OK" if log_lines.is_empty() else "PROBE FAIL " + str(log_lines))
	quit(0 if log_lines.is_empty() else 1)
