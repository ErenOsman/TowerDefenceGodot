extends TestCase
## CoopMode against a stub relay (no network, no FakeRelay): the launch hand-off (CoopLaunch) builds the CoopSession
## from match_ready's info; your commands are checked, sent once and applied only on the relay's echo (never twice);
## remote commands apply; a finished round sends its checksum; desync / player_left / a lost connection are handled;
## two CoopModes fed the same relay stream end with the same checksums.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib

## The relay client's surface CoopMode uses: its signals, send_cmd / send_checksum / chat / leave_room.
class StubNet extends RefCounted:
	signal cmd_received(player: String, round: int, seq: int, cmd: Dictionary)
	signal player_left(player: String)
	signal desync(round: int, hashes: Dictionary)
	signal chat_received(from: String, name: String, text: String)
	signal kicked
	signal match_ready(info: Dictionary)
	var player_id := ""
	var cmds: Array = []        # [[round, cmd], …] sent
	var checksums: Array = []   # [[round, hash], …] sent
	var chats: Array = []
	var left := false
	var reopen_lobby := false
	var _seq := 0
	func send_cmd(round: int, cmd: Dictionary) -> int:
		_seq += 1
		cmds.append([round, cmd])
		return _seq
	func send_checksum(round: int, hash: String) -> void: checksums.append([round, hash])
	func chat(text: String) -> void: chats.append(text)
	func leave_room() -> void: left = true
	## The relay's echo of a command (JSON numbers arrive as floats).
	func echo(player: String, round: int, cmd: Dictionary) -> void:
		cmd_received.emit(player, round, 0, JSON.parse_string(JSON.stringify(cmd)))

const A := "aaaa1111"
const B := "bbbb2222"

func _info(level_id := "chapter1-1", local := A) -> Dictionary:
	return {"seed": 4242, "level": level_id, "shared_pool": true, "local_player": local,
		"players": [{"id": B, "name": "Şule", "hand": ["mage"], "slot": 1},
			{"id": A, "name": "Eren", "hand": ["archer", "cannon"], "slot": 0}]}

func _mode(net: StubNet, info: Dictionary) -> CoopMode:
	net.player_id = str(info.local_player)
	var m := CoopMode.create(info, net, lib(), AssetConverter.new(), net.player_id)
	assert_eq(m.setup_error, "")
	m.start()
	return m

func teardown() -> void:
	CoopLaunch.clear()

## A free tile where the player's tower can go now, or null.
func _free_tile(m: CoopMode, tower_id: String):
	var g := m.coop.state.grid
	for x in g.width:
		for y in g.height:
			if m.coop.can_place(m.me, tower_id, Vector2i(x, y)): return Vector2i(x, y)
	return null

func test_launch_hands_the_match_to_the_level_once() -> void:
	var net := StubNet.new()
	CoopLaunch.request(_info(), net)
	assert_true(CoopLaunch.has_request())
	var info := CoopLaunch.take()
	assert_false(CoopLaunch.has_request(), "consumed once")
	assert_eq(CoopLaunch.take(), {})
	var m := _mode(net, info)
	assert_eq(m.level_id, "chapter1-1")
	assert_eq(Array(m.coop.slots), [A, B], "slot order, not list order")
	assert_eq(m.coop.current_player, A)
	assert_true(m.my_turn)
	assert_eq(m.turn_text(), "Your turn")
	assert_eq(m.my_hand().size(), 2, "only your hand")
	assert_eq(m.my_hand()[0].id, A + ":archer#1")
	assert_eq(m.coop.hand_of(B)[0].id, B + ":mage#1")
	assert_true(m.coop.shared_pool, "chapter1-1 shares one pool (data/coop.json)")
	m.detach()

func test_unknown_level_is_a_setup_error() -> void:
	var info := _info()
	info.level = "no-such-level"
	var m := CoopMode.create(info, StubNet.new(), lib(), AssetConverter.new(), A)
	assert_ne(m.setup_error, "")

func test_local_command_is_sent_once_and_applied_on_the_echo() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info())
	var tower: String = m.my_hand()[0].id
	var tile = _free_tile(m, tower)
	assert_not_null(tile)
	var log_before := m.coop.log.events.size() if "events" in m.coop.log else -1
	assert_true(m.place(tower, tile), m.last_reason)
	assert_eq(net.cmds.size(), 1, "sent once")
	assert_eq(net.cmds[0][1], CoopSession.place_command(tower, tile))
	assert_null(m.session.placed_tower(tower), "nothing changes before the echo")
	assert_false(m.my_turn, "input waits for the echo")
	assert_false(m.place(tower, tile), "a second command waits too")
	assert_eq(net.cmds.size(), 1)
	net.echo(A, 1, net.cmds[0][1])
	assert_not_null(m.session.placed_tower(tower), "applied on the echo")
	assert_true(m.my_turn)
	assert_eq(m.awaiting, 0)
	if log_before >= 0: assert_true(m.coop.log.events.size() > log_before)
	# the same command echoed again would be a second placement: refused → desync (never silently re-applied)
	assert_eq(net.cmds.size(), 1, "the echo sends nothing")
	m.detach()

func test_local_refusal_sends_nothing() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info("chapter1-1", B)) # B is second: not their turn
	assert_false(m.my_turn)
	assert_false(m.end_turn())
	assert_false(m.pass_turn())
	assert_eq(net.cmds.size(), 0)
	assert_ne(m.last_reason, "")
	assert_eq(m.turn_text(), "Eren's turn")
	m.detach()

