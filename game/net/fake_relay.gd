class_name FakeRelay
extends RefCounted
## An in-process co-op relay speaking protocol v1 (docs/Co-op Protocol.md), for tests and the lobby's "Offline
## practice" (one local player). Same rules as the real relay: hello first, lobby of rooms on the same version,
## create/join/leave/ready/set_level/set_count/kick/chat/set_hand/start, cmd stamped with the player and broadcast to
## the room in arrival order (sender included), checksums compared per round (mismatch → desync), leaving during a
## match → player_left. No sockets, no threads: a client gets a `Link` (connect_client) whose send_text() is handled
## at once and whose replies wait in its inbox until the client polls.

## The connection a client holds (the transport RelayClient talks to, like a WebSocketPeer).
class Link extends RefCounted:
	var relay: FakeRelay
	var conn_id := 0
	var player_id := ""
	var name := ""
	var version := ""
	var hello_done := false
	var room_id := ""
	var inbox: Array[String] = []
	var open := true
	var missed_pongs := 0

	## WebSocketPeer-like: 1 = open, 3 = closed.
	func get_ready_state() -> int:
		return WebSocketPeer.STATE_OPEN if open else WebSocketPeer.STATE_CLOSED

	func send_text(text: String) -> int:
		if not open: return ERR_UNAVAILABLE
		relay.receive(self, text)
		return OK

	func poll() -> void:
		pass

	## The frames waiting for the client (and empties the inbox).
	func take() -> Array[String]:
		var out := inbox.duplicate()
		inbox.clear()
		return out

	func close(_code := 1000, _reason := "") -> void:
		if not open: return
		relay.drop(self)

	func push(msg: Dictionary) -> void:
		if open: inbox.append(NetProtocol.encode(msg))

## Optional: the only version the relay accepts as current (welcome.version_ok); "" accepts any.
var current_version := ""
## Seeds for matches: the next match_start's seed (incremented per match), unless seed_fn gives one.
var next_seed := 1001
var seed_fn: Callable = Callable()
## level id → bool (the level's energy rule) for match_start.shared_pool; unset = false.
var shared_pool_of: Callable = Callable()
## Tools only: player id → round trip in ms, sent as `ping_ms` on the room's players (the real relay v1 sends none).
var player_pings := {}
## Every message the relay received, as [player_id, msg] (tests read it).
var received: Array = []

var links: Array = []
var rooms := {}          # room id → room Dictionary (internal: has "password", "version", "checksums")
var _next_conn := 1
var _next_room := 1

## A new client connection.
func connect_client() -> Link:
	var l := Link.new()
	l.relay = self
	l.conn_id = _next_conn
	l.player_id = "p%07d" % _next_conn
	_next_conn += 1
	links.append(l)
	return l

## The client went away (closed or dropped): leaves its room like `leave`.
func drop(l: Link) -> void:
	if not l.open: return
	_leave_room(l)
	l.open = false
	links.erase(l)

## Sends ping to everyone; a client that missed 3 pongs is dropped (tests drive this by hand).
func ping_all() -> void:
	for l in links.duplicate():
		if not l.hello_done: continue
		l.missed_pongs += 1
		if l.missed_pongs > 3:
			drop(l)
			continue
		l.push({"t": "ping"})

# ------------------------------------------------------------------ messages

func receive(l: Link, frame: String) -> void:
	var m = NetProtocol.decode(frame)
	if m == null:
		_error(l, "bad_request", "Not a protocol message.")
		return
	received.append([l.player_id, m])
	var t: String = m.t
	if not l.hello_done:
		if t != "hello":
			drop(l)
			return
		l.hello_done = true
		l.version = str(m.get("version", ""))
		l.name = NetProtocol.clamp_text(str(m.get("name", "")), NetProtocol.MAX_PLAYER_NAME)
		if l.name == "": l.name = "Player"
		var ok := _hex16(l.version) and (current_version == "" or current_version == l.version)
		l.push({"t": "welcome", "player": l.player_id, "version_ok": ok})
		if not ok:
			drop(l)
			return
		l.push(_rooms_msg(l))
		return
	match t:
		"list": l.push(_rooms_msg(l))
		"create": _create(l, m)
		"join": _join(l, m)
		"leave":
			_leave_room(l)
			l.push(_rooms_msg(l))
		"ready": _with_room(l, m, func(room):
			if room.started:
				_error(l, "started", NetProtocol.error_text("started"))
				return
			_player(room, l.player_id).ready = bool(m.get("value", false))
			_push_room(room))
		"set_level": _host_only(l, m, func(room):
			if room.started:
				_error(l, "started", NetProtocol.error_text("started"))
				return
			room.level = str(m.get("level", room.level))
			_reset_ready(room)
			_push_room(room)
			_push_lobby())
		"set_count": _host_only(l, m, func(room):
			if room.started:
				_error(l, "started", NetProtocol.error_text("started"))
				return
			_set_count(room, NetProtocol.int_of(m, "count", room.count)))
		"kick": _host_only(l, m, func(room):
			var who := str(m.get("player", ""))
			var target := _link_of(who)
			if who == l.player_id or _player(room, who) == null:
				_error(l, "bad_request", "No such player.")
				return
			_remove_player(room, who)
			if target != null:
				target.room_id = ""
				target.push({"t": "kicked"})
				target.push(_rooms_msg(target))
			_push_room(room)
			_push_lobby())
		"chat": _with_room(l, m, func(room):
			var said := NetProtocol.clamp_text(str(m.get("text", "")), NetProtocol.MAX_CHAT)
			if said == "": return
			_broadcast(room, {"t": "chat", "from": l.player_id, "name": l.name, "text": said}))
		"set_hand": _with_room(l, m, func(room):
			if room.started:
				_error(l, "started", "The match has started.")
				return
			_player(room, l.player_id).hand = (m.get("hand", []) as Array).duplicate()
			_push_room(room))
		"start": _host_only(l, m, func(room): _start(l, room))
		"cmd": _with_room(l, m, func(room):
			if not room.started:
				_error(l, "bad_request", "No match is running.")
				return
			_broadcast(room, {"t": "cmd", "player": l.player_id, "round": NetProtocol.int_of(m, "round"),
				"seq": NetProtocol.int_of(m, "seq"), "cmd": m.get("cmd", {})}))
		"checksum": _with_room(l, m, func(room): _checksum(room, l.player_id, NetProtocol.int_of(m, "round"), str(m.get("hash", ""))))
		"pong": l.missed_pongs = 0
		_: _error(l, "bad_request", "Unknown message '%s'." % t)

