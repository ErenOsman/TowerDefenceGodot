extends SceneTree
## Renders review scenarios of the level scene (PNGs), beside tools/level_shot.gd:
##   ~/godot/run.sh projects/td [--resolution 1280x720] -s tools/level_scenes.gd -- <scenario> <out dir> [prefix]
## Scenarios:
##   spitters  — Spitters: an enemy that walks 2+ tiles and attacks a tower, hovered (path, stop, red line, damage)
##   statuses  — First Steps: an archer with Burn (3 stacks, timed), Shield and Haste: compact, then hovered + selected
##   tutorial  — the tutorial's intro run to its first line pointing at the board (ring and dim)
##   defeat    — First Steps with no towers, played to the end: the board as the end window opens
## The save is pointed at user://level_scenes.json (the real save is untouched).

var scenario := "spitters"
var out_dir := "user://shots"
var prefix := "scene"
var level: LevelController

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: scenario = args[0]
	if args.size() > 1: out_dir = args[1]
	if args.size() > 2: prefix = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	var sd = root.get_node_or_null("SaveData")
	if sd != null:
		sd.path = "user://level_scenes.json"
		sd.data = GameData.new()
		if scenario != "tutorial": sd.data.profile.create("Tester")
	match scenario:
		"spitters": await _spitters()
		"statuses": await _statuses()
		"tutorial": await _tutorial()
		"defeat": await _defeat()
		_: print("unknown scenario ", scenario)
	quit(0)

func _open(level_id: String, hand: Array) -> void:
	var scene: PackedScene = load("res://game/level/level.tscn")
	level = scene.instantiate()
	level.test_level_id = level_id
	level.test_hand = PackedStringArray(hand)
	level.instant_override = false
	root.add_child(level)
	await _frames(4)
	if level.setup_error != null: print("SETUP ERROR: ", level.setup_error)

# ------------------------------------------------------------------ scenarios

func _spitters() -> void:
	await _open("chapter1-2", ["archer"])
	level.skip_sequence()
	await _settle()
	var s := level.session
	var tiles := _build_tiles_near_path(s.hand.size(), 1)
	print("towers on ", tiles)
	for i in tiles.size():
		level.toggle_placing(s.hand[i].id)
		level.click_tile(tiles[i])
		await _settle()
	var found: Entity = null
	var score := 0
	for r in 16:
		var pick := _best_attacker()
		if pick[1] > score:
			found = pick[0]
			score = pick[1]
		if score >= 4 or (score >= 3 and r >= 6): break
		if found != null and r >= 14: break
		if score < 3:
			found = null
			score = 0
		level.instant_override = true
		level.end_round()
		await _settle()
		level.instant_override = false
		if s.is_over: break
	await _frames(3)
	if found == null:
		print("no enemy walking 2+ tiles and attacking found; round ", s.round)
		await _shot("spitters_none")
		return
	print("score ", score, " hovering ", found.name, " at ", found.pos, " round ", s.round)
	level.hover_override = found.pos
	await _frames(6)
	await _shot("spitters_hover")

## An enemy whose coming turn walks 2+ tiles and then attacks one of your units.
## The enemy whose coming turn shows the most: a walk then a shot at one of your units (Projectile) scores
## highest, a 2-tile walk more than one. [entity or null, score].
func _best_attacker() -> Array:
	var s := level.session
	var best: Entity = null
	var best_score := 0
	for e in s.enemies:
		var steps: Array = level._forecast_of(e)
		var walked := 0
		var hits := false
		var shot := false
		for st in steps:
			if st.is_movement: walked = maxi(walked, st.aim.path.size() if st.aim.path != null else 1)
			else:
				for id in st.preview.targets:
					if s.is_commanded(s.state.get_entity(id)):
						hits = true
						shot = shot or st.ability.tags.has(Tags.Projectile)
		if not hits or walked == 0: continue
		var score := (2 if shot else 0) + mini(walked, 2)
		if score > best_score:
			best = e
			best_score = score
	return [best, best_score]

