class_name RelayClient
extends Node
## Autoload `Net`: the co-op relay client (docs/COOP-PROTOCOL.md). Talks JSON text frames over a WebSocketPeer to the
## relay (ws://92.5.94.11/ws/relay), or to an in-process FakeRelay (tests, the lobby's Offline practice). Polled from
## _process (no threads: works in the web export). Keeps what the relay last said (rooms, room, match) and emits a
## signal for every relay message. Sends hello (content hash + the profile's player name) as soon as the socket
## opens; a dropped connection retries with back-off while the player still wants to be online.
##   Net.connect_relay()                      # or Net.start_practice() for the offline room
##   Net.rooms_changed.connect(...); Net.list_rooms(); Net.create_room("Akşam", "chapter1-1", 2, "", hand)

enum State { OFFLINE, CONNECTING, HELLO, ONLINE, RECONNECTING }
const STATE_NAMES := ["Offline", "Connecting", "Saying hello", "Online", "Reconnecting"]

signal state_changed(state: int)
signal welcomed(player_id: String, version_ok: bool)
signal rooms_changed(rooms: Array)
## The room you are in changed ({} = you are in no room now).
signal room_changed(room: Dictionary)
## What changed in the room since the last state (NetProtocol.room_diff): joined / left / level / count / host.
signal room_notes(notes: Array)
signal error_received(code: String, text: String)
signal chat_received(from: String, name: String, text: String)
signal kicked
signal match_started(info: Dictionary)
signal cmd_received(player: String, round: int, seq: int, cmd: Dictionary)
signal desync(round: int, hashes: Dictionary)
signal player_left(player: String)
## Hand-off to the in-match code: emitted right after match_started with the match ready to build:
## {seed, level, shared_pool, players: [{id, name, hand (type ids), slot}] (slot order), local_player (your id)}.
signal match_ready(info: Dictionary)
## Your round trip to the relay changed (ms; -1 = unknown).
signal rtt_changed(ms: int)
## Every relay message, decoded (after the specific signal).
signal message_received(msg: Dictionary)

## Seconds before a connection attempt counts as failed; retry back-off (doubles up to the max).
const CONNECT_TIMEOUT := 8.0
const RETRY_FIRST := 2.0
const RETRY_MAX := 15.0

var url: String = NetProtocol.DEFAULT_URL
var state: int = State.OFFLINE
var player_id := ""
## The content hash sent in hello (ContentHash over data/content + "coop-1"); computed on first use.
var version := ""
var version_ok := true
## Overrides the profile's name (tests, tools); "" = SaveData.profile.player_name.
var player_name_override := ""
var rooms: Array = []
var room: Dictionary = {}
## The last match_start ({} before one).
var match_info: Dictionary = {}
## Connected to an in-process FakeRelay (Offline practice or a test), not the network.
var practice := false
var fake_relay: FakeRelay = null
var auto_reconnect := true
## Polls in _process (tests turn it off and call poll() themselves).
var auto_poll := true
## The last error code the relay sent ("" = none), and why the connection failed ("" = it did not).
var last_error := ""
var connect_failure := ""
## Frames sent (tests and the dev panel read it): [msg Dictionary, …], last 64.
var sent_log: Array = []

var _peer = null          # WebSocketPeer or FakeRelay.Link
var _want := false        # the player wants to be online
var _seq := 0
var _retry_in := 0.0
var _retry_wait := RETRY_FIRST
var _connecting_for := 0.0
## Round trip to the relay in ms (a `list` → `rooms` exchange every RTT_EVERY seconds while online); -1 = unknown.
var rtt_ms := -1
const RTT_EVERY := 5.0
var _rtt_in := 0.0
var _rtt_sent := -1
## The password you created or joined the room with ("" = open), for the room header and Copy.
var room_password := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if auto_poll: poll(delta)

# ------------------------------------------------------------------ connection

var is_online: bool:
	get: return state == State.ONLINE
var in_room: bool:
	get: return not room.is_empty()
var is_host: bool:
	get: return in_room and str(room.get("host", "")) == player_id
var state_name: String:
	get: return STATE_NAMES[state]

## Connects to the relay (the default URL unless one is given). Does nothing while already connected there.
func connect_relay(to_url := "") -> void:
	if to_url != "": url = to_url
	if practice: disconnect_relay()
	_want = true
	if state == State.ONLINE or state == State.CONNECTING or state == State.HELLO: return
	_open_socket()

## Connects to an in-process relay (a test, or Offline practice).
func connect_fake(relay: FakeRelay) -> void:
	disconnect_relay()
	practice = true
	fake_relay = relay
	_want = true
	_peer = relay.connect_client()
	_set_state(State.HELLO)
	_send(NetProtocol.hello(_version(), _player_name()))

