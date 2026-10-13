extends TestCase
## Two RelayClients driven through the in-process FakeRelay (no sockets): hello, lobby, create/join with the error
## cases, ready/start rules, host controls, chat, cmd broadcast in relay order, checksum/desync, leaving.

var relay: FakeRelay
var a: RelayClient
var b: RelayClient

func setup() -> void:
	relay = FakeRelay.new()
	a = _client("Çağrı")
	b = _client("Şule")

func teardown() -> void:
	a.free()
	b.free()

func _client(n: String) -> RelayClient:
	var c := RelayClient.new()
	c.auto_poll = false
	c.player_name_override = n
	c.version = "0123456789abcdef"
	c.connect_fake(relay)
	c.poll()
	return c

func _pump() -> void:
	for i in 3:
		a.poll()
		b.poll()

func _room_with_both(password := "") -> void:
	a.create_room("Akşam savunması", "chapter1-1", 2, password, ["archer"])
	_pump()
	b.join_room(a.room.id, password, ["mage"])
	_pump()

func test_hello_and_lobby() -> void:
	assert_eq(a.state, RelayClient.State.ONLINE)
	assert_true(a.player_id != "" and a.player_id != b.player_id)
	assert_eq(relay.received[0][1].t, "hello", "hello is the first frame")
	assert_eq(relay.received[0][1].name, "Çağrı")
	a.create_room("Akşam savunması", "chapter1-1", 4, "", ["archer"])
	_pump()
	assert_eq(b.rooms.size(), 1, "the lobby is pushed to clients not in a room")
	assert_eq(b.rooms[0].name, "Akşam savunması")
	assert_eq(int(b.rooms[0].players), 1)
	assert_eq(int(b.rooms[0].count), 4)
	assert_false(b.rooms[0].locked)

func test_other_versions_are_hidden() -> void:
	var c := RelayClient.new()
	c.auto_poll = false
	c.player_name_override = "Mert"
	c.version = "fedcba9876543210"
	c.connect_fake(relay)
	a.create_room("Room", "chapter1-1", 2, "", [])
	_pump()
	c.poll()
	assert_eq(c.rooms.size(), 0)
	c.join_room(a.room.id, "", [])
	c.poll()
	assert_eq(c.last_error, "version")
	c.free()

func test_create_join_and_errors() -> void:
	var errors := []
	b.error_received.connect(func(code, _t): errors.append(code))
	a.create_room("Kötü İsim", "chapter1-1", 2, "", [])
	_pump()
	assert_eq(a.last_error, "bad_name")
	assert_false(a.in_room)
	a.create_room("Akşam", "chapter1-1", 2, "pw", ["archer"])
	_pump()
	assert_true(a.is_host)
	assert_true(a.room.locked)
	b.join_room(a.room.id, "nope", [])
	_pump()
	b.join_room("ZZZZZZ", "", [])
	_pump()
	b.join_room(a.room.id, "pw", ["mage"])
	_pump()
	assert_seq(errors, ["wrong_password", "not_found"])
	assert_true(b.in_room)
	assert_eq(b.room.players.size(), 2)
	var c := _client("Mert")
	c.join_room(a.room.id, "pw", [])
	c.poll()
	assert_eq(c.last_error, "full")
	b.create_room("Second", "chapter1-1", 2, "", [])
	_pump()
	assert_eq(b.last_error, "bad_request", "create while in a room")
	c.free()

func test_ready_and_start_rules() -> void:
	_room_with_both()
	var started := []
	a.match_started.connect(func(info): started.append(info))
	b.match_started.connect(func(info): started.append(info))
	b.start_match()
	_pump()
	assert_eq(b.last_error, "not_host")
	a.set_ready(true)
	_pump()
	a.start_match()
	_pump()
	assert_eq(started.size(), 0, "Şule is not ready")
	b.set_ready(true)
	_pump()
	assert_true(NetProtocol.all_ready(a.room))
	a.set_level("chapter1-2")
	_pump()
	assert_false(NetProtocol.all_ready(a.room), "changing the level resets Ready")
	assert_eq(b.room.level, "chapter1-2")
	a.set_ready(true)
	b.set_ready(true)
	_pump()
	a.start_match()
	_pump()
	assert_eq(started.size(), 2)
	assert_eq(started[0].seed, started[1].seed)
	assert_eq(started[0].level, "chapter1-2")
	assert_eq(started[0].players.size(), 2)
	assert_eq(started[0].players[0].id, a.player_id, "turn order = slot order")
	assert_seq(started[0].players[1].hand, ["mage"])
	assert_true(b.room.started)

