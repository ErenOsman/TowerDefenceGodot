class_name CoopMode
extends RefCounted
## The co-op side of a level (Multiplayer — Design, co-op; docs/COOP-PROTOCOL.md): owned by LevelController when a
## match was launched from the lobby, absent in single player (which stays untouched). It builds the CoopSession from
## the relay's match_start (level, seed, players' hands in slot order, energy rule from data/coop.json), and keeps
## both clients in lockstep: your commands are sent to the relay and applied only when the relay echoes them, so
## every client applies every command in relay order; remote commands are applied the same way; a refused relay
## command or a different checksum is a desync. After every round end it sends the checksum for that round. A
## player who leaves is removed through CoopSession.remove_player (turn skipped, towers neutral, pool closed).
## Headless and testable: `net` is anything with RelayClient's signals (cmd_received, player_left, desync,
## chat_received, kicked) and send_cmd / send_checksum / chat / leave_room. The level scene gets the match through
## CoopLaunch (Net.match_ready → CoopLaunch.start_match → LevelController._setup → CoopMode.create).

## Player colours by slot (name plates, the turn banner).
const COLORS := [Color("4a90e2"), Color("e8913a"), Color("59b35c"), Color("a46ad9"), Color("e05a5a"), Color("3fb8b0")]

signal command_applied(player: String, cmd: Dictionary, ok: bool)
## The acting player changed ("" = nobody acts: enemy phase, over).
signal turn_changed(player: String)
## A round ended here (its checksum was sent).
signal round_checked(round: int, hash: String)
signal desynced(round: int, reason: String)
signal player_gone(player: String, name: String)
## Chat during the match (system lines have from = "").
signal chat_line(from_name: String, text: String, color: Color)
## The connection to the match is gone (lost, kicked).
signal match_lost(reason: String)

var net = null
var coop: CoopSession = null
var me := ""
var info: Dictionary = {}
var level_id := ""
## player id → name / slot, from match_start (leavers stay).
var names := {}
var slots := {}
var desync := false
var desync_reason := ""
var lost := false
## Your commands sent and not echoed yet (input waits while > 0).
var awaiting := 0
## Rounds whose checksum was sent, in order (tests read it).
var checksums: Array = []
## Players who passed in this round (player id → true; cleared when a round ends). The HUD's turn order marks them.
var passed: Dictionary = {}
var setup_error := ""

var _last_turn := "-"

## Builds the session for a match_start (info) with the content library; setup_error says why it failed.
static func create(p_info: Dictionary, p_net, lib: ContentLibrary, converter: AssetConverter, my_id: String) -> CoopMode:
	var m := CoopMode.new()
	m.info = p_info
	m.net = p_net
	m.me = my_id
	m.level_id = str(p_info.get("level", ""))
	var asset: LevelAsset = lib.catalog.find_level(m.level_id) if lib.catalog != null else null
	if asset == null:
		m.setup_error = "This co-op level is not in your game: %s." % m.level_id
		return m
	var list := CoopLevels.list()
	var shared := list.shared_pool(m.level_id) if list.find(m.level_id) != null else bool(p_info.get("shared_pool", true))
	var players := []
	var type_by_id := func(t: String) -> TowerType:
		var ta: TowerAsset = lib.catalog.find_tower(t)
		return converter.tower_type(ta) if ta != null else null
	var ordered: Array = (p_info.get("players", []) as Array).duplicate()
	ordered.sort_custom(func(a, b): return NetProtocol.int_of(a, "slot") < NetProtocol.int_of(b, "slot"))
	for p in ordered:
		var pid := str(p.get("id", ""))
		m.names[pid] = str(p.get("name", "?"))
		m.slots[pid] = m.slots.size()
		players.append({"id": pid, "hand": CoopSession.build_hand(pid, p.get("hand", []), type_by_id)})
	m.coop = CoopSession.new(converter.level(asset), converter.rules(lib.rules), players, NetProtocol.int_of(p_info, "seed", 1),
		shared, list.hand_cap(m.level_id))
	if m.coop.last_error != "":
		m.setup_error = m.coop.last_error
		return m
	m._connect()
	return m

func _connect() -> void:
	if net == null: return
	net.cmd_received.connect(_on_cmd)
	net.player_left.connect(_on_player_left)
	net.desync.connect(_on_desync)
	net.chat_received.connect(_on_chat)
	if net.has_signal("kicked"): net.kicked.connect(_on_kicked)

## Stops listening to the relay (the level is left).
func detach() -> void:
	if net == null: return
	for pair in [["cmd_received", _on_cmd], ["player_left", _on_player_left], ["desync", _on_desync], ["chat_received", _on_chat],
			["kicked", _on_kicked]]:
		if net.has_signal(pair[0]) and net.is_connected(pair[0], pair[1]): net.disconnect(pair[0], pair[1])
	net = null

## Leaves the match on purpose: tells the relay (the others get player_left) and stops listening.
func leave() -> void:
	if net != null and net.has_method("leave_room"): net.leave_room()
	detach()

## Sends a chat line to the room (it comes back through the relay like everyone's).
func say(text: String) -> void:
	if net != null and text.strip_edges() != "": net.chat(text.strip_edges())