## Offline practice: a local relay with one room of one player on this machine (no network).
func start_practice() -> void:
	var relay := FakeRelay.new()
	relay.shared_pool_of = func(level_id): return CoopLevels.shared_pool(level_id)
	connect_fake(relay)
	poll()

## Closes the connection on purpose (no reconnect).
func disconnect_relay() -> void:
	_want = false
	if _peer != null:
		_peer.close()
		_peer = null
	practice = false
	fake_relay = null
	_reset_session()
	_set_state(State.OFFLINE)

func _open_socket() -> void:
	practice = false
	fake_relay = null
	var ws := WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	var err := ws.connect_to_url(url)
	if err != OK:
		connect_failure = "Can't reach the server (%s)." % error_string(err)
		_peer = null
		_schedule_retry()
		return
	_peer = ws
	_connecting_for = 0.0
	_set_state(State.CONNECTING if state != State.RECONNECTING else State.RECONNECTING)

## Reads the socket: sends hello once it opens, handles every frame waiting, notices a closed connection.
func poll(delta := 0.0) -> void:
	if _peer == null:
		if _want and not practice and (state == State.RECONNECTING or state == State.OFFLINE) and auto_reconnect and _retry_in > 0.0:
			_retry_in -= delta
			if _retry_in <= 0.0: _open_socket()
		return
	_peer.poll()
	var ready_state: int = _peer.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN:
		if state == State.CONNECTING or state == State.RECONNECTING:
			_set_state(State.HELLO)
			_send(NetProtocol.hello(_version(), _player_name()))
		for text in _frames(): _handle_text(text)
		if state == State.ONLINE and not practice: # an in-process relay has no round trip to measure
			_rtt_in -= delta
			if _rtt_in <= 0.0 and _rtt_sent < 0:
				_rtt_in = RTT_EVERY
				_rtt_sent = Time.get_ticks_msec()
				_send(NetProtocol.list())
	elif ready_state == WebSocketPeer.STATE_CONNECTING:
		_connecting_for += delta
		if _connecting_for > CONNECT_TIMEOUT:
			connect_failure = "Can't reach the server."
			_peer.close()
			_peer = null
			_lost()
	elif ready_state == WebSocketPeer.STATE_CLOSED:
		for text in _frames(): _handle_text(text) # what arrived before the close
		if connect_failure == "" or state == State.ONLINE: connect_failure = "The connection to the server was lost."
		_peer = null
		_lost()

func _frames() -> Array:
	var out := []
	if _peer is WebSocketPeer:
		while _peer.get_available_packet_count() > 0:
			out.append(_peer.get_packet().get_string_from_utf8())
	elif _peer != null:
		out = _peer.take()
	return out

func _lost() -> void:
	var was_in_match := not match_info.is_empty()
	_reset_session()
	if was_in_match: player_left.emit(player_id) # our own seat is gone: the match screen leaves
	if _want and auto_reconnect and not practice: _schedule_retry()
	else: _set_state(State.OFFLINE)

func _schedule_retry() -> void:
	_retry_in = _retry_wait
	_retry_wait = minf(_retry_wait * 2.0, RETRY_MAX)
	_set_state(State.RECONNECTING if _want else State.OFFLINE)

func _reset_session() -> void:
	var had_room := in_room
	room = {}
	match_info = {}
	rooms = []
	_seq = 0
	_rtt_sent = -1
	if rtt_ms != -1:
		rtt_ms = -1
		rtt_changed.emit(rtt_ms)
	if had_room: room_changed.emit(room)

func _set_state(s: int) -> void:
	if s == state: return
	state = s
	state_changed.emit(s)

# ------------------------------------------------------------------ client → relay

func list_rooms() -> void: _send(NetProtocol.list())
## mission: the room's mission id (extra field, the relay ignores it); "" = the level's co-op mission, if any.
func create_room(room_name: String, level: String, count: int, password: String, hand: Array, mission: String = "") -> void:
	room_password = password
	if mission == "":
		var m := CoopLevels.mission_for_level(level)
		if m != null: mission = m.id
	_send(NetProtocol.create(room_name, level, count, password, hand, mission))
func join_room(room_id: String, password: String, hand: Array) -> void:
	room_password = password
	_send(NetProtocol.join(room_id, password, hand))
## Leaves the room (or the match) at once on this side; the relay keeps the room open for the others.
func leave_room() -> void:
	_send(NetProtocol.leave())
	var had := in_room
	room = {}
	match_info = {}
	if had: room_changed.emit(room)
