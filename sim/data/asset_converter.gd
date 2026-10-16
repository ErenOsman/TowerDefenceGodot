class_name AssetConverter
extends RefCounted
## Converts assets into core definitions, once per asset. Each core object is cached before
## its fields are filled, so assets that reference each other (a status whose reaction
## re-applies it, an ability that casts itself) convert without infinite recursion.
## Use one converter per battle (or per load) so every reference resolves to the same object.

var _cache := {}   # asset → def
var _assets := {}  # def → asset

## The asset a core definition was built from (reverse lookup), e.g. an AbilityDef's AbilityAsset
## for its icon. Null for definitions this converter did not build, or (with type_name, C# AssetOf<T>)
## when the asset is not of that class.
func asset_of(def, type_name: String = ""):
	if def is EntityDef and not _assets.has(def) and def.levelled_from != null: return asset_of(def.levelled_from, type_name)
	if def == null or not _assets.has(def): return null
	var asset = _assets[def]
	if type_name != "" and not ContentSerializer.is_type(asset, type_name): return null
	return asset

## Every core definition of a class this converter has built (a level converts everything it references).
func built(type_name: String) -> Array:
	var result := []
	for def in _assets:
		if ContentSerializer.is_type(def, type_name): result.append(def)
	return result

func _remember(asset, def) -> void:
	_cache[asset] = def
	_assets[def] = asset

func ability(a: AbilityAsset) -> AbilityDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := AbilityDef.new()
	_remember(a, d)
	d.name = a.get_id()
	d.display_name = a.display_name
	d.description = a.description
	d.tags = _copy(a.tags)
	var costs := []
	for c in a.costs: costs.append(Cost.new(c.resource, c.amount)) # a struct array: copied by value
	d.costs = costs
	d.cast_gate = a.cast_gate
	d.targeting = a.targeting if a.targeting != null else PatternDef.self_()
	d.target_filter = a.target_filter
	d.targets_dead = a.targets_dead
	d.needs_free_tile = a.needs_free_tile
	d.cooldown = a.cooldown
	d.cooldown_until_reset = a.cooldown_until_reset
	d.start_cooldown = a.start_cooldown
	d.instinct = a.instinct if a.instinct != null else InstinctDef.new()
	d.steps = steps(a.steps)
	return d

func status(a: StatusAsset) -> StatusDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := StatusDef.new()
	_remember(a, d)
	d.name = a.get_id()
	d.display_name = a.display_name
	d.description = a.description
	d.tags = _copy(a.tags)
	d.stacking = a.stacking
	d.max_stacks = a.max_stacks
	d.duration = a.duration
	d.modifiers = a.modifiers.duplicate() if a.modifiers != null else []
	d.replacements = _replacements(a.replacements)
	d.reactions = _reactions(a.reactions)
	d.passive_condition = a.passive_condition
	d.duration_unit = a.duration_unit
	d.aura = a.aura
	d.shield_pool = a.shield_pool
	d.team_override = a.team_override
	d.fixed_team = a.fixed_team
	d.persists_through_death = a.persists_through_death
	return d

func reaction(a: ReactionAsset) -> ReactionDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := ReactionDef.new()
	_cache[a] = d
	d.name = a.name
	d.trigger = a.trigger
	d.condition = a.condition
	d.chance = a.chance
	d.roll_per = a.roll_per
	d.timing = a.timing
	d.limit = a.limit
	d.ignore_tags = _copy(a.ignore_tags)
	d.works_when_dead = a.works_when_dead
	d.response = steps(a.response)
	return d

func passive(a: PassiveAsset) -> PassiveDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := PassiveDef.new()
	_remember(a, d) # asset_of finds its icon
	d.name = a.name
	d.display_name = a.display_name
	d.description = a.description
	d.hidden = a.hidden
	d.condition = a.condition
	d.off_condition = a.off_condition
	d.modifiers = a.modifiers.duplicate() if a.modifiers != null else []
	d.replacements = _replacements(a.replacements)
	d.reactions = _reactions(a.reactions)
	d.aura = a.aura
	return d

func entity(a: EntityAsset) -> EntityDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := EntityDef.new()
	_remember(a, d)
	d.name = a.get_id()
	d.display_name = a.display_name
	d.description = a.description
	d.kind = a.kind
	d.tags = _copy(a.tags)
	d.blocks_projectiles = a.blocks_projectiles
	d.die_with_summoner = a.die_with_summoner
	d.footing = a.footing
	for s in a.stats:
		if s != null and not s.stat.is_empty():
			var v = try_parse(s.value)
			if v != null: d.base_stats[s.stat] = v
	for ab in a.abilities:
		if ab != null: d.abilities.append(ability(ab))
	for p in a.passives:
		if p != null: d.passives.append(passive(p))
	return d

