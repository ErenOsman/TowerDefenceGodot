class_name Entity
extends IEntity
## Anything with an identity in a battle: a unit, an object, a hazard or the Environment entity.
## Plain data owned by GameState; only effects change it. Final stats, tags, effective team and
## capabilities are computed on read, never stored.
## `name` (C# Name) is inherited from IEntity.

## A cooldown that does not count down: the ability waits until a Reset Cooldown step frees it (e.g. on a kill).
const HeldCooldown := 2147483647

var id: int = 0
var def: EntityDef = null
var kind: int = EntityKind.Unit
var life: int = LifeState.Alive

## The effective team may differ (status overrides): use GameState.effective_team.
var base_team: int = 0

## Vector2i, or null when not on the board (Environment, Dead, Removed).
var position = null

## Read only when GameRules.facing_enabled.
var facing: Vector2i = Vector2i(0, 1)

## String → float.
var base_stats: Dictionary = {}

## Current amounts other than HP: Mana, Ap (action points), Mp (movement points), custom ones. String → int.
var resources: Dictionary = {}

## Array of StatusInstance, oldest first.
var statuses: Array = []
## Array of PassiveInstance.
var passives: Array = []
## Array of ItemDef.
var items: Array = []
## Array of AbilityDef.
var abilities: Array = []

var summoner: int = -1
var created_by: int = -1
var death: DeathRecord = null

## The path an OnPath entity follows (index into BattleGrid.paths); -1 for none.
var path_id: int = -1

## Where it is on its path: the index of its tile in the path's tile list. A path may pass a tile twice
## (a loop), so this is kept, not looked up: set on spawn, updated on every move (the visit nearest the old step).
var path_step: int = -1

## The round it last lost HP in (GameState.round); -1 if never. DamagedThisRound reads it.
var last_damaged_round: int = -1

## The level wave this entity belongs to (spawns, LevelEvent spawns and their summons); -1 for none.
var wave: int = -1

## How many turns the unit has started (its TurnStarted count): 1 during its first turn. Formulas read Self.TurnsTaken.
var turns_taken: int = 0

## Turns left before an ability can be cast again (AbilityDef → int); drops by one at each of the entity's TurnStarted.
var cooldowns: Dictionary = {}

## OncePerTurn limits fired since the last TurnStarted (a Dictionary used as a set).
var fired_this_turn: Dictionary = {}

## The Source of the effect that brought HP to 0; -1 (None) for the Environment.
var hp_zero_by: int = -1

## A tag for the EntityDied event of the death under way (Fell: its tile became unstandable); cleared on death.
var death_tag = null

var _hp: int = 0
## C# internal State. Held weakly: the state owns its entities, and a strong back-reference would make
## every GameState (and every clone, e.g. forecasts) a reference cycle that RefCounted never frees.
var _state_ref: WeakRef = null
var state: GameState:
	get: return null if _state_ref == null else _state_ref.get_ref()
	set(v): _state_ref = null if v == null else weakref(v)

## How far ahead along this entity's own path another one stands: the index of the path tile
## nearest to it (ties: the further one). -1 when this entity follows no path.
func ahead_on_path(other: Entity) -> int:
	var p: PathDef = state.grid.path(path_id) if path_id >= 0 else null
	if p == null or other == null: return -1
	var best := -1
	var best_distance := 2147483647
	var op := other.pos
	for i in p.tiles.size():
		var d := Dirs.manhattan(p.tiles[i], op)
		if d <= best_distance:
			best = i
			best_distance = d
	return best

## How far along its own path it stands (its step; higher = closer to the end), or -1 off a path.
var path_progress: int:
	get:
		var p: PathDef = state.grid.path(path_id) if path_id >= 0 and on_board else null
		if p == null: return -1
		var here := pos
		if path_step >= 0 and path_step < p.tiles.size() and p.tiles[path_step] == here: return path_step
		return p.visit_near(here, path_step)

# ------------------------------------------------------------------ life and placement

var alive: bool:
	get: return life == LifeState.Alive

var is_environment: bool:
	get: return kind == EntityKind.Environment_

var on_board: bool:
	get: return position != null and alive

## The board position, or the death tile for a corpse.
var pos: Vector2i:
	get:
		if position != null: return position
		if death != null: return death.tile
		return Vector2i.ZERO

## Units always have HP; objects only when their MaxHp is above 0; hazards never.
var has_hp: bool:
	get: return kind == EntityKind.Unit or (kind == EntityKind.Object_ and max_hp > 0)

# ------------------------------------------------------------------ stats and resources

func stat(p_stat: String) -> float:
	return state.final_stat(self, p_stat)

var max_hp: int:
	get: return Num.floor_to_int(state.final_stat(self, "MaxHp"))

## Never below 0, and capped on read when MaxHp falls (Entity System — Max HP changes).
var hp: int:
	get: return mini(_hp, maxi(0, max_hp))
	set(v): _hp = maxi(0, v)

## The stat that caps a resource: Mana → MaxMana, Ap → ActionPoints, Mp → MovePoints; null otherwise.
static func max_stat_of(p_resource: String) -> Variant:
	match p_resource:
		"Mana": return "MaxMana"
		"Ap": return "ActionPoints"
		"Mp": return "MovePoints"
		_: return null

