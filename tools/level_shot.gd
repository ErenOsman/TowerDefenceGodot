extends SceneTree
## Headless-render proof of the level scene: loads a level with a test hand, places two archers, plays rounds
## (Instant on to fast-forward), and saves PNGs at several moments: the board, placing, an ability aimed, a cast
## in flight, an enemy walking, an enemy hovered (its forecast).
##   ~/godot/run.sh projects/td -s tools/level_shot.gd -- <level id> <out dir> [prefix]
##   ~/godot/run.sh projects/td --resolution 1280x720 -s tools/level_shot.gd -- chapter1-1 /tmp/shots small
## The save is pointed at user://level_shot.json (the real save is untouched).

var level_id := "chapter1-1"
var out_dir := "user://shots"
var prefix := "shot"
var level: LevelController

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
		sd.path = "user://level_shot.json"
		sd.data = GameData.new()
		sd.data.profile.create("Tester")
		sd.data.settings.always_show_health = false
	var scene: PackedScene = load("res://game/level/level.tscn")
	level = scene.instantiate()
	level.test_level_id = level_id
	level.test_hand = PackedStringArray(["archer", "archer"])
	if OS.get_cmdline_user_args().has("drawn_plates"):
		level.ready.connect(func(): level.overlay.plates.make_plate = func(): return BoardPlate.new())
	level.instant_override = false
	root.add_child(level)
	await _frames(4)
	if level.setup_error != null:
		print("SETUP ERROR: ", level.setup_error)
		quit(1)
		return
	level.skip_sequence()
	# let the opening banners and spawns play
	await _settle()
	await _shot("1_board")
	if OS.get_cmdline_user_args().has("quick"):
		quit(0)
		return

	# placing: the build tiles light up
	var hand: Array = level.session.hand
	level.toggle_placing(hand[0].id)
	await _frames(3)
	await _shot("2_placing")
	var tiles := _build_tiles_near_path(2)
	print("placing on ", tiles)
	level.click_tile(tiles[0])
	await _settle()
	level.toggle_placing(hand[1].id)
	level.click_tile(tiles[1])
	await _settle()
	await _shot("3_placed")

	# fast-forward rounds with Instant on until an enemy is in an archer's range
	var archer: Entity = level.session.placed_tower(hand[0].id)
	var shoot: AbilityDef = null
	for a in archer.abilities:
		if not a.targeting.is_movement: shoot = a
	for i in 8:
		if _has_target(archer, shoot): break
		level.instant_override = true
		level.end_round()
		await _settle()
	level.instant_override = false
	await _frames(2)
	print("round ", level.session.round, " enemies ", level.session.enemies.size())

	# aim: range, valid targets, the attack line
	level.select(archer.id)
	level.toggle_aim(shoot)
	var aims: Array = Targeting.valid_aims(level.session.state, archer.id, shoot)
	if aims.size() > 0:
		_hover_tile(aims[0].tile)
	await _frames(4)
	await _shot("4_aiming")

	# a cast in flight: slow the game down so the frames catch the arrow
	Engine.time_scale = 0.2
	if aims.size() > 0:
		level.click_tile(aims[0].tile)
	else:
		level.quick_cast(shoot)
	for k in 10:
		await _frames(3)
		await _shot("5_cast_%d" % k)
	Engine.time_scale = 1.0
	await _settle()
	await _shot("6_after_cast")

	# the enemy phase at a slow speed: enemies walk along the road
	_hover_tile(Vector2i(-5, -5))
	level.select(-1)
	Engine.time_scale = 0.3
	level.end_round()
	for k in 8:
		await _frames(3)
		await _shot("7_enemy_%d" % k)
	Engine.time_scale = 1.0
	level.instant_override = true
	await _settle()
	level.instant_override = false
	await _frames(3)

	# hover an enemy: its coming turn (path, stop tile, attack line, the damage it would do)
	var enemies: Array = level.session.enemies
	if enemies.size() > 0:
		_hover_tile(enemies[0].pos)
		await _frames(5)
		await _shot("8_enemy_hover")
	# End turn hovered: no board marks, a threat line for the HUD
	level.preview_enemy_phase = true
	_hover_tile(Vector2i(-5, -5))
	await _frames(4)
	await _shot("9_enemy_phase_preview")
	print("threat summary: ", level.threat_summary)
	level.preview_enemy_phase = false
	# an enemy's ability row hovered in its card: only that ability's part of its turn
	if enemies.size() > 0:
		var foe: Entity = level.session.enemies[0]
		level.select(foe.id)
		for a in foe.abilities:
			if not a.targeting.is_movement:
				level.preview_ability(foe, a)
				break
		await _frames(4)
		await _shot("10_enemy_ability_row")
		level.preview_ability(null, null)
		level.select(-1)
	print("hint: ", level.hint, " | version ", level.version, " | over ", level.session.is_over)
	quit(0)

func _frames(n: int) -> void:
	for i in n: await process_frame

## Waits until nothing plays (up to ~10 s of frames).
func _settle() -> void:
	for i in 600:
		await process_frame
		if not level.director.busy: break
	await _frames(2)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join("%s_%s.png" % [prefix, n])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

## The first n free build tiles closest to the first path (Manhattan).
func _build_tiles_near_path(n: int) -> Array:
	var s := level.session
	var path: Array = s.state.grid.paths[0].tiles if s.state.grid.paths.size() > 0 else []
	var options := []
	for x in s.state.grid.width:
		for y in s.state.grid.height:
			var p := Vector2i(x, y)
			if not s.can_place(s.hand[0].id, p): continue
			var best := 999
			for t in path: best = mini(best, absi(t.x - p.x) + absi(t.y - p.y))
			options.append([best, -y, x, p])
	options.sort()
	var out := []
	for o in options:
		if out.size() >= n: break
		out.append(o[3])
	return out

func _has_target(unit: Entity, a: AbilityDef) -> bool:
	if a == null: return false
	for aim in Targeting.valid_aims(level.session.state, unit.id, a):
		var t: Entity = Instinct.target_of(level.session.state, a, aim)
		if t != null and level.session.enemies.has(t): return true
	return false

## Puts the pointer over a tile (warps the mouse to its screen point).
func _hover_tile(p: Vector2i) -> void:
	level.hover_override = p
	root.warp_mouse(level.camera.unproject_position(GridSpace.to_world(p)))
