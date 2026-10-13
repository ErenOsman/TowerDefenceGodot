extends SceneTree
## End-to-end co-op bot: a headless Godot client that talks the relay protocol itself (no RelayClient dependency),
## creates or joins a room, readies, and plays the match with the golden policy through CoopSession, sending its
## commands and per-round checksums. Two of these against the live relay = a real lockstep test (tools/coop_two.sh).
##   godot --headless --path . -s tools/coop_bot.gd -- host|guest <player name> <room name> <level id> [rounds] [url]
## Exit 0 when the match ran <rounds> rounds (or ended) with no desync and no refused command; 1 otherwise.

var role := "host"
var my_name := "Bot"
var room_name := "bots"
var level_id := "chapter1-1"
var max_rounds := 6
var url := "ws://127.0.0.1/ws/relay"

var ws := WebSocketPeer.new()
var me := ""
var room_id := ""
var readied := false
var started := false
var coop: CoopSession = null
var seq := 0
var pending := false          # my last cmd not yet echoed
var last_round := 0
var checked_rounds := {}
var applied := 0
var refused := 0
var t0 := 0
var ended := false
var hello_sent := false

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: role = a[0]
	if a.size() > 1: my_name = a[1]
	if a.size() > 2: room_name = a[2]
	if a.size() > 3: level_id = a[3]
	if a.size() > 4: max_rounds = int(a[4])
	if a.size() > 5: url = a[5]
	root.get_node("GameApp").ensure_loaded()
	t0 = Time.get_ticks_msec()
	var err := ws.connect_to_url(url)
	if err != OK:
		print("BOT %s: connect error %d" % [my_name, err]); quit(1)

func _process(_dt: float) -> bool:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not hello_sent:
			hello_sent = true
			_send({"t": "hello", "version": ContentHash.compute(), "name": my_name, "client": "godot-td/bot"})
		while ws.get_available_packet_count() > 0:
			var msg = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if msg is Dictionary: _on(msg)
		if started and coop != null and not ended: _play()
	elif st == WebSocketPeer.STATE_CLOSED:
		print("BOT %s: socket closed %d %s" % [my_name, ws.get_close_code(), ws.get_close_reason()])
		_finish(1)
	if Time.get_ticks_msec() - t0 > 240000:
		print("BOT %s: timeout" % my_name); _finish(1)
	return false

func _send(d: Dictionary) -> void:
	ws.send_text(JSON.stringify(d))

func _on(m: Dictionary) -> void:
	match m.get("t"):
		"ping": _send({"t": "pong"})
		"welcome":
			me = m.player
			print("BOT %s: welcome id=%s version_ok=%s" % [my_name, me, m.get("version_ok")])
			if role == "host":
				_send({"t": "create", "name": room_name, "level": level_id, "count": 2, "hand": _hand()})
		"rooms":
			if role == "guest" and room_id == "":
				for r in m.rooms:
					if r.name == room_name and not r.get("started", false):
						room_id = r.id
						_send({"t": "join", "room": room_id, "hand": _hand()})
						break
		"room":
			room_id = m.id
			var n: int = m.players.size()
			if not readied and n >= 2:
				readied = true
				_send({"t": "ready", "value": true})
			if role == "host" and m.host == me and n >= 2 and not m.get("started", false):
				var all_ready := true
				for p in m.players: if not p.ready: all_ready = false
				if all_ready: _send({"t": "start"})
		"error":
			print("BOT %s: error %s %s" % [my_name, m.get("code"), m.get("text")])
		"match_start":
			_start_match(m)
		"cmd":
			if coop == null: return
			var ok := coop.apply_command(m.player, m.cmd)
			if ok: applied += 1
			else:
				refused += 1
				print("BOT %s: REFUSED cmd from %s: %s (%s)" % [my_name, m.player, JSON.stringify(m.cmd), coop.last_reason])
			if m.player == me: pending = false
			if coop.round > last_round:
				var r := last_round
				last_round = coop.round
				_send({"t": "checksum", "round": r, "hash": coop.checksum()})
		"desync":
			print("BOT %s: DESYNC at round %s %s" % [my_name, m.get("round"), JSON.stringify(m.get("hashes"))])
			_finish(1)
		"player_left":
			if coop != null: coop.remove_player(m.player)
		"kicked":
			print("BOT %s: kicked" % my_name); _finish(1)

func _hand() -> Array:
	var app = root.get_node("GameApp")
	var ids := []
	for t in app.catalog.tower_types:
		ids.append(t.get_id())
	ids.sort()
	# host takes the first three types, guest the next three (wrapping)
	var start := 0 if role == "host" else 3
	var out := []
	for i in 3: out.append(ids[(start + i) % ids.size()])
	return out

func _start_match(m: Dictionary) -> void:
	var app = root.get_node("GameApp")
	var la = app.catalog.find_level(m.level)
	var level = app.convert.level(la)
	var players := []
	for p in m.players:
		var hand = CoopSession.build_hand(p.id, p.hand, func(t): return app.convert.tower_type(app.catalog.find_tower(t)))
		players.append({"id": p.id, "hand": hand})
	coop = CoopSession.new(level, app.rules, players, int(m.seed), bool(m.shared_pool), 3)
	if coop.last_error != "":
		print("BOT %s: session error %s" % [my_name, coop.last_error]); _finish(1); return
	coop.start()
	last_round = coop.round
	started = true
	print("BOT %s: match started level=%s seed=%s players=%d shared=%s" % [my_name, m.level, m.seed, players.size(), m.shared_pool])

## One command per frame when it is my turn and my previous command has been echoed.
func _play() -> void:
	if coop.is_over or coop.round > max_rounds:
		_finish(0); return
	if pending or coop.current_player != me: return
	var cmd := _next_command()
	seq += 1
	pending = true
	_send({"t": "cmd", "round": coop.round, "seq": seq, "cmd": cmd})

func _next_command() -> Dictionary:
	var s = coop.session
	for t in coop.hand_of(me):
		if s.placed.has(t.id): continue
		for y in s.state.grid.height:
			for x in s.state.grid.width:
				if coop.can_place(me, t.id, Vector2i(x, y)):
					return CoopSession.place_command(t.id, Vector2i(x, y))
	for unit in coop.units_of(me):
		if not unit.alive: continue
		for ability in unit.abilities:
			if ability.targeting.is_movement: continue
			if not coop.can_cast(me, unit, ability): continue
			var aim = Instinct.quick_cast(s.state, unit, ability)
			if aim == null: continue
			return CoopSession.cast_command(unit, ability, aim)
	return {"k": "end_turn"}

func _finish(code: int) -> void:
	if ended: return
	ended = true
	var outcome := "n/a"
	if coop != null: outcome = "%s round %d applied %d refused %d" % [Outcome.name_of(coop.session.outcome), coop.round, applied, refused]
	print("BOT %s: done code=%d %s" % [my_name, code, outcome])
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send({"t": "leave"})
		ws.close()
	quit(code if refused == 0 else 1)