func test_remote_commands_apply_and_turns_move() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info("chapter1-1", B))
	var turns := []
	m.turn_changed.connect(func(p): turns.append(p))
	net.echo(A, 1, {"k": "pass"})
	assert_eq(m.current_player, B, "Eren passed: Şule acts")
	assert_true(m.my_turn)
	assert_eq(Array(m.coop.turn_order), [B, A])
	assert_true(m.end_turn())
	net.echo(B, 1, net.cmds[0][1])
	assert_eq(m.current_player, A)
	assert_eq(turns, [B, A])
	assert_eq(net.checksums.size(), 0, "the round is not over yet")
	m.detach()

func test_checksum_is_sent_after_each_round() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info())
	var checked := []
	m.round_checked.connect(func(r, h): checked.append([r, h]))
	assert_true(m.end_turn())
	net.echo(A, 1, net.cmds[0][1])
	net.echo(B, 1, {"k": "end_turn"})
	assert_eq(m.coop.round, 2)
	assert_eq(net.checksums.size(), 1)
	assert_eq(net.checksums[0][0], 1, "for round 1")
	assert_eq(net.checksums[0][1], m.coop.checksum())
	assert_eq(checked, net.checksums)
	assert_eq(m.checksums, [1])
	m.detach()

func test_a_refused_relay_command_is_a_desync() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info())
	var why := []
	m.desynced.connect(func(_r, reason): why.append(reason))
	net.echo(B, 1, {"k": "end_turn"}) # out of turn here
	assert_true(m.desync)
	assert_eq(why.size(), 1)
	assert_false(m.my_turn, "no input after a desync")
	assert_false(m.end_turn())

func test_relay_desync_message() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info())
	net.desync.emit(3, {A: "x", B: "y"})
	assert_true(m.desync)
	assert_true(m.desync_reason.contains("round 3"))
	m.detach()

func test_player_left_in_stream_order_and_our_own_loss() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info())
	var gone := []
	var lines := []
	m.player_gone.connect(func(p, n): gone.append([p, n]))
	m.chat_line.connect(func(f, t, _c): lines.append([f, t]))
	assert_true(m.end_turn())
	net.echo(A, 1, net.cmds[0][1])
	assert_eq(m.current_player, B)
	net.player_left.emit(B) # Şule leaves during her turn: the round ends (nobody else waits)
	assert_eq(gone, [[B, "Şule"]])
	assert_true(m.coop.left.has(B))
	assert_eq(m.coop.round, 2)
	assert_eq(net.checksums.size(), 1, "the round her leaving ended is checked")
	assert_eq(m.current_player, A)
	assert_eq(lines, [["", "Şule left the match."]])
	net.player_left.emit(B)
	assert_eq(gone.size(), 1, "once")
	var lost := []
	m.match_lost.connect(func(r): lost.append(r))
	net.player_left.emit(A) # our own connection dropped
	assert_true(m.lost)
	assert_eq(lost.size(), 1)
	assert_false(m.my_turn)
	m.detach()

func test_chat_and_leaving() -> void:
	var net := StubNet.new()
	var m := _mode(net, _info())
	var lines := []
	m.chat_line.connect(func(f, t, c): lines.append([f, t, c]))
	net.chat_received.emit(B, "Şule", "merhaba")
	assert_eq(lines[0][0], "Şule")
	assert_eq(lines[0][2], m.color_of(B))
	m.say("  selam ")
	assert_eq(net.chats, ["selam"])
	m.leave()
	assert_true(net.left)
	assert_null(m.net, "detached")
	net.chat_received.emit(B, "Şule", "hâlâ burada mısın")
	assert_eq(lines.size(), 1, "no longer listening")

## Plays a few rounds on two clients through one shared relay stream (each sees every command, its own echoed).
func test_two_modes_fed_the_same_stream_agree() -> void:
	var na := StubNet.new()
	var nb := StubNet.new()
	var info := _info("chapter1-3") # separate pools
	var ma := _mode(na, info)
	var ib := info.duplicate(true)
	ib.local_player = B
	var mb := _mode(nb, ib)
	assert_false(ma.coop.shared_pool)
	var nets := {A: na, B: nb}
	var modes := {A: ma, B: mb}
	var guard := 0
	while ma.coop.round <= 4 and not ma.coop.is_over and guard < 200:
		guard += 1
		var actor: String = ma.current_player
		var m: CoopMode = modes[actor]
		var n: StubNet = nets[actor]
		var sent := n.cmds.size()
		var placed := false
		for t in m.my_hand():
			if m.session.placed.has(t.id): continue
			var tile = _free_tile(m, t.id)
			if tile != null and m.place(t.id, tile):
				placed = true
				break
		if not placed:
			for unit in m.coop.units_of(actor):
				if placed: break
				for a in unit.abilities:
					if a.targeting.is_movement or not m.coop.can_cast(actor, unit, a): continue
					var aim: Aim = Instinct.quick_cast(m.session.state, unit, a)
					if aim != null and m.cast(unit, a, aim):
						placed = true
						break
		if not placed: assert_true(m.end_turn(), m.last_reason)
		assert_eq(n.cmds.size(), sent + 1, "one command sent")
		var cmd: Dictionary = n.cmds.back()[1]
		var r: int = n.cmds.back()[0]
		na.echo(actor, r, cmd) # the relay broadcasts to everyone, the sender too
		nb.echo(actor, r, cmd)
	assert_true(na.checksums.size() >= 3, "rounds were checked")
	assert_eq(na.checksums, nb.checksums, "same hash every round")
	assert_eq(ma.coop.state_digest(), mb.coop.state_digest())
	assert_false(ma.desync or mb.desync)
	assert_eq(ma.coop.energy_of(A), mb.coop.energy_of(A))
	assert_eq(ma.coop.energy_of(B), mb.coop.energy_of(B))
	ma.detach()
	mb.detach()
