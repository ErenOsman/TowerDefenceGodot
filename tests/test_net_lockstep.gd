extends TestCase
## Two clients in lockstep through the FakeRelay: each builds its CoopMode from the same match_start, plays only
## its own turns by sending commands, applies everything in relay order, and both end every round with the same
## checksum (the relay sees no desync). Also: a refused relay command is a desync; a leaver is applied at the same
## point of the stream on both sides.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib

var relay: FakeRelay
var clients: Array = []
var modes: Array = []

func teardown() -> void:
	for m in modes: m.detach()
	for c in clients: c.free()
	modes.clear()
	clients.clear()

func _setup_match(level_id: String, names: Array, hands: Array) -> void:
	relay = FakeRelay.new()
	# chapter1-1 stands for a shared-pool level (no starter mission shares a pool since the co-op list became the
	# missions); the others follow the co-op list
	relay.shared_pool_of = func(l): return l == "chapter1-1" or CoopLevels.shared_pool(l)
	for n in names:
		var c := RelayClient.new()
		c.auto_poll = false
		c.player_name_override = n
		c.version = "0123456789abcdef"
		c.connect_fake(relay)
		c.poll()
		clients.append(c)
	var infos := {}
	for c in clients: c.match_started.connect(func(info): infos[c.player_id] = info)
	clients[0].create_room("Lockstep", level_id, names.size(), "", hands[0])
	_pump()
	for i in range(1, clients.size()):
		clients[i].join_room(clients[0].room.id, "", hands[i])
		_pump()
	for c in clients: c.set_ready(true)
	_pump()
	clients[0].start_match()
	_pump()
	for c in clients:
		var m := CoopMode.create(infos[c.player_id], c, lib(), AssetConverter.new(), c.player_id)
		assert_eq(m.setup_error, "")
		m.start()
		modes.append(m)

func _pump() -> void:
	for i in 2:
		for c in clients: c.poll()

## The acting client's simple policy: place an unplaced tower on the first free tile, else quick-cast one ability,
## else (every other round, once) pass, else end the turn. One command, then everyone polls.
func _step(passed: Dictionary) -> bool:
	var actor := ""
	for m in modes:
		if m.my_turn: actor = m.me
	if actor == "": return false
	var m: CoopMode = null
	for x in modes:
		if x.me == actor: m = x
	var coop := m.coop
	var s := coop.session
	for t in m.my_hand():
		if s.placed.has(t.id): continue
		for x in s.state.grid.width:
			for y in s.state.grid.height:
				if coop.can_place(actor, t.id, Vector2i(x, y)):
					assert_true(m.place(t.id, Vector2i(x, y)), m.last_reason)
					_pump()
					return true
	for unit in coop.units_of(actor):
		for a in unit.abilities:
			if a.targeting.is_movement or not coop.can_cast(actor, unit, a): continue
			var aim: Aim = Instinct.quick_cast(s.state, unit, a)
			if aim == null: continue
			assert_true(m.cast(unit, a, aim), m.last_reason)
			_pump()
			return true
	if coop.round % 2 == 0 and not passed.has(coop.round) and coop.turn_order.size() > 1:
		passed[coop.round] = true
		assert_true(m.pass_turn())
		_pump()
		return true
	assert_true(m.end_turn())
	_pump()
	return true

func _play(rounds: int) -> void:
	var passed := {}
	var guard := 0
	while guard < 600 and not modes[0].coop.is_over and modes[0].coop.round <= rounds:
		guard += 1
		if not _step(passed): break

func test_two_clients_same_checksums() -> void:
	var desyncs := []
	_setup_match("chapter1-3", ["Çağrı", "Şule"], [["archer", "cannon", "mage"], ["archer", "mage"]])
	for c in clients: c.desync.connect(func(r, h): desyncs.append(r))
	assert_false(modes[0].coop.shared_pool, "chapter1-3: separate pools")
	_play(4)
	assert_true(modes[0].checksums.size() >= 3, "rounds were checked: %s" % [modes[0].checksums])
	assert_eq(modes[0].checksums, modes[1].checksums)
	assert_eq(modes[0].coop.checksum(), modes[1].coop.checksum())
	assert_eq(modes[0].coop.state_digest(), modes[1].coop.state_digest())
	assert_eq(desyncs.size(), 0, "the relay compared every round")
	assert_false(modes[0].desync or modes[1].desync)
	var owners := {}
	for t in modes[0].coop.session.placed: owners[modes[0].coop.owner_of(t)] = true
	assert_eq(owners.size(), 2, "both players placed towers")

func test_three_players_shared_pool_with_leaver() -> void:
	var desyncs := []
	_setup_match("chapter1-1", ["A", "B", "C"], [["archer"], ["mage"], ["cannon"]])
	for c in clients: c.desync.connect(func(r, h): desyncs.append(r))
	_play(1)
	var gone: String = clients[1].player_id
	clients[1].disconnect_relay()
	modes[1].detach()
	_pump()
	assert_true(modes[0].coop.left.has(gone))
	assert_true(modes[2].coop.left.has(gone))
	_play(3)
	assert_eq(modes[0].coop.checksum(), modes[2].coop.checksum())
	assert_eq(desyncs.size(), 0)
	assert_false(modes[0].coop.players.has(gone))

func test_refused_relay_command_is_a_desync() -> void:
	_setup_match("chapter1-1", ["A", "B"], [["archer"], ["mage"]])
	var why := []
	modes[0].desynced.connect(func(_r, reason): why.append(reason))
	# B sends out of turn (bypassing its own check): A's session refuses it → desync
	clients[1].send_cmd(1, {"k": "end_turn"})
	_pump()
	assert_true(modes[0].desync)
	assert_eq(why.size(), 1)

func test_local_refusal_sends_nothing() -> void:
	_setup_match("chapter1-1", ["A", "B"], [["archer"], ["mage"]])
	var before := relay.received.size()
	assert_false(modes[1].end_turn(), "not B's turn")
	assert_ne(modes[1].last_reason, "")
	assert_eq(relay.received.size(), before)
	assert_true(modes[0].my_turn)
	assert_true(modes[0].pass_turn())
	assert_false(modes[0].my_turn, "waits for the echo")
	_pump()
	assert_eq(modes[0].current_player, clients[1].player_id)
	assert_eq(modes[1].turn_text(), "Your turn")
	assert_eq(modes[0].turn_text(), "B's turn")