func terrain(a: TerrainAsset) -> TerrainDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := TerrainDef.new()
	d.name = a.get_id()
	d.display_name = a.display_name
	d.description = a.description
	d.stand = a.stand
	d.blocks_projectiles = a.blocks_projectiles
	d.blocks_sight = a.blocks_sight
	d.tags = _copy(a.tags)
	d.when_unstandable = a.when_unstandable
	_remember(a, d) # asset_of finds its view
	return d

func item(a: ItemAsset) -> ItemDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := ItemDef.new()
	_cache[a] = d
	d.name = a.name
	d.modifiers = a.modifiers.duplicate() if a.modifiers != null else []
	d.replacements = _replacements(a.replacements)
	d.reactions = _reactions(a.reactions)
	return d

func tower_type(a: TowerAsset) -> TowerType:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := TowerType.new()
	d.id = a.get_id()
	d.name = a.get_display_name()
	d.description = a.description
	d.cost = a.cost
	_remember(a, d)
	d.entity = entity(a.entity)
	d.levels = tower_levels(a.levels)
	var forms := []
	for f in a.forms:
		if f != null: forms.append(form(f))
	d.forms = forms
	return d

## A level ladder (Upgrades — Design): Array of TowerLevelData → Array of TowerLevelDef (null entries skipped).
func tower_levels(list: Array) -> Array:
	var out := []
	for l in list:
		if l != null: out.append(tower_level(l))
	return out

## One level step: its tasks (TaskDef) and bonuses (Modifier: target = the stat, the kind, the amount as a constant
## formula). Not cached (a plain value object).
func tower_level(a: TowerLevelData) -> TowerLevelDef:
	if a == null: return null
	var d := TowerLevelDef.new()
	d.to = a.to
	for t in a.tasks:
		if t == null: continue
		var task := TaskDef.new()
		task.kind = t.kind
		task.count = t.count
		task.text = t.text
		task.currency = t.currency
		if t.mission != null:
			task.mission = t.mission.get_id()
			task.mission_name = t.mission.get_display_name()
		d.tasks.append(task)
	for b in a.bonuses:
		if b != null and not b.stat.is_empty(): d.bonuses.append(Modifier.new(b.stat, b.kind, b.amount))
	return d

## A tower form (Workshop — Design): its entity, cost, unlock cost and parent. (No C# counterpart.)
func form(a: FormAsset) -> FormDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := FormDef.new()
	_remember(a, d)
	d.id = a.get_id()
	d.name = a.get_display_name()
	d.description = a.description
	d.icon = a.icon
	d.badge = a.badge
	d.tower = a.tower.get_id() if a.tower != null else ""
	d.cost = a.cost
	d.order = a.order
	for u in a.unlock:
		if u == null or u.token == null: continue
		var t := token(u.token)
		d.unlock[t.id] = d.unlock.get(t.id, 0) + u.amount
		d.tokens[t.id] = t
	d.parent = form(a.parent)
	d.entity = entity(a.entity)
	d.levels = tower_levels(a.levels)
	return d

## A token kind (Workshop — Design).
func token(a: TokenAsset) -> TokenDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := TokenDef.new()
	_remember(a, d)
	d.id = a.get_id()
	d.name = a.get_display_name()
	d.description = a.description
	d.icon = a.icon
	d.rarity = a.rarity
	return d

## A mission (Missions & Guild — Design). (No C# counterpart.) Token amounts of the same kind add up;
## requires keep the ids of the levels / missions listed (empty entries skipped).
func mission(a: MissionAsset) -> MissionDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := MissionDef.new()
	_remember(a, d)
	d.id = a.get_id()
	d.name = a.get_display_name()
	d.description = a.description
	d.icon = a.icon
	d.level_id = a.level.get_id() if a.level != null else ""
	d.mode = a.mode
	if a.players != null:
		d.min_players = a.players.min
		d.max_players = a.players.max
	d.plays_per_day = a.plays_per_day
	var req := []
	for r in a.requires:
		if r != null and r.has_method("get_id"): req.append(r.get_id())
	d.requires = req
	d.require_all = a.require_all
	d.shared_pool = a.shared_pool
	d.coop_hand_cap = a.coop_hand_cap
	d.first_win_tokens = GameCatalogAsset._amounts(a.first_win_tokens)
	d.win_tokens = GameCatalogAsset._amounts(a.win_tokens)
	d.first_win_gold = maxi(0, a.first_win_gold)
	d.win_gold = maxi(0, a.win_gold)
	return d

## One individual tower of a type, for a level's hand (tests and tools; the game builds it from the save).
func tower(type: TowerAsset, tower_id: String, custom_name: String = "") -> TowerDef:
	if type == null: return null
	var d := TowerDef.new()
	d.id = tower_id
	d.custom_name = custom_name
	d.type = tower_type(type)
	return d

