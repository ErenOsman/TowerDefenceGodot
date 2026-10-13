extends SceneTree
## Headless-render proof of the co-op HUD: a 2-player match launched through CoopLaunch with a stub relay (your
## commands are echoed back at once, the other player's are injected). Shots: your turn (the turn strip, Pass,
## your hand only, your tower selected), the other player's turn (everything waits: "Waiting for Şule", the other's
## tower read-only in the inspector), the chat open, and the "left the match" banner.
##   ~/godot/run.sh projects/td -s tools/coop_hud_shot.gd -- [level id] [out dir] [prefix]
## The save is pointed at user://coop_hud_shot.json (the real save is untouched).

var level_id := "chapter1-3"
var out_dir := "user://shots"
var prefix := "coop"
var level: LevelController
var hud: Hud
var net: StubRelay

const ME := "eren0001"
const OTHER := "sule0002"

## The relay as CoopMode sees it: a command you send comes back (stamped with your id) on the next frame.
class StubRelay extends RefCounted:
	signal cmd_received(player: String, round: int, seq: int, cmd: Dictionary)
	signal player_left(player: String)
	signal desync(round: int, hashes: Dictionary)
	signal chat_received(from: String, name: String, text: String)
	signal kicked
	var player_id := ""
	var reopen_lobby := false
	var sent: Array = []
	var _seq := 0
	func send_cmd(round: int, cmd: Dictionary) -> int:
		_seq += 1
		sent.append(cmd)
		(func(): cmd_received.emit(player_id, round, _seq, JSON.parse_string(JSON.stringify(cmd)))).call_deferred()
		return _seq
	func send_checksum(_round: int, _hash: String) -> void: pass
	func chat(text: String) -> void:
		(func(): chat_received.emit(player_id, "Eren", text)).call_deferred()
	func leave_room() -> void: pass

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: level_id = args[0]
	if args.size() > 1: out_dir = args[1]
	if args.size() > 2: prefix = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	var sd = root.get_node_or_null("SaveData")
	if sd != null:
		sd.path = "user://coop_hud_shot.json"
		sd.data = GameData.new()
		sd.data.profile.create("Eren")
		sd.data.settings.always_show_health = false
	net = StubRelay.new()
	net.player_id = ME
	CoopLaunch.request({"seed": 7, "level": level_id, "shared_pool": false, "local_player": ME,
		"players": [{"id": ME, "name": "Eren", "hand": ["archer", "cannon", "mage"], "slot": 0},
			{"id": OTHER, "name": "Şule", "hand": ["archer", "priest"], "slot": 1}]}, net)
	var scene: PackedScene = load("res://game/level/level.tscn")
	level = scene.instantiate()
	level.instant_override = false
	root.add_child(level)
	await _frames(4)
	if level.setup_error != null:
		print("SETUP ERROR: ", level.setup_error)
		quit(1)
		return
	hud = level.hud as Hud
	_check(level.is_coop, "co-op launch")
	_check(level.hand_towers.size() == 3, "only my hand in the tray (%d)" % level.hand_towers.size())
	_park_mouse()
	await _settle()
	await _frames(30)

	# your turn: place a tower (sent, echoed, applied), select it
	var mine: Array = level.hand_towers
	var tiles := _tiles_for(mine[0].id, 3)
	level.toggle_placing(mine[0].id)
	level.click_tile(tiles[0])
	await _frames(3)
	await _settle()
	_check(level.session.placed_tower(mine[0].id) != null, "my placement applied on the echo")
	_check(net.sent.size() == 1, "sent once (%d)" % net.sent.size())
	await _frames(20)
	# Pass hovered: its tooltip (order after passing)
	var dial: Control = hud.coop_hud.dial
	_move(dial.get_global_rect().position + Vector2(HudCoop.PASS_R - 10, HudCoop.PASS_R - 10))
	await _frames(30)
	net.chat_received.emit(OTHER, "Şule", "I'll take the left road!") # fresh: lines fade after a few seconds
	await _frames(2)
	level.chat_lines.back()["at"] = Time.get_ticks_msec() + 30000 # software rendering is slow: keep the line in its shown time
	await _frames(4)
	await _shot("1_your_turn")
	_park_mouse()

	# pass: Şule acts; she places her archer (a relay command from her), we select it
	level.pass_turn()
	await _frames(3)
	await _settle()
	_check(level.current_player == OTHER, "Şule's turn after Pass")
	_check(not level.can_act and level.wait_reason == "Waiting for Şule", "everything waits: " + level.wait_reason)
	var theirs: TowerDef = level.coop.coop.hand_of(OTHER)[0]
	var t2 := _tiles_for_player(OTHER, theirs.id, 1)
	net.cmd_received.emit(OTHER, 1, 1, CoopSession.place_command(theirs.id, t2[0]))
	await _settle()
	var their_tower := level.session.placed_tower(theirs.id)
	_check(their_tower != null, "Şule's placement applied")
	level.select(their_tower.id)
	await _frames(20)
	_check(not hud.action_bar.visible, "no action bar for her tower")
	_check(not hud.inspector._sell.visible, "no Sell on her tower")
	_check(hud.coop_hud.face.visible, "End turn shows her turn")
	await _shot("2_other_turn")

	# her leaving: the toast, her turn skipped (my turn again); the chat input open
	net.player_left.emit(OTHER)
	hud.coop_hud.open_chat()
	await _frames(3)
	await _settle()
	level.select(-1)
	await _frames(20)
	_check(level.current_player == ME, "my turn again after she left")
	await _shot("3_chat_player_left")
	hud.coop_hud.close_chat()
	print("COOP SHOT OK" if _problems.is_empty() else "COOP SHOT PROBLEMS " + str(_problems))
	CoopLaunch.clear()
	quit(0 if _problems.is_empty() else 1)

var _problems: Array = []
func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: _problems.append(what)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _settle() -> void:
	for i in 900:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join("%s_%s.png" % [prefix, n])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

func _park_mouse() -> void:
	_move(Vector2(root.get_visible_rect().size.x / 2.0, 300))

func _move(p: Vector2) -> void:
	root.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	ev.position = p * Vector2(root.size) / root.get_visible_rect().size
	ev.global_position = ev.position
	Input.parse_input_event(ev)

func _tiles_for(tower_id: String, n: int) -> Array:
	return _tiles_for_player(ME, tower_id, n)

## Free tiles where that player's tower could go (ignoring whose turn it is), nearest the road first.
func _tiles_for_player(_player: String, tower_id: String, n: int) -> Array:
	var s := level.session
	var path: Array = s.state.grid.paths[0].tiles if s.state.grid.paths.size() > 0 else []
	var options := []
	for x in s.state.grid.width:
		for y in s.state.grid.height:
			var p := Vector2i(x, y)
			var keep := s.energy
			s.energy = 999
			var ok := s.can_place(tower_id, p)
			s.energy = keep
			if not ok: continue
			var best := 999
			for t in path: best = mini(best, absi(t.x - p.x) + absi(t.y - p.y))
			options.append([best, -y, x, p])
	options.sort()
	var out := []
	for o in options:
		if out.size() >= n: break
		out.append(o[3])
	return out