func _statuses() -> void:
	await _open("chapter1-1", ["archer", "archer"])
	level.skip_sequence()
	await _settle()
	var s := level.session
	var tiles := _build_tiles_near_path(1)
	level.toggle_placing(s.hand[0].id)
	level.click_tile(tiles[0])
	await _settle()
	var unit: Entity = s.placed_tower(s.hand[0].id)
	var app = root.get_node_or_null("GameApp")
	var lib: ContentLibrary = app.lib if app != null else ContentLibrary.load("res://data/content")
	for spec in [["burn", "3", "3"], ["shield", "2", ""], ["haste", "1", "2"]]:
		var asset: StatusAsset = null
		for a in lib.all_of("StatusAsset"):
			if a.get_id().to_lower() == spec[0] or a.name.get_file().to_lower() == spec[0]: asset = a
		if asset == null:
			print("no status ", spec[0])
			continue
		var fx := ApplyStatusEffect.new()
		fx.status = level.converter.status(asset)
		fx.stacks = Formula.new(spec[1])
		if spec[2] != "": fx.duration = Formula.new(spec[2])
		fx.target_id = unit.id
		fx.source = 0
		s.resolver.run(fx)
	await _settle()
	var f: EntityFrame = level.shown.get_frame(unit.id)
	var names := []
	for st in f.statuses: names.append("%s x%d (%d turns, shield %d)" % [st.name, st.stacks, st.turns_left, st.shield])
	print("statuses on ", unit.name, ": ", names)
	level.hover_override = Vector2i(-9, -9)
	await _frames(4)
	await _shot("statuses_compact")
	level.select(unit.id)
	level.hover_override = unit.pos
	await _frames(6)
	await _shot("statuses_full")

func _tutorial() -> void:
	await _open("tutorial", ["archer"])
	await _frames(6)
	var s := level.session
	for i in 20:
		var run := level.sequence
		if run == null: break
		var line := run.current
		if line == null: break
		var board_target := line.point_at in [SequencePointAt.FirstEnemy, SequencePointAt.FirstTower, SequencePointAt.Tile, SequencePointAt.Subject, SequencePointAt.Speaker]
		if board_target and level.sequence_target_screen(line, true) != null:
			print("line %d points at %s: %s" % [run.index, SequencePointAt.name_of(line.point_at), line.text])
			await _frames(20)
			await _shot("tutorial_pointing")
			return
		# play the step the line asks for
		if line.continue_on == SequenceContinue.Click: level.continue_sequence()
		elif line.wait_for == SequenceEvent.TowerPlaced:
			var tiles := _build_tiles_near_path(1)
			level.toggle_placing(s.hand[0].id)
			level.click_tile(tiles[0])
		elif line.wait_for == SequenceEvent.SelectionCleared:
			level.select(-1)
		elif line.wait_for == SequenceEvent.RoundEnded:
			level.end_round()
		else:
			level.instant_override = true
			level.end_round()
		await _settle()
		level.instant_override = false
		await _frames(3)
	print("no line pointing at the board")
	await _shot("tutorial_none")

func _defeat() -> void:
	await _open("chapter1-1", ["archer"])
	level.skip_sequence()
	await _settle()
	level.instant_override = true
	var ended := [false]
	level.level_ended.connect(func(_o): ended[0] = true)
	for r in 40:
		if level.session.is_over: break
		level.end_round()
		await _settle()
	level.instant_override = false
	for i in 120:
		if ended[0]: break
		await process_frame
	await _frames(10)
	print("outcome ", Outcome.name_of(level.session.outcome), " ended ", ended[0], " waves ", level.waves_finished, "/", level.waves_total,
		" banner '", level.overlay.banners.text, "' floaters ", level.overlay.floaters.live_texts())
	await _shot("defeat_end")

# ------------------------------------------------------------------ helpers

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

func _build_tiles_near_path(n: int, at_least: int = 0) -> Array:
	var s := level.session
	var path: Array = s.state.grid.paths[0].tiles if s.state.grid.paths.size() > 0 else []
	var options := []
	for x in s.state.grid.width:
		for y in s.state.grid.height:
			var p := Vector2i(x, y)
			if not s.can_place(s.hand[0].id, p): continue
			var best := 999
			for t in path: best = mini(best, absi(t.x - p.x) + absi(t.y - p.y))
			if best < at_least: continue
			options.append([best, -y, x, p])
	options.sort()
	var out := []
	for o in options:
		if out.size() >= n: break
		out.append(o[3])
	return out
