class_name AssetValidator
extends RefCounted
## Validates assets with the formula Validator, plus what only assets know: chain-variable order
## (a step may read only what an earlier step of the same chain produces), the facts each
## reaction trigger provides, missing references and counts below their minimum.
## C# overloads Validate(asset, vocab) are one validate_asset(asset, vocab) here (plus the typed
## validate_ability/validate_status/… it dispatches to); validate(assets, vocab) checks a list.

const _ALL := SubjectNeeds.Source | SubjectNeeds.Target | SubjectNeeds.Self

## Every problem of the assets (any other objects are skipped).
static func validate(assets: Array, vocab: Vocabulary) -> Array[String]:
	var errors: Array[String] = []
	for asset in assets:
		errors.append_array(validate_asset(asset, vocab))
	return errors

## One asset's problems (C# Validate(XAsset …) overloads); [] for objects it does not check.
static func validate_asset(asset, vocab: Vocabulary = null) -> Array[String]:
	if asset is AbilityAsset: return validate_ability(asset, vocab)
	if asset is StatusAsset: return validate_status(asset, vocab)
	if asset is ReactionAsset: return validate_reaction(asset, vocab)
	if asset is PassiveAsset: return validate_passive(asset, vocab)
	if asset is GameRulesAsset: return validate_rules(asset, vocab)
	if asset is EntityAsset: return validate_entity(asset, vocab)
	if asset is ItemAsset: return validate_item(asset, vocab)
	if asset is TowerAsset: return validate_tower(asset)
	if asset is LevelAsset: return validate_level(asset)
	if asset is GameCatalogAsset: return validate_catalog(asset)
	if asset is FormAsset: return validate_form(asset)
	if asset is TokenAsset: return validate_token(asset)
	if asset is MissionAsset: return validate_mission(asset)
	var none: Array[String] = []
	return none

## What players would miss, as warnings that never block play: an id (rules and saves would use
## the asset name), a display name and description, and an icon on what the HUD shows (abilities,
## towers, statuses that are not Hidden).
static func warnings(asset) -> Array[String]:
	var w: Array[String] = []
	var check := func(missing: bool, what: String) -> void:
		if missing: w.append("%s: no %s" % [asset.name, what])
	if asset is AbilityAsset:
		check.call(asset.id.is_empty(), "id (rules use the asset name, which breaks on rename)")
		check.call(asset.display_name.is_empty(), "display name")
		check.call(asset.description.is_empty(), "description")
		check.call(asset.icon.is_empty(), "icon")
	elif asset is StatusAsset:
		check.call(asset.id.is_empty(), "id (rules use the asset name, which breaks on rename)")
		check.call(asset.display_name.is_empty(), "display name")
		check.call(asset.description.is_empty(), "description")
		check.call(asset.icon.is_empty() and not asset.tags.has(Tags.Hidden), "icon")
	elif asset is EntityAsset:
		check.call(asset.id.is_empty(), "id (the asset name is used, which breaks on rename)")
		check.call(asset.display_name.is_empty(), "display name")
		check.call(asset.description.is_empty(), "description")
	elif asset is LevelAsset:
		check.call(asset.id.is_empty(), "id (progress would use the asset name, which breaks on rename)")
		check.call(asset.display_name.is_empty(), "display name")
		check.call(asset.description.is_empty(), "description")
	elif asset is TowerAsset:
		check.call(asset.display_name.is_empty() and (asset.entity == null or asset.entity.display_name.is_empty()), "display name (on the tower or its entity)")
		check.call(asset.description.is_empty(), "description")
		check.call(asset.icon.is_empty(), "icon")
	elif asset is MissionAsset:
		check.call(asset.display_name.is_empty(), "display name")
		check.call(asset.description.is_empty(), "description")
	elif asset is FormAsset or asset is TokenAsset:
		check.call(asset.display_name.is_empty(), "display name")
		check.call(asset.description.is_empty(), "description")
		check.call(asset.icon.is_empty(), "icon")
	return w

## The deepest a form may sit (Workshop — Design § Validation: root + 2 levels).
const MaxFormDepth := 2

