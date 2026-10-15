class_name GameState
extends RefCounted
## All combat data: entities, statuses, grid, turn order and RNG state. Plain data, cloneable,
## no engine calls. Definitions (abilities, statuses, rules) are shared read-only.
## C# Get(id) is get_entity(id): Object.get() cannot be overridden (see docs/Sim Port.md Renames).

var rules: GameRules
var grid: BattleGrid
var rng: IRng

## Index == EntityId; [0] is the Environment. Entities are never removed from this list.
var entities: Array = []

## Abilities between their CastAbility and EndAbility; their scoped modifiers apply. Array of AbilityInstance.
var open_abilities: Array = []

# Turns (Entity System — Turns)
var round: int = 0
## Array of EntityId ints.
var turn_order: Array = []
var turn_index: int = -1
var current_turn: int = -1

var _ability_instance_counter: int = 0
var _attack_counter: int = 0

var _aura_guard: Dictionary = {}
var _stat_guard: Dictionary = {}

## GameState.new(rules, grid, seed). The C# private constructor used by clone() is _bare = true.
func _init(p_rules: GameRules = null, p_grid: BattleGrid = null, p_seed: int = 0, _bare: bool = false) -> void:
	rules = p_rules
	if _bare: return
	grid = p_grid
	rng = XorShiftRng.new(p_seed)
	var env := Entity.new()
	env.id = 0
	env.name = "Environment"
	env.kind = EntityKind.Environment_
	env.base_team = -1
	env.state = self
	entities.append(env)

var vocab: Vocabulary:
	get: return rules.vocabulary

var environment: Entity:
	get: return entities[0]

## C# Get(EntityId): the entity, or null.
func get_entity(p_id: int) -> Entity:
	return entities[p_id] if p_id >= 0 and p_id < entities.size() else null

# ------------------------------------------------------------------ creating entities

## Creates an entity from a definition with the next EntityId. Effects use this through SpawnEffect.
## position: Vector2i or null.
func create(def: EntityDef, team: int, p_position) -> Entity:
	var e := Entity.new()
	e.id = entities.size()
	e.def = def
	e.name = def.display_name # what players see; rules and saves use def.name (the id)
	e.kind = def.kind
	e.base_team = team
	e.position = p_position
	e.state = self
	e.base_stats = def.base_stats.duplicate()
	e.abilities = def.abilities.duplicate()
	for p in def.passives:
		var pi := PassiveInstance.new()
		pi.def = p
		e.passives.append(pi)
	for a in e.abilities: # abilities that start on cooldown (-1: held until a reset)
		if a != null and a.start_cooldown != 0: e.cooldowns[a] = Entity.HeldCooldown if a.start_cooldown < 0 else a.start_cooldown
	entities.append(e)

	e.hp = e.max_hp
	for r in ["Mana", "Ap", "Mp"]:
		var mx = Entity.max_stat_of(r)
		if e.base_stats.has(mx): e.resources[r] = Num.floor_to_int(final_stat(e, mx))
	return e

## Setup helper: a Unit with MaxHp = hp and the given base stats (Initiative defaults to 0).
## stats: Array of [stat_name, value] pairs (the C# params tuples).
func add_unit(p_name: String, team: int, p_pos: Vector2i, hp: int, stats: Array = []) -> Entity:
	var def := EntityDef.new()
	def.name = p_name
	def.kind = EntityKind.Unit
	def.base_stats["MaxHp"] = float(hp)
	def.base_stats["Initiative"] = 0.0
	for s in stats: def.base_stats[s[0]] = float(s[1])
	return create(def, team, p_pos)

# ------------------------------------------------------------------ occupancy

## The living unit or object on a tile's blocking layer, if any.
func entity_at(p: Vector2i) -> Entity:
	for e in entities:
		if e.on_board and e.position == p and (e.kind == EntityKind.Unit or e.kind == EntityKind.Object_): return e
	return null

## Hazards on a tile's overlay layer.
func hazards_at(p: Vector2i) -> Array:
	var out := []
	for e in entities:
		if e.on_board and e.position == p and e.kind == EntityKind.Hazard: out.append(e)
	return out

## Corpses (Dead entities) whose death tile is p.
func corpses_at(p: Vector2i) -> Array:
	var out := []
	for e in entities:
		if e.life == LifeState.Dead and e.death != null and e.death.tile == p: out.append(e)
	return out