func set_ready(value: bool) -> void: _send(NetProtocol.ready(value))
func set_level(level: String) -> void: _send(NetProtocol.set_level(level))
func set_count(count: int) -> void: _send(NetProtocol.set_count(count))
func kick(player: String) -> void: _send(NetProtocol.kick(player))
func chat(text: String) -> void:
	if text.strip_edges() != "": _send(NetProtocol.chat(text))
func set_hand(hand: Array) -> void: _send(NetProtocol.set_hand(hand))
func start_match() -> void: _send(NetProtocol.start())
## Sends one of your commands for the round (seq counts 1, 2, 3… per match); returns the seq used.
func send_cmd(round: int, command: Dictionary) -> int:
	_seq += 1
	_send(NetProtocol.cmd(round, _seq, command))
	return _seq
func send_checksum(round: int, hash: String) -> void: _send(NetProtocol.checksum(round, hash))

func _send(msg: Dictionary) -> bool:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return false
	sent_log.append(msg)
	if sent_log.size() > 64: sent_log.pop_front()
	return _peer.send_text(NetProtocol.encode(msg)) == OK

# ------------------------------------------------------------------ relay → client

func _handle_text(text: String) -> void:
	var m = NetProtocol.decode(text)
	if m == null:
		push_warning("[Net] not a protocol frame: " + text.substr(0, 80))
		return
	handle_message(m)

## Handles one decoded relay message (public for tests that inject messages).
func handle_message(m: Dictionary) -> void:
	match str(m.t):
		"welcome":
			player_id = str(m.get("player", ""))
			version_ok = bool(m.get("version_ok", true))
			connect_failure = ""
			_retry_wait = RETRY_FIRST
			_set_state(State.ONLINE)
			welcomed.emit(player_id, version_ok) # the relay sends `rooms` right after welcome
		"rooms":
			if _rtt_sent >= 0:
				rtt_ms = Time.get_ticks_msec() - _rtt_sent
				_rtt_sent = -1
				rtt_changed.emit(rtt_ms)
			rooms = (m.get("rooms", []) as Array).duplicate(true)
			rooms_changed.emit(rooms)
		"room":
			var new_room: Dictionary = m.duplicate(true)
			new_room.erase("t")
			if NetProtocol.find_player(new_room, player_id) == null: # not ours any more
				if in_room:
					room = {}
					room_changed.emit(room)
				return
			var notes := NetProtocol.room_diff(room, new_room)
			room = new_room
			room_changed.emit(room)
			if notes.size() > 0: room_notes.emit(notes)
		"error":
			last_error = str(m.get("code", ""))
			error_received.emit(last_error, str(m.get("text", NetProtocol.error_text(last_error))))
		"chat":
			chat_received.emit(str(m.get("from", "")), str(m.get("name", "")), str(m.get("text", "")))
		"kicked":
			room = {}
			match_info = {}
			kicked.emit()
			room_changed.emit(room)
		"match_start":
			match_info = m.duplicate(true)
			match_info.erase("t")
			_seq = 0
			if in_room: room["started"] = true
			match_started.emit(match_info)
			start_coop_match(match_info)
		"cmd":
			cmd_received.emit(str(m.get("player", "")), NetProtocol.int_of(m, "round"), NetProtocol.int_of(m, "seq"),
				m.get("cmd", {}) if m.get("cmd") is Dictionary else {})
		"desync":
			desync.emit(NetProtocol.int_of(m, "round"), m.get("hashes", {}) if m.get("hashes") is Dictionary else {})
		"player_left":
			player_left.emit(str(m.get("player", "")))
		"ping":
			_send(NetProtocol.pong())
	message_received.emit(m)

## The hand-off point (the coordinator's contract): emits match_ready(info) with local_player added. The scene
## change and the session belong to the in-match code listening to match_ready.
func start_coop_match(info: Dictionary) -> void:
	var out := info.duplicate(true)
	out["players"] = NetProtocol.players_by_slot(out)
	out["local_player"] = player_id
	match_ready.emit(out)

## Set when a co-op match is left: the Camp opens the lobby again (the in-match code sets it when leaving).
var reopen_lobby := false

# ------------------------------------------------------------------ identity

func _player_name() -> String:
	if player_name_override != "": return player_name_override
	var sd = get_node_or_null("/root/SaveData") if is_inside_tree() else null
	var n: String = sd.profile.player_name if sd != null and sd.profile != null else ""
	return n if n.strip_edges() != "" else "Player"

func _version() -> String:
	if version == "": version = CoopLevels.content_version()
	return version

## A player's round trip for the room's rows: yours as measured, another's when the relay reports one
## (`ping_ms` on the player entry — v1 does not), else -1.
func ping_of(player: String) -> int:
	if player == player_id: return rtt_ms
	var p = NetProtocol.find_player(room, player)
	return NetProtocol.int_of(p, "ping_ms", -1) if p != null else -1