## A tower form (Workshop — Design § Validation): its id, tower, entity (a Unit standing OffPath), parent (a form of
## the same tower, no cycles, depth ≤ MaxFormDepth) and unlock cost (at least one token; tokens exist; amounts > 0).
## Godot-first (not in the C# yet).
static func validate_form(f: FormAsset) -> Array[String]:
	var errors: Array[String] = []
	var error := func(message: String) -> void: errors.append("%s: %s" % [f.name, message])
	if f.id.is_empty(): error.call("has no form ID (saves would refer to the asset name, which breaks on rename)")
	if f.tower == null: error.call("has no tower")
	if f.entity == null: error.call("has no entity")
	else:
		if f.entity.kind != EntityKind.Unit: error.call("its entity should be a Unit")
		if f.entity.footing != Footing.OffPath: error.call("its entity's footing should be OffPath (towers never stand on a path)")
	if f.parent != null and f.parent.tower != f.tower: error.call("its parent %s is a form of another tower" % f.parent.name)
	var depth := 1
	var p := f.parent
	var seen := {f: true}
	while p != null:
		if seen.has(p):
			error.call("its parents make a cycle")
			break
		seen[p] = true
		depth += 1
		p = p.parent
	if depth > MaxFormDepth and not errors.any(func(e): return e.contains("cycle")):
		error.call("sits %d deep; forms may only be %d deep for now" % [depth, MaxFormDepth])
	var total := 0
	for i in f.unlock.size():
		var u = f.unlock[i]
		if u == null or u.token == null: error.call("unlock[%d] has no token" % i)
		elif u.amount <= 0: error.call("unlock[%d] needs a positive amount" % i)
		else: total += u.amount
	if total == 0: error.call("costs no tokens (only the default form is free)")
	return errors

## A token kind: its id.
static func validate_token(t: TokenAsset) -> Array[String]:
	var errors: Array[String] = []
	if t.id.is_empty(): errors.append("%s: has no token ID (saves would refer to the asset name, which breaks on rename)" % t.name)
	return errors

## The most players a co-op mission may have (the relay's room count limit).
const MaxPlayers := 6

## A mission (Missions & Guild — Design § Validation): its id, its level, playsPerDay ≥ 1, a co-op mission's player
## range within 1–MaxPlayers and coopHandCap ≥ 1, its requirements (levels or missions, no empty entries, no cycle
## through other missions' requirements) and its drops (a token each, positive amounts). Godot-first.
static func validate_mission(m: MissionAsset) -> Array[String]:
	var errors: Array[String] = []
	var error := func(message: String) -> void: errors.append("%s: %s" % [m.name, message])
	if m.id.is_empty(): error.call("has no mission ID (saves would refer to the asset name, which breaks on rename)")
	if m.level == null: error.call("has no level")
	if m.plays_per_day < 1: error.call("playsPerDay must be at least 1")
	if m.mode == MissionMode.Coop or m.mode == MissionMode.Any:
		var lo := m.players.min if m.players != null else 1
		var hi := m.players.max if m.players != null else 1
		if lo < 1 or hi > MaxPlayers or lo > hi: error.call("players %d–%d must be within 1–%d (min ≤ max)" % [lo, hi, MaxPlayers])
		if m.mode == MissionMode.Coop and hi < 2: error.call("a Co-op mission needs room for 2 players (max ≥ 2)")
		if m.coop_hand_cap < 1: error.call("coopHandCap must be at least 1")
	for i in m.requires.size():
		var r = m.requires[i]
		if r == null: error.call("requires[%d] is empty" % i)
		elif not (r is LevelAsset or r is MissionAsset): error.call("requires[%d] is not a level or a mission" % i)
		elif r == m: error.call("requires itself")
	# a cycle through other missions' requirements
	var stack := [m]
	var seen := {}
	var cycle := false
	while not stack.is_empty() and not cycle:
		var cur = stack.pop_back()
		for r in cur.requires:
			if not (r is MissionAsset): continue
			if r == m and cur != m: cycle = true
			if not seen.has(r):
				seen[r] = true
				stack.append(r)
	if cycle: error.call("its requirements make a cycle")
	for list_name in ["firstWinTokens", "winTokens"]:
		var list: Array = m.first_win_tokens if list_name == "firstWinTokens" else m.win_tokens
		for i in list.size():
			var u = list[i]
			if u == null or u.token == null: error.call("%s[%d] has no token" % [list_name, i])
			elif u.amount <= 0: error.call("%s[%d] needs a positive amount" % [list_name, i])
	return errors