## is_free(p): not blocking movement and nobody there. is_free(p, flying): free for a walker or, with flying,
## a flyer (which may also stand over a chasm). The C# overloads: flying = null means the one-argument form.
func is_free(p: Vector2i, flying = null) -> bool:
	if flying == null: return not grid.blocks_movement(p) and entity_at(p) == null
	return grid.can_stand_on(p, flying) and entity_at(p) == null

## Whether the entity's footing allows the tile (occupancy aside): the terrain must let it stand (flyers
## also over chasms); OnPath entities only on their own path, OffPath entities never on any path.
func can_stand(e: Entity, p: Vector2i) -> bool:
	if not grid.can_stand_on(p, e.has_tag(Tags.Flying)): return false # flyers cross chasms
	match e.footing:
		Footing.OnPath:
			var path := grid.path(e.path_id)
			return path.contains(p) if path != null else false
		Footing.OffPath: return not grid.is_path(p)
		_: return true

## Free and allowed by the entity's footing.
func can_enter(e: Entity, p: Vector2i) -> bool:
	if not can_stand(e, p): return false
	var o := entity_at(p)
	return o == null or o == e

## The free tile of a path nearest to index i (by index distance, the tile behind first on a tie),
## or null when every tile of the path is taken.
func free_path_tile_near(p_path_id: int, i: int, flying: bool = false) -> Variant:
	var path := grid.path(p_path_id)
	if path == null: return null
	for d in path.tiles.size():
		for k in ([i] if d == 0 else [i - d, i + d]):
			if k >= 0 and k < path.tiles.size() and is_free(path.tiles[k], flying): return path.tiles[k]
	return null

## The tile itself if free, else the nearest free tile within 1 in canonical order (orthogonal first, then y, x).
func free_tile_near(p: Vector2i, flying: bool = false) -> Variant:
	if is_free(p, flying): return p
	for pass_ in range(1, 3):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if absi(dx) + absi(dy) != pass_: continue
				var t := Vector2i(p.x + dx, p.y + dy)
				if is_free(t, flying): return t
	return null

func next_ability_instance_id() -> int:
	_ability_instance_counter += 1
	return _ability_instance_counter

func next_attack_id() -> int:
	_attack_counter += 1
	return _attack_counter

## A deep copy: own grid terrain (paths shared), cloned RNG, copied entities (statuses/passives copied,
## definitions shared). Open abilities are not copied (C# behaviour).
func clone() -> GameState:
	var s := GameState.new(rules, null, 0, true)
	s.grid = grid.clone()
	s.rng = rng.clone()
	s._ability_instance_counter = _ability_instance_counter
	s._attack_counter = _attack_counter
	s.round = round
	s.turn_order = turn_order.duplicate()
	s.turn_index = turn_index
	s.current_turn = current_turn
	for e in entities: s.entities.append(e.clone_into(s))
	return s

# ------------------------------------------------------------------ teams

## The newest active team override wins; otherwise the base team.
func effective_team(e: Entity) -> int:
	for i in range(e.statuses.size() - 1, -1, -1):
		var st: StatusInstance = e.statuses[i]
		if st.active and st.def.team_override != TeamOverride.None: return st.override_team
	return e.base_team

## An entity is always its own ally; the Environment is nobody's ally.
func relation(a: Entity, b: Entity) -> int:
	if a == b: return Relation.Ally
	if a.is_environment or b.is_environment: return Relation.Neutral
	return rules.relation_of(effective_team(a), effective_team(b))

# ------------------------------------------------------------------ rule sources

## The rule sources that apply to an entity (Array of RuleEntry), in definition order: passives, statuses oldest
## first, items, then auras by owner EntityId. Gathered on read; nothing is registered.
## Removed entities contribute nothing; Dead owners' auras end.
## (The C# is a lazy iterator; gathering eagerly gives the same entries: aura filters run under the guard,
## which is released before the entries are returned, as in the C#.)
func rules_of(receiver: Entity) -> Array:
	var out := []
	if receiver.life == LifeState.Removed: return out
	if receiver.is_environment:
		out.append(RuleEntry.new(rules, receiver, "env"))
		return out

	var rid := str(receiver.id)
	for p in receiver.passives:
		if p.active and p.def.aura.is_empty:
			out.append(RuleEntry.new(p.def, receiver, "%s:passive:%s" % [rid, p.def.name]))
	for i in receiver.statuses.size():
		var st: StatusInstance = receiver.statuses[i]
		if st.active and st.def.aura.is_empty:
			out.append(RuleEntry.new(st.def, receiver, "%s:status:%s:%d" % [rid, st.def.name, i], st))
	for item in receiver.items:
		out.append(RuleEntry.new(item, receiver, "%s:item:%s" % [rid, item.name]))

	# auras: a filter evaluated while gathering could read stats, which gather rules again — skip nested auras
	if _aura_guard.has(receiver.id): return out
	_aura_guard[receiver.id] = true
	var auras := []
	for owner in entities:
		if not owner.alive or owner.is_environment: continue
		for p in owner.passives:
			if p.active and not p.def.aura.is_empty and _aura_covers(p.def.aura, owner, receiver):
				auras.append(RuleEntry.new(p.def, owner, "%s:aura:%d:%s" % [rid, owner.id, p.def.name], null, true))
		for st in owner.statuses:
			if st.active and not st.def.aura.is_empty and _aura_covers(st.def.aura, owner, receiver):
				auras.append(RuleEntry.new(st.def, owner, "%s:aura:%d:%s" % [rid, owner.id, st.def.name], st, true))
	_aura_guard.erase(receiver.id)
	out.append_array(auras)
	return out

