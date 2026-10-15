extends SceneTree
## Real level flow: First Steps with a Mage only; cast Firebolt at the first slime in range once, then just end rounds
## and print every enemy's hp / shield / Burn stacks after each enemy turn.
func _initialize() -> void:
	var lib = ContentLibrary.load_game()
	var convert = AssetConverter.new()
	var rules = convert.rules(lib.rules)
	var level_asset = null
	for l in lib.all_of("LevelAsset"): if l.id == "chapter1-2": level_asset = l
	var level = convert.level(level_asset)
	var mage_asset = null
	for t in lib.all_of("TowerAsset"): if t.id == "mage": mage_asset = t
	var s = LevelSession.new(level, rules, [convert.tower(mage_asset, "t-mage")], 12345)
	s.start()
	var tile = null
	var road: Array = level.paths[0] if level.paths.size() > 0 else []
	var mid: Vector2i = road[int(road.size() / 2)] if road.size() > 0 else Vector2i.ZERO
	var best := 999
	for y in s.state.grid.height:
		for x in s.state.grid.width:
			var t := Vector2i(x, y)
			if not s.can_place("t-mage", t): continue
			var d: int = absi(t.x - mid.x) + absi(t.y - mid.y)
			if d < best: best = d; tile = t
	s.place("t-mage", tile)
	print("mage at %s" % tile)
	var burned := false
	for round in 14:
		var mage: Entity = s.player_units[0]
		if not burned:
			for ability in mage.abilities:
				if ability.name != "Firebolt" or not s.can_cast(mage, ability): continue
				var aim = Instinct.quick_cast(s.state, mage, ability)
				if aim != null:
					s.cast(mage, ability, aim); burned = true
					print("round %d: Firebolt cast" % s.round)
		var line := "round %d after player phase:" % s.round
		for e in s.enemies: if e.alive: line += " %s#%d@%s hp %s burn %s |" % [e.name, e.id, e.pos, e.hp, e.stacks("Burn")]
		print(line)
		s.end_round()
		if s.is_over: break
		line = "round %d start (enemy phase done):" % s.round
		for e in s.enemies: if e.alive: line += " %s#%d@%s hp %s burn %s |" % [e.name, e.id, e.pos, e.hp, e.stacks("Burn")]
		print(line)
	quit(0)