func test_host_controls_and_notes() -> void:
	_room_with_both()
	var notes := []
	a.room_notes.connect(func(n): notes.append_array(n))
	var kicked := [false]
	b.kicked.connect(func(): kicked[0] = true)
	a.set_count(4)
	_pump()
	assert_eq(int(b.room.count), 4)
	a.set_count(1)
	_pump()
	assert_true(kicked[0], "lowering below the players present removes the last joined")
	assert_false(b.in_room)
	assert_eq(a.room.players.size(), 1)
	var kinds := []
	for n in notes: kinds.append(n.kind)
	assert_contains(kinds, "left")
	b.join_room(a.room.id, "", [])
	_pump()
	assert_eq(b.last_error, "full")
	a.set_count(2)
	_pump()
	b.join_room(a.room.id, "", [])
	_pump()
	a.kick(b.player_id)
	_pump()
	assert_false(b.in_room)

func test_host_moves_on_leave_and_slots_renumber() -> void:
	_room_with_both()
	var c := _client("Mert")
	a.set_count(3)
	_pump()
	c.join_room(a.room.id, "", [])
	c.poll()
	_pump()
	a.leave_room()
	_pump()
	c.poll()
	assert_eq(b.room.host, b.player_id, "the next joined becomes host")
	assert_eq(int(NetProtocol.find_player(c.room, c.player_id).slot), 1)
	assert_true(b.is_host)
	c.free()

func test_chat() -> void:
	_room_with_both()
	var got := []
	b.chat_received.connect(func(from, n, t): got.append([from, n, t]))
	a.chat("hi! which road?")
	_pump()
	assert_eq(got.size(), 1)
	assert_seq(got[0], [a.player_id, "Çağrı", "hi! which road?"])

func test_cmd_relay_order_and_seq() -> void:
	_room_with_both()
	a.set_ready(true); b.set_ready(true)
	_pump()
	a.start_match()
	_pump()
	var seen_a := []
	var seen_b := []
	a.cmd_received.connect(func(p, r, s, c): seen_a.append([p, r, s, c.k]))
	b.cmd_received.connect(func(p, r, s, c): seen_b.append([p, r, s, c.k]))
	a.send_cmd(1, {"k": "pass"})
	b.send_cmd(1, {"k": "end_turn"})
	a.send_cmd(1, {"k": "end_turn"})
	_pump()
	assert_eq(seen_a.size(), 3, "the sender gets its own commands back")
	assert_eq(seen_a, seen_b, "every client sees the same order")
	assert_seq(seen_a[0], [a.player_id, 1, 1, "pass"])
	assert_seq(seen_a[2], [a.player_id, 1, 2, "end_turn"], "seq counts per player")

func test_checksum_and_desync() -> void:
	_room_with_both()
	a.set_ready(true); b.set_ready(true)
	_pump()
	a.start_match()
	_pump()
	var desyncs := []
	a.desync.connect(func(r, h): desyncs.append([r, h]))
	a.send_checksum(1, "aaaa")
	b.send_checksum(1, "aaaa")
	_pump()
	assert_eq(desyncs.size(), 0)
	a.send_checksum(2, "aaaa")
	b.send_checksum(2, "bbbb")
	_pump()
	assert_eq(desyncs.size(), 1)
	assert_eq(desyncs[0][0], 2)
	assert_eq(desyncs[0][1][b.player_id], "bbbb")

func test_player_left_during_match_and_ping() -> void:
	_room_with_both()
	a.set_ready(true); b.set_ready(true)
	_pump()
	a.start_match()
	_pump()
	var left := []
	a.player_left.connect(func(p): left.append(p))
	b.disconnect_relay()
	a.poll()
	assert_seq(left, [b.player_id])
	assert_eq(a.room.players.size(), 1, "the room stays for the others")
	relay.ping_all()
	a.poll()
	assert_eq(relay.received[relay.received.size() - 1][1].t, "pong", "pings are answered at once")

func test_offline_practice() -> void:
	var c := RelayClient.new()
	c.auto_poll = false
	c.player_name_override = "Eren"
	c.start_practice()
	assert_true(c.practice)
	assert_eq(c.state, RelayClient.State.ONLINE)
	c.create_room("Practice", "chapter1-1", 1, "", ["archer"])
	c.poll()
	c.set_ready(true)
	c.poll()
	var got := []
	c.match_started.connect(func(info): got.append(info))
	c.start_match()
	c.poll()
	assert_eq(got.size(), 1)
	assert_true(got[0].shared_pool, "chapter1-1 is a shared pool in data/coop.json")
	c.free()