func _create(l: Link, m: Dictionary) -> void:
	if l.room_id != "" or not _hand_ok(m):
		_error(l, "bad_request", "Leave your room first." if l.room_id != "" else "Bad hand.")
		return
	var room_name := str(m.get("name", "")).strip_edges()
	if room_name.length() > NetProtocol.MAX_ROOM_NAME or not NetProtocol.name_allowed(room_name):
		_error(l, "bad_name", NetProtocol.error_text("bad_name"))
		return
	var id := "r%d" % _next_room
	_next_room += 1
	var room := {"id": id, "name": room_name, "level": str(m.get("level", "")),
		"count": clampi(NetProtocol.int_of(m, "count", NetProtocol.DEFAULT_COUNT), NetProtocol.MIN_COUNT, NetProtocol.MAX_COUNT),
		"password": str(m.get("password", "")), "version": l.version, "host": l.player_id, "started": false,
		"players": [], "next_slot": 0, "checksums": {}}
	rooms[id] = room
	_add_player(room, l, m.get("hand", []))
	_push_room(room)
	_push_lobby()

func _join(l: Link, m: Dictionary) -> void:
	if l.room_id != "" or not _hand_ok(m):
		_error(l, "bad_request", "Leave your room first." if l.room_id != "" else "Bad hand.")
		return
	var room = rooms.get(str(m.get("room", "")))
	if room == null:
		_error(l, "not_found", NetProtocol.error_text("not_found"))
		return
	if room.version != l.version:
		_error(l, "version", NetProtocol.error_text("version"))
		return
	if room.started:
		_error(l, "started", NetProtocol.error_text("started"))
		return
	if _player(room, l.player_id) != null:
		_push_room(room)
		return
	if room.players.size() >= room.count:
		_error(l, "full", NetProtocol.error_text("full"))
		return
	if room.password != "" and str(m.get("password", "")) != room.password:
		_error(l, "wrong_password", NetProtocol.error_text("wrong_password"))
		return
	_add_player(room, l, m.get("hand", []))
	_push_room(room)
	_push_lobby()

func _start(l: Link, room: Dictionary) -> void:
	if room.started:
		_error(l, "started", NetProtocol.error_text("started"))
		return
	for p in room.players:
		if not p.ready:
			_error(l, "bad_request", "Not everyone is ready.")
			return
	room.started = true
	var seed_value: int = seed_fn.call(room) if seed_fn.is_valid() else next_seed
	next_seed += 1
	var players := []
	for p in NetProtocol.players_by_slot(_public_room(room)):
		players.append({"id": p.id, "name": p.name, "hand": p.hand, "slot": p.slot})
	var shared: bool = bool(shared_pool_of.call(room.level)) if shared_pool_of.is_valid() else false
	_broadcast(room, {"t": "match_start", "seed": seed_value, "level": room.level, "shared_pool": shared, "players": players})
	_push_room(room)
	_push_lobby()

func _checksum(room: Dictionary, player_id: String, round: int, hash: String) -> void:
	if not room.checksums.has(round): room.checksums[round] = {}
	room.checksums[round][player_id] = hash
	var got: Dictionary = room.checksums[round]
	for p in room.players:
		if not got.has(p.id): return
	var first := ""
	var same := true
	for p in room.players:
		if first == "": first = got[p.id]
		elif got[p.id] != first: same = false
	if not same: _broadcast(room, {"t": "desync", "round": round, "hashes": got.duplicate()})
	room.checksums.erase(round)