static func validate_ability(a: AbilityAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(a.name, vocab)
	v.condition(a.cast_gate, ContextSpec.CastGate, "castGate")
	v.pattern(a.targeting, "targeting")
	v.condition(a.target_filter, ContextSpec.TargetFilter, "targetFilter")
	v.instinct(a.instinct, "instinct")
	if a.cooldown_until_reset and a.cooldown > 1:
		v.error("cooldown", "is ignored: Cooldown Until Reset is on (set it to 1)")
	if a.instinct != null and a.instinct.preset == InstinctPreset.Engage and (a.targeting == null or not a.targeting.is_movement):
		v.error("instinct", "Engage is for movement abilities (it plans the walk for the attack after it)")
	v.steps(a.steps, "steps", {}, false)
	return v.errors

static func validate_status(s: StatusAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(s.name, vocab)
	v.modifiers(s.modifiers, "modifiers")
	v.replacements(s.replacements, "replacements")
	v.condition(s.passive_condition, ContextSpec.Passive, "passiveCondition")
	v.condition(s.aura, ContextSpec.TargetFilter, "aura")
	if not _empty(s.shield_pool): v.formula(s.shield_pool, ContextSpec.OnHit.with("Stacks"), "shieldPool") # Stacks: the stacks the application gives
	if s.reactions != null and s.reactions.has(null): v.error("reactions", "has an empty entry")
	return v.errors

static func validate_reaction(r: ReactionAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(r.name, vocab)
	var facts: Array = facts_of(r.trigger).duplicate()
	facts.append("StatusStacks")
	v.condition(r.condition, ContextSpec.ReactionTrigger.with(facts), "condition")
	v.formula(r.chance, ContextSpec.new("Chance", _ALL, ValueKind.Number, true, facts), "chance")
	var produced := {}
	for f in facts: produced[f] = true
	v.steps(r.response, "response", produced, false)
	return v.errors

static func validate_passive(p: PassiveAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(p.name, vocab)
	v.condition(p.condition, ContextSpec.Passive, "condition")
	v.condition(p.off_condition, ContextSpec.Passive, "offCondition")
	v.modifiers(p.modifiers, "modifiers")
	v.replacements(p.replacements, "replacements")
	v.condition(p.aura, ContextSpec.TargetFilter, "aura")
	return v.errors

static func validate_entity(e: EntityAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(e.name, vocab)
	if e.kind == EntityKind.Environment_: v.error("kind", "Environment is reserved for the battle's Environment entity")
	var seen := {}
	if e.stats != null:
		for i in e.stats.size():
			var s: StatValue = e.stats[i]
			if s == null: continue
			var p := "stats[%d]" % i
			if s.stat.is_empty():
				v.error(p, "has no stat name")
				continue
			if not vocab.is_stat(s.stat): v.error(p, "'%s' is not a registered stat" % s.stat)
			if seen.has(s.stat): v.error(p, "'%s' is listed twice" % s.stat)
			seen[s.stat] = true
			if AssetConverter.try_parse(s.value) == null: v.error(p, "'%s' is not a number" % s.value)
	if e.kind == EntityKind.Unit and not seen.has("MaxHp"): v.error("stats", "a Unit needs MaxHp")
	if e.abilities != null and e.abilities.has(null): v.error("abilities", "has an empty entry")
	if e.passives != null and e.passives.has(null): v.error("passives", "has an empty entry")
	return v.errors

static func validate_tower(t: TowerAsset) -> Array[String]:
	var errors: Array[String] = []
	if t.id.is_empty(): errors.append("%s: has no type ID (saves would refer to the asset name, which breaks on rename)" % t.name)
	if t.entity == null: errors.append("%s: has no entity" % t.name)
	else:
		if t.entity.kind != EntityKind.Unit: errors.append("%s: its entity should be a Unit" % t.name)
		if t.entity.footing != Footing.OffPath: errors.append("%s: its entity's footing should be OffPath (towers never stand on a path)" % t.name)
	return errors

## The game catalog: empty entries, levels without an id or listed twice, broken requirements
## and unreachable levels (LevelCatalog.problems), duplicate tower type ids, starting towers
## whose type is not listed.
static func validate_catalog(c: GameCatalogAsset) -> Array[String]:
	var errors: Array[String] = []
	var error := func(message: String) -> void: errors.append("%s: %s" % [c.name, message])

	if c.chapters == null or c.chapters.is_empty(): error.call("has no chapters")
	for e in c.entries():
		var data: CatalogLevelData = e[0]
		if data.level == null:
			error.call("chapter %d has an empty level entry" % (e[1] + 1))
			continue
		if data.requirement == RequirementKind.Levels and data.requires != null and data.requires.has(null):
			error.call("%s: has an empty required level" % data.level.get_id())
	for problem in c.to_catalog().problems(): error.call(problem)

	var type_ids := {}
	for t in c.tower_types:
		if t == null:
			error.call("towerTypes has an empty entry")
			continue
		if type_ids.has(t.get_id()): error.call("tower type ID '%s' is listed twice" % t.get_id())
		type_ids[t.get_id()] = true
	for t in c.starting_towers:
		if t != null and not type_ids.has(t.get_id()): error.call("starting tower %s is not in towerTypes (saves could not find it)" % t.name)
	for e in c.entries():
		var data: CatalogLevelData = e[0]
		if data.level != null and data.first_clear_reward != null and not type_ids.has(data.first_clear_reward.get_id()):
			error.call("%s: its first-clear reward %s is not in towerTypes (saves could not find it)" % [data.level.get_id(), data.first_clear_reward.name])
	# Missions & Guild (Godot-first): the guild unlock is a catalog level; the board's missions are listed once
	if c.guild_unlock != null and c.find_level(c.guild_unlock.get_id()) == null:
		error.call("guildUnlock %s is not a level of the chapters" % c.guild_unlock.get_id())
	var mission_ids := {}
	for i in c.missions.size():
		var m = c.missions[i]
		if m == null:
			error.call("missions[%d] is empty" % i)
			continue
		if mission_ids.has(m.get_id()): error.call("mission '%s' is listed twice" % m.get_id())
		mission_ids[m.get_id()] = true
	var starting := 0
	for t in c.starting_towers:
		if t != null: starting += 1
	if starting > TowerCollection.MaxHand:
		error.call("more than %d starting towers: only the first %d go in the hand" % [TowerCollection.MaxHand, TowerCollection.MaxHand])
	return errors

## Checks the map, paths, bases and wave schedule. Duplicate tower IDs are checked by Validate All.
static func validate_level(l: LevelAsset) -> Array[String]:
	var errors: Array[String] = []
	var error := func(path: String, message: String) -> void: errors.append("%s: %s: %s" % [l.name, path, message])

	var size := l.size
	var width := size.x
	var height := size.y
	if width == 0 or height == 0: error.call("map", "is empty")
	var is_inside := func(v: Vector2i) -> bool: return v.x >= 0 and v.y >= 0 and v.x < width and v.y < height

	# the three layers: the same size, every terrain character named, only known build and road characters
	var same_size := func(layer: Array, layer_name: String) -> void:
		if layer == null or layer.is_empty():
			error.call(layer_name, "is empty")
			return
		if layer.size() != height: error.call(layer_name, "has %d rows; the terrain layer has %d" % [layer.size(), height])
		for r in layer.size():
			var n: int = layer[r].length() if layer[r] != null else 0
			if n != width: error.call("%s[%d]" % [layer_name, r], "is %d characters long; the map is %d wide" % [n, width])
	same_size.call(l.terrain, "terrain")
	same_size.call(l.build, "build")
	same_size.call(l.road, "road")

	var keys := {}
	for i in l.terrain_keys.size():
		var k: TerrainKey = l.terrain_keys[i]
		if k == null: continue
		if k.symbol.length() != 1: error.call("terrainKeys[%d]" % i, "the symbol must be one character")
		elif keys.has(k.symbol[0]): error.call("terrainKeys[%d]" % i, "'%s' is named twice" % k.symbol)
		else: keys[k.symbol[0]] = true
		if k.terrain == null: error.call("terrainKeys[%d]" % i, "'%s' names no Terrain asset" % k.symbol)
	var unnamed := {}
	for x in width:
		for y in height:
			var c := l.terrain_char_at(x, y)
			if not keys.has(c) and not unnamed.has(c):
				unnamed[c] = true
				error.call("terrain", "'%s' (first at (%d, %d)) is not in Terrain Keys" % [c, x, y])
			var b := LevelAsset.char_at(l.build, x, y, ".")
			if b != "." and b != LevelAsset.Buildable: error.call("build", "(%d, %d) is '%s': use '+' (build) or '.'" % [x, y, b])
			elif b == LevelAsset.Buildable and l.standing_at(x, y) != Standing.Everyone: error.call("build", "(%d, %d) is buildable, but not everyone stands on %s" % [x, y, l.terrain_name_at(x, y)])
			var r := LevelAsset.char_at(l.road, x, y, LevelAsset.NoRoad)
			if LevelAsset.sides_of(r) == null: error.call("road", "(%d, %d) is '%s', not a road character (─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ ╴ ╶ ╵ ╷ • or '.')" % [x, y, r])

	if l.paths == null or l.paths.is_empty(): error.call("paths", "a level needs at least one path")
	else:
		for p in l.paths.size():
			var tiles := l.tiles_of(p)
			if tiles.is_empty():
				error.call("paths[%d]" % p, "has no tiles")
				continue
			for i in tiles.size():
				var t: Vector2i = tiles[i]
				var where := "paths[%d][%d]" % [p, i]
				if not is_inside.call(t):
					error.call(where, "%s is outside the map" % t)
					continue
				if l.standing_at(t.x, t.y) == Standing.Nobody: error.call(where, "%s is %s, where nobody stands" % [t, l.terrain_name_at(t.x, t.y)])
				elif l.build_at(t.x, t.y): error.call(where, "%s is marked buildable, but towers never stand on a path" % t)
				if i >= 2 and tiles[i] == tiles[i - 2] and LevelAsset.touch(tiles[i - 1], tiles[i]): error.call(where, "turns straight back to %s: a path loops round, never back on itself" % t)
				if i > 0 and t == tiles[i - 1]: error.call(where, "%s twice in a row" % t)
				# a step between neighbours runs along the road drawn on both tiles
				if i > 0 and is_inside.call(tiles[i - 1]) and LevelAsset.touch(tiles[i - 1], t):
					var a: Vector2i = tiles[i - 1]
					if not l.road_reaches(a.x, a.y, LevelAsset.side_of(t - a)) or not l.road_reaches(t.x, t.y, LevelAsset.side_of(a - t)):
						error.call(where, "the step %s → %s is not joined by the road layer" % [a, t])

	if l.bases == null or l.bases.is_empty(): error.call("bases", "a level needs at least one base")
	else:
		for b in l.bases.size():
			var data: BaseData = l.bases[b]
			if data == null: continue
			if data.entity == null: error.call("bases[%d]" % b, "has no entity")
			elif not data.entity.tags.has(Tags.Base): error.call("bases[%d]" % b, "its entity needs the %s tag" % Tags.Base)
			if not is_inside.call(data.tile): error.call("bases[%d]" % b, "%s is outside the map" % data.tile)

	var path_count := l.paths.size()
	var taken := {}
	for b in l.bases:
		if b != null: taken[b.tile] = true
	for u in l.starting_units.size():
		var data: StartingUnitData = l.starting_units[u]
		if data == null: continue
		var up := "startingUnits[%d]" % u
		if data.entity == null:
			error.call(up, "has no entity")
			continue
		if not is_inside.call(data.tile):
			error.call(up, "%s is outside the map" % data.tile)
			continue
		var stand := l.standing_at(data.tile.x, data.tile.y)
		var flies := data.entity.tags.has(Tags.Flying)
		if stand == Standing.Nobody or (stand == Standing.Flyers and not flies): error.call(up, "%s stands on %s at %s" % [data.entity.name, l.terrain_name_at(data.tile.x, data.tile.y), data.tile])
		if taken.has(data.tile): error.call(up, "%s is already taken by a base or another starting unit" % data.tile)
		taken[data.tile] = true
		var on_road := false
		for p in path_count:
			if l.tiles_of(p).has(data.tile): on_road = true
		if data.side == StartingSide.Enemy:
			if data.path >= path_count: error.call(up, "road %d does not exist" % (data.path + 1))
			elif (not l.tiles_of(data.path).has(data.tile)) if data.path >= 0 else not on_road: error.call(up, "an enemy must start on its road; %s is not on it" % data.tile)

	# a road over terrain only flyers stand on (a chasm): only flying enemies may be sent along it
	for p in path_count:
		var tiles := l.tiles_of(p)
		var over_chasm := false
		for t in tiles:
			if is_inside.call(t) and l.standing_at(t.x, t.y) == Standing.Flyers: over_chasm = true
		if not over_chasm: continue
		var walkers := []
		for w in l.waves:
			if w == null: continue
			for s in w.spawns:
				if s != null and s.enemy != null and s.path == p: walkers.append(s.enemy)
			for e in w.events:
				if e != null and e.kind == LevelEventKind.SpawnEnemies and e.enemy != null and e.path == p: walkers.append(e.enemy)
		for u in l.starting_units:
			if u != null and u.entity != null and u.side == StartingSide.Enemy and (u.path == p or (u.path < 0 and tiles.has(u.tile))): walkers.append(u.entity)
		var reported := {}
		for e in walkers:
			if reported.has(e): continue
			reported[e] = true
			if not e.tags.has(Tags.Flying): error.call("paths[%d]" % p, "crosses a chasm, but %s cannot fly (tag %s)" % [e.name, Tags.Flying])

	if l.waves == null or l.waves.is_empty(): error.call("waves", "a level needs at least one wave")
	else:
		for w in l.waves.size():
			var wave: WaveData = l.waves[w]
			if wave == null: continue
			var wp := "waves[%d]" % w
			if wave.start == WaveStart.AfterWave and (wave.after_wave < 0 or wave.after_wave >= l.waves.size() or wave.after_wave == w):
				error.call(wp, "afterWave must name another wave of this level")
			for s in wave.spawns.size():
				var sp: SpawnData = wave.spawns[s]
				if sp == null: continue
				if sp.enemy == null: error.call("%s.spawns[%d]" % [wp, s], "has no enemy")
				elif sp.enemy.footing != Footing.OnPath: error.call("%s.spawns[%d]" % [wp, s], "%s's footing should be OnPath" % sp.enemy.name)
				if sp.path < 0 or sp.path >= path_count: error.call("%s.spawns[%d]" % [wp, s], "path %d does not exist" % sp.path)
			for e in wave.events.size():
				var ev: LevelEventData = wave.events[e]
				var ep := "%s.events[%d]" % [wp, e]
				if ev != null and ev.kind == LevelEventKind.ChangeTerrain:
					if ev.terrain == null: error.call(ep, "has no terrain to change the tiles to")
					if ev.tiles == null or ev.tiles.is_empty(): error.call(ep, "has no tiles")
					else:
						for t in ev.tiles:
							if not is_inside.call(t): error.call(ep, "%s is outside the map" % t)
					continue
				if ev == null or ev.kind != LevelEventKind.SpawnEnemies: continue
				if ev.enemy == null: error.call(ep, "has no enemy")
				if ev.path >= path_count: error.call(ep, "path %d does not exist" % ev.path)
	return errors

static func validate_item(i: ItemAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(i.name, vocab)
	v.modifiers(i.modifiers, "modifiers")
	v.replacements(i.replacements, "replacements")
	if i.reactions != null and i.reactions.has(null): v.error("reactions", "has an empty entry")
	return v.errors

static func validate_rules(g: GameRulesAsset, vocab: Vocabulary) -> Array[String]:
	var v := Scope.new(g.name, vocab)
	v.formula(g.mana_regen, ContextSpec.Modifier, "manaRegen")
	v.formula(g.hit_chance, ContextSpec.OnHit, "hitChance")
	v.formula(g.crit_chance, ContextSpec.OnHit, "critChance")
	v.formula(g.crit_multiplier, ContextSpec.OnHit, "critMultiplier")
	v.formula(g.mitigation, ContextSpec.Mitigation, "mitigation")
	v.modifiers(g.modifiers, "modifiers")
	v.replacements(g.replacements, "replacements")
	for entry in g.library:
		if entry != null: v.formula(Formula.new(entry.expression), ContextSpec.Modifier, "library @%s" % entry.name)
	return v.errors

## The facts a trigger's event provides to conditions, chances and responses.
static func facts_of(t: int) -> Array:
	match t:
		Trigger.OnHitDealt, Trigger.OnHitTaken, Trigger.OnAllyHitTaken, Trigger.OnDodge:
			return ["Hit", "IsCrit", "Damage", "FinalDamage"]
		Trigger.OnDamageDealt, Trigger.OnDamageTaken:
			return ["Damage", "FinalDamage", "Absorbed", "HpLost", "Overkill"]
		Trigger.OnHealed:
			return ["Amount", "Overheal"]
		Trigger.OnStatusApplied, Trigger.OnStatusRemoved:
			return ["Stacks"]
		Trigger.OnTileChanged:
			return ["X", "Y"]
		Trigger.OnAttackStarted, Trigger.OnTargeted:
			return ["ActionPower"]
		Trigger.OnCollision:
			return ["TilesLeft"]
		Trigger.OnRoundStart, Trigger.OnRoundEnd:
			return ["Round"]
	return []

static func _empty(f) -> bool:
	return f == null or f.is_empty

# ------------------------------------------------------------------ walking

## One asset's checks: errors are "<asset>: <path>: <message>".
class Scope:
	var errors: Array[String] = []
	var _asset: String
	var _vocab: Vocabulary

	func _init(p_asset: String, p_vocab: Vocabulary) -> void:
		_asset = p_asset
		_vocab = p_vocab

	func error(path: String, message: String) -> void:
		errors.append("%s: %s: %s" % [_asset, path, message])

	## Must and every preference's formula and filter; Custom needs at least one preference.
	func instinct(d: InstinctDef, path: String) -> void:
		if d == null: return
		condition(d.must, ContextSpec.TargetFilter, path + ".must")
		if d.preset == InstinctPreset.Custom and (d.prefer == null or d.prefer.is_empty()):
			error(path, "is Custom but has no preferences")
		if d.prefer == null: return
		for i in d.prefer.size():
			var pr: Preference = d.prefer[i]
			var pp := "%s.prefer[%d]" % [path, i]
			if pr == null:
				error(pp, "is empty")
				continue
			if pr.over != PreferOver.AreaCount:
				if AssetValidator._empty(pr.value): error(pp, "has no formula")
				else: formula(pr.value, ContextSpec.Instinct, pp + ".value")
			condition(pr.filter, ContextSpec.TargetFilter, pp + ".filter")

	func formula(f, spec: ContextSpec, path: String) -> void:
		for e in Validator.validate(f.expression if f != null else "", spec, _vocab, path): errors.append("%s: %s" % [_asset, e])

	func condition(c, spec: ContextSpec, path: String) -> void:
		for e in Validator.validate(c.expression if c != null else "", spec, _vocab, path): errors.append("%s: %s" % [_asset, e])

	func pattern(p: PatternDef, path: String) -> void:
		if p == null or p.shape == Shape.Single or p.shape == Shape.Custom or p.shape == Shape.Ray: return # no radius
		formula(p.min_radius, ContextSpec.Targeting, path + ".minRadius")
		formula(p.max_radius, ContextSpec.Targeting, path + ".maxRadius")

	func modifiers(mods: Array, path: String) -> void:
		if mods == null: return
		for i in mods.size():
			if mods[i] == null: continue
			if mods[i].target == null or mods[i].target.is_empty(): error("%s[%d]" % [path, i], "has no target stat or variable")
			formula(mods[i].amount, ContextSpec.Modifier, "%s[%d].amount" % [path, i])

	func replacements(list: Array, path: String) -> void:
		if list == null: return
		for i in list.size():
			if list[i] == null: continue
			condition(list[i].condition, ContextSpec.Replacement, "%s[%d].condition" % [path, i])
			steps(list[i].instead, "%s[%d].instead" % [path, i], {}, false)

	## Walks steps in order; `produced` (a set {name: true}) grows as steps produce chain variables.
	func steps(list: StepList, path: String, produced: Dictionary, in_chain: bool) -> void:
		if list == null or list.items == null: return
		for i in list.items.size():
			var step = list.items[i]
			var p := "%s[%d]" % [path, i]
			if step == null:
				error(p, "is an empty step")
				continue
			p += " " + step.display_name
			# exactly the variables produced so far: Power only after an Attack, HpLost only after Damage…
			var on_hit := ContextSpec.new("OnHit", AssetValidator._ALL, ValueKind.Number, true, produced.keys())

			if step is AttackStepData:
				pattern(step.area, p + ".area")
				condition(step.area_filter, ContextSpec.TargetFilter, p + ".areaFilter")
				formula(step.power, ContextSpec.Attack, p + ".power")
				formula(step.hits, ContextSpec.Attack, p + ".hits")
				formula(step.bounces, ContextSpec.Attack, p + ".bounces")
				pattern(step.bounce_area, p + ".bounceArea")
				condition(step.bounce_filter, ContextSpec.TargetFilter, p + ".bounceFilter")
				instinct(step.bounce_instinct, p + ".bounceInstinct")
				_at_least(step.hits, 1, p + ".hits")
				_at_least(step.bounces, 0, p + ".bounces")
				var chain := produced.duplicate()
				chain["ActionPower"] = true
				if step.can_miss or step.can_crit:
					chain["Hit"] = true
					chain["IsCrit"] = true
				steps(step.on_hit, p + ".onHit", chain, true)
				produced["Power"] = true # later steps of the ability read the frozen Power
			elif step is DamageStepData:
				formula(step.amount, on_hit, p + ".amount")
				for v in ["Damage", "FinalDamage", "Absorbed", "HpLost", "Overkill"]: produced[v] = true
			elif step is HealStepData:
				formula(step.amount, on_hit, p + ".amount")
				for v in ["Amount", "Overheal"]: produced[v] = true
			elif step is ApplyStatusStepData:
				if step.status == null: error(p, "has no status")
				formula(step.stacks, on_hit, p + ".stacks")
			elif step is RemoveStatusStepData:
				if step.by == RemoveBy.Name and step.status == null: error(p, "has no status")
				if step.by == RemoveBy.Name and not AssetValidator._empty(step.stacks): formula(step.stacks, on_hit, p + ".stacks")
				if step.by == RemoveBy.Tag and step.tag.is_empty(): error(p, "has no tag")
				if step.by == RemoveBy.Tag and step.tag == Tags.Permanent: error(p, "cleansing Permanent removes nothing: Permanent statuses are skipped by tag removal")
			elif step is PushStepData:
				formula(step.distance, on_hit, p + ".distance")
			elif step is IfStepData:
				condition(step.condition, ContextSpec.new("Step", AssetValidator._ALL, ValueKind.Bool, false, produced.keys()), p + ".condition")
				steps(step.then, p + ".then", produced.duplicate(), in_chain)
				steps(step.otherwise, p + ".otherwise", produced.duplicate(), in_chain)
			elif step is CastAbilityStepData:
				if step.ability == null: error(p, "has no ability")
			elif step is AddCooldownStepData:
				formula(step.turns, on_hit, p + ".turns")
			elif step is ResetCooldownStepData:
				if not AssetValidator._empty(step.turns): formula(step.turns, on_hit, p + ".turns")
			elif step is PickStepData:
				pattern(step.area, p + ".area")
				condition(step.filter, ContextSpec.TargetFilter, p + ".filter")
				formula(step.count, ContextSpec.Attack, p + ".count")
				_at_least(step.count, 1, p + ".count")
				instinct(step.instinct, p + ".instinct")
				steps(step.steps, p + ".steps", produced.duplicate(), in_chain)
			elif step is SpawnStepData:
				if step.entity == null: error(p, "has no entity")
			elif step is ChangeTerrainStepData:
				if step.terrain == null: error(p, "has no terrain to change the tiles to")
			elif step is ResurrectStepData:
				formula(step.hp, on_hit, p + ".hp")
			elif step is AddScopedModifierStepData:
				if step.modifier == null or step.modifier.target == null or step.modifier.target.is_empty(): error(p, "modifier has no target")
				else: formula(step.modifier.amount, ContextSpec.Modifier, p + ".modifier.amount")

	## Counts must resolve to at least min; checked when the formula is a constant.
	func _at_least(f, minimum: int, path: String) -> void:
		if f == null: return
		var node = f.compile(_vocab) # null on a parse error: reported by formula()
		if node is ConstNode and node.value < minimum: error(path, "must be at least %d" % minimum)