func _on_kicked() -> void:
	_lose("You were removed from the match.")

## Starts round 1 (after the presentation is wired to coop.session).
func start() -> void:
	coop.start()
	_check_turn()

# ------------------------------------------------------------------ queries

var session: CoopLevelSession:
	get: return coop.session if coop != null else null

var current_player: String:
	get: return coop.current_player if coop != null else ""

## It is your turn and nothing of yours is on its way to the relay.
var my_turn: bool:
	get: return coop != null and not desync and not lost and awaiting == 0 and coop.current_player == me

func name_of(player: String) -> String:
	return names.get(player, "?")

func color_of(player: String) -> Color:
	return COLORS[int(slots.get(player, 0)) % COLORS.size()]

## You may command this unit (your tower, a leaver's, a base or an ally).
func controls(unit: Entity) -> bool:
	return coop != null and coop.controls(me, unit)

## The tower ids of your hand.
func my_hand() -> Array:
	return coop.hand_of(me) if coop != null else []

func my_energy() -> int:
	return coop.energy_of(me) if coop != null else 0

## "Your turn" / "Şule's turn" / "" (nobody acts).
func turn_text() -> String:
	var p := current_player
	if p == "": return ""
	return "Your turn" if p == me else "%s's turn" % name_of(p)

# ------------------------------------------------------------------ your commands

## Sends a command after checking it on the session (nothing changes here until the relay echoes it).
## false + reason when it is refused locally.
func send(cmd: Dictionary) -> bool:
	if coop == null or desync or lost:
		last_reason = "The match is not running."
		return false
	if awaiting > 0:
		last_reason = "Wait for your last move to arrive."
		return false
	if not _would_accept(cmd):
		last_reason = coop.last_reason if coop.last_reason != "" else "That cannot be done now"
		return false
	awaiting += 1
	last_reason = ""
	if net != null: net.send_cmd(coop.round, cmd)
	return true

var last_reason := ""

func place(tower_id: String, tile: Vector2i) -> bool: return send(CoopSession.place_command(tower_id, tile))
func sell(tower_id: String) -> bool: return send(CoopSession.sell_command(tower_id))
func cast(unit: Entity, ability: AbilityDef, aim: Aim) -> bool: return send(CoopSession.cast_command(unit, ability, aim))
func pass_turn() -> bool: return send({"k": "pass"})
func end_turn() -> bool: return send({"k": "end_turn"})

func _would_accept(cmd: Dictionary) -> bool:
	match str(cmd.get("k", "")):
		"pass", "end_turn": return coop.can_act(me)
		"place": return coop.can_place(me, str(cmd.tower), Vector2i(int(cmd.x), int(cmd.y)))
		"sell": return coop.can_sell(me, str(cmd.tower))
		"cast":
			var unit: Entity = coop.state.get_entity(int(cmd.unit))
			if unit == null: return false
			for a in unit.abilities:
				if a.name == cmd.ability: return coop.can_cast(me, unit, a)
			return false
	return false

# ------------------------------------------------------------------ relay → session

func _on_cmd(player: String, _round: int, _seq: int, cmd: Dictionary) -> void:
	if coop == null or desync: return
	if player == me: awaiting = maxi(0, awaiting - 1)
	var before := coop.round
	var ok := coop.apply_command(player, cmd)
	if not ok:
		command_applied.emit(player, cmd, ok)
		_desync(before, "%s's move was refused here (%s)." % [name_of(player), coop.last_reason])
		return
	if str(cmd.get("k", "")) == "pass": passed[player] = true
	command_applied.emit(player, cmd, ok)
	_after_change(before)

func _on_player_left(player: String) -> void:
	if coop == null: return
	if player == me or player == "":
		_lose("The connection to the match was lost.")
		return
	if not slots.has(player) or coop.left.has(player): return
	var before := coop.round
	coop.remove_player(player)
	chat_line.emit("", "%s left the match." % name_of(player), Color(0, 0, 0, 0))
	player_gone.emit(player, name_of(player))
	_after_change(before)

func _on_desync(round: int, _hashes: Dictionary) -> void:
	_desync(round, "The games no longer match (round %d)." % round)

func _on_chat(_from: String, from_name: String, text: String) -> void:
	chat_line.emit(from_name, text, color_of(_from))

## After a command or a leaver: a finished round sends its checksum; the acting player may have changed.
func _after_change(round_before: int) -> void:
	if coop.round != round_before: passed.clear()
	if coop.round != round_before or (coop.is_over and not checksums.has(round_before)):
		var h := coop.checksum()
		checksums.append(round_before)
		if net != null: net.send_checksum(round_before, h)
		round_checked.emit(round_before, h)
	_check_turn()

func _check_turn() -> void:
	var p := current_player
	if p != _last_turn:
		_last_turn = p
		turn_changed.emit(p)

func _desync(round: int, reason: String) -> void:
	if desync: return
	desync = true
	desync_reason = reason
	desynced.emit(round, reason)

func _lose(reason: String) -> void:
	if lost: return
	lost = true
	match_lost.emit(reason)