func _set_count(room: Dictionary, count: int) -> void:
	count = clampi(count, NetProtocol.MIN_COUNT, NetProtocol.MAX_COUNT)
	room.count = count
	# the last joined leave first
	var by_slot := NetProtocol.players_by_slot(_public_room(room))
	while room.players.size() > count:
		var last = by_slot.pop_back()
		if last.id == room.host: # never the host: the next latest instead
			var keep = last
			last = by_slot.pop_back()
			by_slot.append(keep)
		_remove_player(room, last.id)
		var target := _link_of(last.id)
		if target != null:
			target.room_id = ""
			target.push({"t": "kicked"})
			target.push(_rooms_msg(target))
	_reset_ready(room)
	_push_room(room)
	_push_lobby()

# ------------------------------------------------------------------ room state

func _add_player(room: Dictionary, l: Link, hand) -> void:
	room.players.append({"id": l.player_id, "name": l.name, "ready": false, "hand": (hand if hand is Array else []).duplicate(),
		"slot": room.players.size()})
	l.room_id = room.id

func _remove_player(room: Dictionary, player_id: String) -> void:
	for p in room.players.duplicate():
		if p.id == player_id: room.players.erase(p)
	for i in room.players.size(): room.players[i].slot = i # slots renumber 0…n-1; host = slot 0
	if room.players.size() > 0: room.host = room.players[0].id
	if room.started and room.players.size() > 0: _broadcast(room, {"t": "player_left", "player": player_id})

func _leave_room(l: Link) -> void:
	if l.room_id == "": return
	var room = rooms.get(l.room_id)
	l.room_id = ""
	if room == null: return
	_remove_player(room, l.player_id)
	if room.players.is_empty(): rooms.erase(room.id)
	else:
		if room.started: _resolve_checksums(room)
		_push_room(room)
	_push_lobby()

## A player left mid-round: the rounds that now have every remaining hash are compared.
func _resolve_checksums(room: Dictionary) -> void:
	for round in room.checksums.keys():
		if room.players.size() > 0:
			var pid: String = room.players[0].id
			if room.checksums[round].has(pid): _checksum(room, pid, round, room.checksums[round][pid])

func _reset_ready(room: Dictionary) -> void:
	for p in room.players: p.ready = false

func _player(room: Dictionary, player_id: String):
	for p in room.players:
		if p.id == player_id: return p
	return null

func _link_of(player_id: String) -> Link:
	for l in links:
		if l.player_id == player_id: return l
	return null

## The room as clients see it (no password, version or checksums).
func _public_room(room: Dictionary) -> Dictionary:
	var players := []
	for p in room.players:
		var e := {"id": p.id, "name": p.name, "ready": p.ready, "hand": p.hand.duplicate(), "slot": p.slot}
		if player_pings.has(p.id): e["ping_ms"] = player_pings[p.id]
		players.append(e)
	return {"t": "room", "id": room.id, "name": room.name, "level": room.level, "count": room.count, "host": room.host,
		"locked": room.password != "", "started": room.started, "players": players}

func _rooms_msg(l: Link) -> Dictionary:
	var out := []
	for room in rooms.values():
		if room.version != l.version: continue # other versions are never listed
		var host = _player(room, room.host)
		out.append({"id": room.id, "name": room.name, "level": room.level, "count": room.count, "players": room.players.size(),
			"locked": room.password != "", "started": room.started, "host_name": host.name if host != null else "",
			"host_hand": host.hand.duplicate() if host != null else []})
	return {"t": "rooms", "rooms": out}

func _push_room(room: Dictionary) -> void:
	_broadcast(room, _public_room(room))

func _push_lobby() -> void:
	for l in links:
		if l.hello_done and l.room_id == "": l.push(_rooms_msg(l))

func _broadcast(room: Dictionary, msg: Dictionary) -> void:
	for p in room.players:
		var l := _link_of(p.id)
		if l != null: l.push(msg)

func _error(l: Link, code: String, text: String) -> void:
	l.push({"t": "error", "code": code, "text": text})

func _with_room(l: Link, _m: Dictionary, f: Callable) -> void:
	var room = rooms.get(l.room_id)
	if room == null:
		_error(l, "not_found", "You are not in a room.")
		return
	f.call(room)

func _host_only(l: Link, m: Dictionary, f: Callable) -> void:
	_with_room(l, m, func(room):
		if room.host != l.player_id:
			_error(l, "not_host", NetProtocol.error_text("not_host"))
			return
		f.call(room))

func _hand_ok(m: Dictionary) -> bool:
	var h = m.get("hand", [])
	if not (h is Array) or h.size() > 16: return false
	for e in h:
		if not (e is String) or e.length() > 64: return false
	return true

static func _hex16(v: String) -> bool:
	if v.length() != 16: return false
	for c in v:
		if not "0123456789abcdef".contains(c): return false
	return true
