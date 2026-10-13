class_name ResolveContext
extends RefCounted
## Per-queue-item state: events written, child effects, the current effect and chain.

var resolver: Resolver
var state: GameState
var log: EventLog
## Array of Effect.
var children: Array = []
## Array of GameEvent.
var new_events: Array = []

var current: Effect
## internal in C#.
var chain: Chain
var chain_index: int = 0

func _init(p_resolver: Resolver) -> void:
	resolver = p_resolver
	state = p_resolver.state
	log = p_resolver.log

## Writes an event caused by the given effect and gathers the reactions it triggers.
func write(by: Effect, e: GameEvent) -> GameEvent:
	e.cause = by.cause if by != null else -1
	e.depth = by.depth if by != null else 0
	if e.ability == null and by != null: e.ability = by.ability
	if e.attack_id == 0 and by != null and by.attack != null: e.attack_id = by.attack.id
	log.write(e)
	new_events.append(e)
	resolver.gather(e)
	return e

## A child effect: goes to the front of the queue after this item, in authored order.
func push(child: Effect) -> void:
	children.append(child)

func push_all(p_children: Array) -> void:
	children.append_array(p_children)

## Inserts effects right after the current one in the running chain (If branches).
func insert_into_chain(effects: Array) -> void:
	for e in effects: e.chain = chain
	var at: int = chain_index + 1
	for i in effects.size():
		chain.effects.insert(at + i, effects[i])

## Variables readable by an effect: frozen Attack results, event facts, then chain variables.
func vars(e: Effect) -> Dictionary:
	var v := {}
	if e.ability != null:
		for k in e.ability.frozen: v[k] = e.ability.frozen[k]
	if e.attack != null: v["ActionPower"] = e.attack.power
	if e.event_facts != null:
		for k in e.event_facts: v[k] = e.event_facts[k]
	if e.chain != null:
		for k in e.chain.vars: v[k] = e.chain.vars[k]
	return v

func eval(_e: Effect, p_self: Entity, source: Entity, target: Entity, p_vars: Dictionary) -> EvalContext:
	var c := EvalContext.new()
	c.self_ = p_self
	c.source = source
	c.target = target
	c.vars = p_vars
	c.rng = state.rng
	c.mode = resolver.mode
	c.trace = resolver.trace
	return c

## Rolls a chance: no RNG draw at ≥ 1 or ≤ 0; previews treat the roll as passing.
func roll(chance: float) -> bool:
	return resolver.roll(chance)

## Stores an effect's results as chain variables and per-target ability results.
func set_results(e: Effect, facts: Dictionary) -> void:
	if e.chain != null:
		for k in facts: e.chain.vars[k] = facts[k]
	if e.ability != null and e.target_id >= 0:
		if not e.ability.results.has(e.target_id): e.ability.results[e.target_id] = {}
		var r: Dictionary = e.ability.results[e.target_id]
		for k in facts: r[k] = facts[k]
		if e.chain != null:
			for k in e.chain.vars: r[k] = e.chain.vars[k]

func move(by: Effect, u: Entity, to: Vector2i, kind: String) -> void:
	var from: Vector2i = u.pos
	u.position = to
	if u.path_id >= 0: # loops: the visit nearest its old step
		var path = state.grid.path(u.path_id)
		u.path_step = path.visit_near(to, u.path_step) if path != null else -1
	for t in [GameEventType.EntityMoved, GameEventType.EntityEnteredTile]:
		var e := GameEvent.new()
		e.type = t
		e.source = by.source
		e.target = u.id
		e.from = from
		e.to = to
		e.detail = kind
		e.tags = by.tags.duplicate()
		write(by, e)

## Turns an entity; does nothing while facing is disabled or the direction is unchanged.
func face(by: Effect, e: Entity, dir: Vector2i) -> void:
	if not state.rules.facing_enabled or Dirs.is_none(dir) or e.facing == dir: return
	var before: Vector2i = e.facing
	e.facing = dir
	var ev := GameEvent.new()
	ev.type = GameEventType.FacingChanged
	ev.source = by.source
	ev.target = e.id
	ev.detail = "<%d,%d> -> <%d,%d>" % [before.x, before.y, dir.x, dir.y] # C# Dir.ToString()
	write(by, ev)

## Writes StatusRemoved while the status is still held, so its own reactions respond,
## then removes it and reports a team change it causes.
func remove_status(by: Effect, target: Entity, st: StatusInstance) -> void:
	if not target.statuses.has(st): return
	var team_before: int = state.effective_team(target)
	var removed := GameEvent.new()
	removed.type = GameEventType.StatusRemoved
	removed.source = by.source if by != null else 0
	removed.target = target.id
	removed.detail = st.def.name
	if by != null: removed.tags = by.tags.duplicate()
	removed.facts["Stacks"] = float(target.stacks(st.def.name) - st.stacks) # what is left after it goes
	write(by, removed)
	target.statuses.erase(st)
	check_team(by, target, team_before)

## Writes TeamChanged when the entity's effective team differs from the given one.
func check_team(by: Effect, target: Entity, team_before: int) -> void:
	var now: int = state.effective_team(target)
	if now == team_before: return
	var e := GameEvent.new()
	e.type = GameEventType.TeamChanged
	e.source = by.source if by != null else 0
	e.target = target.id
	e.facts["From"] = float(team_before)
	e.facts["To"] = float(now)
	write(by, e)

## Counts down the entity's statuses measured in the given unit; a status at 0 is removed.
func count_down(by: Effect, e: Entity, unit: int) -> void:
	for st in e.statuses.duplicate():
		if st.def.duration_unit != unit or st.turns_left < 0: continue
		st.turns_left -= 1
		if st.turns_left <= 0: remove_status(by, e, st)