func _aura_covers(aura: Condition, owner: Entity, receiver: Entity) -> bool:
	var ctx := EvalContext.new()
	ctx.self_ = owner
	ctx.source = owner
	ctx.target = receiver
	ctx.rng = rng
	ctx.mode = EvalMode.PreviewMin
	return aura.evaluate(vocab, ctx)

# ------------------------------------------------------------------ stats and modifiers

## A stat's final value: base plus modifiers from the entity's rule sources and from the
## scoped modifiers of resolving abilities. Hp, HpPct, Shield, Mana, Ap and Mp read live state.
func final_stat(e: Entity, p_stat: String) -> float:
	match p_stat:
		"Hp": return float(e.hp)
		"Shield": return float(e.shield)
		"Mana", "Ap", "Mp": return float(e.resource(p_stat))
		"HpPct":
			var mx := final_stat(e, "MaxHp")
			return 0.0 if mx <= 0.0 else Num.div(float(e.hp), mx)

	var base_value: float = e.base_stats.get(p_stat, 0.0)
	var key := "%d:%s" % [e.id, p_stat]
	if _stat_guard.has(key): return base_value # a modifier reading its own stat sees the base value
	_stat_guard[key] = true
	var mods := []
	for r in rules_of(e):
		for mod in r.source.modifiers:
			if mod.target == p_stat:
				mods.append([mod.kind, eval_modifier(mod, r.holder, null, null, null)])
	for ability in open_abilities:
		for scoped in ability.scoped:
			if scoped.owner == e.id and scoped.modifier.target == p_stat:
				mods.append([scoped.modifier.kind, eval_modifier(scoped.modifier, e, null, null, null)])
	var result := ModifierPipeline.apply(base_value, mods)
	_stat_guard.erase(key)
	return result

## A modifier's amount, resolved with Self = the entity carrying it. vars: Dictionary or null.
func eval_modifier(mod: Modifier, holder: Entity, source: Entity, target: Entity, vars) -> float:
	var ctx := EvalContext.new()
	ctx.self_ = holder
	ctx.source = source if source != null else holder
	ctx.target = target if target != null else holder
	ctx.vars = vars if vars != null else {}
	ctx.rng = rng
	return mod.amount.evaluate(vocab, ctx)

## Modifiers on a variable (Power, Damage, FinalDamage, MaxRadius…): outgoing ones from the
## source (plus the ability's scoped modifiers), incoming ones from the target, filtered by tags.
## Returns an Array of [ModKind, amount] pairs (ModifierPipeline.apply's format). tags: Array/Dictionary set/null.
func value_modifiers(value_name: String, source: Entity, target: Entity, tags, ability, vars) -> Array:
	var result := []
	if source != null:
		for r in rules_of(source):
			for mod in r.source.modifiers:
				if mod.direction == ModDirection.Outgoing and mod.applies_to(value_name, tags):
					result.append([mod.kind, eval_modifier(mod, r.holder, source, target, vars)])
		if ability != null:
			for scoped in ability.scoped:
				if scoped.owner == source.id and scoped.modifier.direction == ModDirection.Outgoing and scoped.modifier.applies_to(value_name, tags):
					result.append([scoped.modifier.kind, eval_modifier(scoped.modifier, source, source, target, vars)])
	if target != null:
		for r in rules_of(target):
			for mod in r.source.modifiers:
				if mod.direction == ModDirection.Incoming and mod.applies_to(value_name, tags):
					result.append([mod.kind, eval_modifier(mod, r.holder, source, target, vars)])
	return result