## A resource's current amount, capped to its maximum when it has one.
func resource(p_name: String) -> int:
	var v: int = int(resources.get(p_name, 0))
	var mx = Entity.max_stat_of(p_name)
	return v if mx == null or not base_stats.has(mx) else mini(v, Num.floor_to_int(state.final_stat(self, mx)))

## Sum of the active shield pools.
var shield: int:
	get:
		var n := 0
		for s in statuses:
			if s.active and s.pool > 0: n += s.pool
		return n

# ------------------------------------------------------------------ statuses and tags

func has_status(p_name: String) -> bool:
	for s in statuses:
		if s.active and s.def.name == p_name: return true
	return false

func stacks(p_name: String) -> int:
	var n := 0
	for s in statuses:
		if s.active and s.def.name == p_name: n += s.stacks
	return n

## Inherent tags plus tags granted by active statuses.
func has_tag(tag: String) -> bool:
	if def != null and def.tags.has(tag): return true
	for s in statuses:
		if s.active and s.has_tag(tag): return true
	return false

## Statuses grouped for display, oldest first: total stacks, longest duration, the instances.
## Hidden instances are left out unless include_hidden (debug tools).
func status_summaries(include_hidden: bool = false) -> Array:
	var result := []
	for st in statuses:
		if st.is_hidden and not include_hidden: continue
		var sum: StatusSummary = null
		for x in result:
			if x.def == st.def:
				sum = x
				break
		if sum == null:
			sum = StatusSummary.new()
			sum.def = st.def
			sum.turns_left = st.turns_left
			result.append(sum)
		sum.instances.append(st)
		sum.stacks += st.stacks
		sum.turns_left = -1 if sum.turns_left < 0 or st.turns_left < 0 else maxi(sum.turns_left, st.turns_left)
	return result

# ------------------------------------------------------------------ capabilities (computed, never stored)

## Units act; objects do not, except bases (tag Base), which the player commands like towers;
## and no tag that prevents acting (Stunned, Frozen, Asleep).
var can_act: bool:
	get:
		if not alive: return false
		if not (kind == EntityKind.Unit or (kind == EntityKind.Object_ and has_tag(Tags.Base))): return false
		for t in Tags.PreventActing:
			if has_tag(t): return false
		return true

## Voluntary movement only; pushes and pulls ignore it.
var can_move: bool:
	get: return can_act and not has_tag(Tags.Rooted)

## Where the entity may stand: its definition's footing (OnPath: only its own path).
var footing: int:
	get: return def.footing if def != null else Footing.Any

func cooldown(ability) -> int:
	return cooldowns.get(ability, 0)

## Whether the ability waits for a reset rather than for turns.
func cooldown_held(ability) -> bool:
	return cooldown(ability) == HeldCooldown

## Alive, a targetable kind (Units; Objects with HP), not Untargetable, and not Stealthed
## against an enemy. Area attacks pass single_target = false: they still hit stealthed entities.
func is_targetable_by(by: Entity, single_target: bool = true) -> bool:
	if not alive or not has_hp or has_tag(Tags.Untargetable): return false
	if single_target and by != null and has_tag(Tags.Stealthed) and state.relation(by, self) == Relation.Enemy: return false
	return true

# ------------------------------------------------------------------ setup helpers

func _innate() -> PassiveInstance:
	for x in passives:
		if x.def.name == "<innate>": return x
	var p := PassiveInstance.new()
	p.def = PassiveDef.new()
	p.def.name = "<innate>"
	p.active = true
	passives.insert(0, p)
	return p

## Gives the entity an always-on rule (for setup in code and tests). The C# overloads in one method:
## a ReactionDef, Modifier or ReplacementRule goes into the innate passive; a PassiveDef is added as a passive.
func grant(rule) -> Entity:
	if rule is ReactionDef: _innate().def.reactions.append(rule)
	elif rule is Modifier: _innate().def.modifiers.append(rule)
	elif rule is ReplacementRule: _innate().def.replacements.append(rule)
	elif rule is PassiveDef:
		var p := PassiveInstance.new()
		p.def = rule
		passives.append(p)
	else: push_error("Entity.grant: unsupported rule %s" % [rule])
	return self

## A copy belonging to `p_state`: every field copied (C# MemberwiseClone), collections copied, definitions shared.
func clone_into(p_state: GameState) -> Entity:
	var e := Entity.new()
	e.id = id
	e.def = def
	e.name = name
	e.kind = kind
	e.life = life
	e.base_team = base_team
	e.position = position
	e.facing = facing
	e.summoner = summoner
	e.created_by = created_by
	e.path_id = path_id
	e.path_step = path_step
	e.last_damaged_round = last_damaged_round
	e.wave = wave
	e.turns_taken = turns_taken
	e.hp_zero_by = hp_zero_by
	e.death_tag = death_tag
	e._hp = _hp
	e.state = p_state
	e.base_stats = base_stats.duplicate()
	e.resources = resources.duplicate()
	e.statuses = []
	for s in statuses: e.statuses.append(s.clone())
	e.passives = []
	for p in passives: e.passives.append(p.clone())
	e.items = items.duplicate()
	e.abilities = abilities.duplicate()
	e.death = death.clone() if death != null else null
	e.fired_this_turn = fired_this_turn.duplicate()
	e.cooldowns = cooldowns.duplicate()
	return e

func _to_string() -> String:
	return name