func level(a: LevelAsset) -> LevelDef:
	if a == null: return null
	if _cache.has(a): return _cache[a]
	var d := LevelDef.new()
	d.name = a.name
	d.hand_cap = a.hand_cap
	d.start_energy = a.start_energy
	d.energy_per_round = a.energy_per_round
	_cache[a] = d

	var size := a.size
	d.width = size.x
	d.height = size.y
	for x in size.x:
		for y in size.y:
			var p := Vector2i(x, y)
			var t := a.terrain_at(x, y)
			if t != null: d.terrain[p] = terrain(t)
			if a.build_at(x, y): d.buildable[p] = true
	for r in a.paths.size():
		var tiles := []
		tiles.assign(a.tiles_of(r))
		d.paths.append(tiles)
	for b in a.bases:
		if b == null: continue
		var base := BaseDef.new()
		base.tile = b.tile
		base.entity = entity(b.entity)
		d.bases.append(base)
	for u in a.starting_units:
		if u == null: continue
		var su := StartingUnitDef.new()
		su.entity = entity(u.entity)
		su.tile = u.tile
		su.side = u.side
		su.path = u.path
		su.facing = u.facing
		d.starting_units.append(su)
	for w in a.waves:
		if w == null: continue
		var wave := WaveDef.new()
		wave.name = w.name
		wave.start = w.start
		wave.start_round = w.start_round
		wave.after_wave = w.after_wave
		for s in w.spawns:
			if s == null: continue
			var se := SpawnEntry.new()
			se.round = s.round
			se.enemy = entity(s.enemy)
			se.path = s.path
			se.facing = s.facing
			wave.spawns.append(se)
		for e in w.events:
			if e == null: continue
			var ev := LevelEventDef.new()
			ev.round = e.round
			ev.kind = e.kind
			ev.enemy = entity(e.enemy)
			ev.count = e.count
			ev.path = e.path
			ev.random_tiles = e.random_tiles
			ev.facing = e.facing
			ev.energy = e.energy
			ev.message = e.message
			ev.terrain = terrain(e.terrain)
			var tiles := []
			tiles.assign(e.tiles)
			ev.tiles = tiles
			ev.build = e.build
			wave.events.append(ev)
		d.waves.append(wave)
	return d

## C# ToPos: Unity's Vector2Int → Pos; both are Vector2i here.
static func to_pos(v: Vector2i) -> Vector2i:
	return v

## Parses a stat value written in an EntityAsset (invariant culture, exact decimal): the number, or null when it is
## not one (C# TryParse(text, out Num) → false).
static func try_parse(text):
	if text == null: return null
	var s: String = str(text).strip_edges()
	if s.is_empty() or not s.is_valid_float(): return null
	if s.containsn("e") or s.containsn("inf") or s.containsn("nan"): return null # decimal.Parse takes no exponent
	return Num.parse(s)

## Builds the GameRules (with its vocabulary) from the rules asset.
func rules(a: GameRulesAsset) -> GameRules:
	if _cache.has(a): return _cache[a]
	var r := GameRules.new(a.create_vocabulary())
	r.hit_chance = a.hit_chance
	r.crit_chance = a.crit_chance
	r.crit_multiplier = a.crit_multiplier
	r.mitigation = a.mitigation
	r.mana_regen = a.mana_regen
	r.facing_enabled = a.facing_enabled
	r.max_depth = a.max_depth
	for rel in a.relations:
		if rel != null: r.set_relation(rel.team_a, rel.team_b, rel.relation)
	_cache[a] = r
	r.reactions = _reactions(a.reactions)
	r.replacements = _replacements(a.replacements)
	r.modifiers = a.modifiers.duplicate() if a.modifiers != null else []
	return r

## The core steps of a step list (null entries skipped).
func steps(list: StepList) -> Array:
	var result := []
	if list == null or list.items == null: return result
	for item in list.items:
		if item != null: result.append(item.to_core(self))
	return result

func replacement(r: ReplacementData) -> ReplacementRule:
	var d := ReplacementRule.new()
	d.name = r.name
	d.matches = r.matches
	d.with_tags = _copy(r.with_tags)
	d.condition = r.condition
	d.action = r.action
	d.instead = steps(r.instead)
	return d

func _replacements(list: Array) -> Array:
	var result := []
	if list != null:
		for r in list:
			if r != null: result.append(replacement(r))
	return result

func _reactions(list: Array) -> Array:
	var result := []
	if list != null:
		for r in list:
			if r != null: result.append(reaction(r))
	return result

static func _copy(a) -> Array:
	var result := []
	if a != null: result.assign(a)
	return result
