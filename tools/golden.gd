extends SceneTree
## Replays the golden policy (see ~/godot/oracle/Golden.cs) on the GDScript port and writes
## user-independent logs to /home/ubuntu/godot/golden-gd/<level id>.log, then diffs them against
## /home/ubuntu/godot/golden/<id>.log (the C# oracle). Run: godot --headless --path . -s tools/golden.gd [-- id]
## Policy per player phase: place every unplaced hand tower (hand order) on the first free build tile
## (scan y then x) it can afford; then for every commanded unit (session order) and every non-movement
## ability in definition order, quick-cast once if can_cast and the instinct finds an aim; then end_round.
## Stops when the level is over or after 40 rounds. Seed 12345. Hand = every tower type by id, "t-<id>".

const OUT := "/home/ubuntu/godot/golden-gd"
const REF := "/home/ubuntu/godot/golden"
## The content golden plays: the frozen snapshot of the Unity content the C# oracle recorded with (plural keys,
## the 12×5 tutorial, no Workshop/missions), NOT res://data/content, which has moved on. A sim-vs-C# regression
## check on fixed content; see ~/godot/oracle/README.md and docs/Implementation Notes.md "Golden".
const CONTENT := "/home/ubuntu/godot/oracle/content"

func _initialize() -> void:
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: only = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	if not DirAccess.dir_exists_absolute(CONTENT):
		print("no oracle content snapshot at " + CONTENT)
		quit(1)
		return
	var lib = ContentLibrary.load(CONTENT)
	if lib.problems.size() > 0:
		for p in lib.problems: print("PROBLEM " + str(p))
	var convert = AssetConverter.new()
	var rules = convert.rules(lib.rules)
	var levels: Array = lib.all_of("LevelAsset")
	levels.sort_custom(func(a, b): return a.id < b.id)
	var tower_assets: Array = lib.all_of("TowerAsset")
	tower_assets.sort_custom(func(a, b): return a.id < b.id)
	var summary: Array[String] = []
	var same := 0
	for level_asset in levels:
		if only != "" and level_asset.id != only: continue
		var level = convert.level(level_asset)
		var hand: Array = []
		for t in tower_assets: hand.append(convert.tower(t, "t-" + t.id))
		if level_asset.fixed_hand != null and level_asset.fixed_hand.size() > 0:
			hand = []
			for i in level_asset.fixed_hand.size(): hand.append(convert.tower(level_asset.fixed_hand[i], "fixed-" + str(i)))
		var s = LevelSession.new(level, rules, hand, 12345)
		s.start()
		var rounds := 0
		while not s.is_over and rounds < 40:
			rounds += 1
			for t in s.hand:
				if s.placed.has(t.id): continue
				var tile = null
				for y in s.state.grid.height:
					if tile != null: break
					for x in s.state.grid.width:
						if s.can_place(t.id, Vector2i(x, y)):
							tile = Vector2i(x, y); break
				if tile != null: s.place(t.id, tile)
				if s.is_over: break
			if s.is_over: break
			for unit in s.player_units:
				if not unit.alive: continue
				for ability in unit.abilities.duplicate():
					if ability.targeting.is_movement: continue
					if not s.can_cast(unit, ability): continue
					var aim = Instinct.quick_cast(s.state, unit, ability)
					if aim == null: continue
					s.cast(unit, ability, aim)
					if s.is_over: break
				if s.is_over: break
			if s.is_over: break
			s.end_round()
		var id: String = level_asset.id
		var text: String = s.log.dump(s.state) + "\n"
		var f := FileAccess.open(OUT.path_join(id + ".log"), FileAccess.WRITE)
		f.store_string(text); f.close()
		var ref := FileAccess.get_file_as_string(REF.path_join(id + ".log"))
		var ok := ref == text
		if ok: same += 1
		var line := "%s: %s round %d energy %d events %d  %s" % [id, Outcome.name_of(s.outcome), s.round, s.energy, s.log.events.size(), "SAME" if ok else "DIFF (first diff line %d)" % _first_diff(ref, text)]
		print(line)
		summary.append(line)
	print("---- %d/%d levels identical to the C# oracle" % [same, summary.size()])
	quit(0 if same == summary.size() else 1)

func _first_diff(a: String, b: String) -> int:
	var la := a.split("\n"); var lb := b.split("\n")
	for i in mini(la.size(), lb.size()):
		if la[i] != lb[i]: return i + 1
	return mini(la.size(), lb.size()) + 1
