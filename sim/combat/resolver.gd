class_name Resolver
extends RefCounted
## Runs commands to completion. One queue; one item (an effect or a batch) at a time;
## a checkpoint after every item: deaths, passives, then reactions. No other component
## determines resolution order.

var state: GameState
var log: EventLog
var mode: int = EvalMode.Execute

## False: no reaction fires (a cast preview shows only what the cast does to its targets; replacements still apply).
var reactions: bool = true

## When set, formula breakdowns are collected here.
var trace: Trace

## The queue (C# LinkedList): index 0 is the front. Array of Effect.
var _queue: Array = []
## Array of PendingReaction.
var _pending: Array = []

func _init(p_state: GameState, p_log: EventLog = null) -> void:
	state = p_state
	log = p_log if p_log != null else EventLog.new()

# ------------------------------------------------------------------ commands

func cast(caster: Entity, ability: AbilityDef, aim: Aim) -> void:
	var c := CastAbilityEffect.new()
	c.def = ability
	c.caster = caster.id
	c.aim = aim
	c.source = caster.id
	run(c)

## Starts a specific entity's turn (outside the round order, e.g. in tests).
## p_tick_cooldowns: false when the unit's cooldowns drop elsewhere (tick_cooldowns).
func start_turn(unit: Entity, p_tick_cooldowns: bool = true) -> void:
	state.current_turn = unit.id
	var e := TurnStartEffect.new()
	e.target_id = unit.id
	e.source = unit.id
	e.tick_cooldowns = p_tick_cooldowns
	run(e)

## Drops a unit's cooldowns by one outside its turn start.
func tick_cooldowns(unit: Entity) -> void:
	var e := CooldownTickEffect.new()
	e.target_id = unit.id
	e.source = unit.id
	run(e)

## C# EndTurn(unit) and EndTurn(): with no unit, ends the current entity's turn, if any.
func end_turn(unit: Entity = null) -> void:
	if unit == null:
		var current: Entity = state.get_entity(state.current_turn)
		if current != null: end_turn(current)
		return
	var e := TurnEndEffect.new()
	e.target_id = unit.id
	e.source = unit.id
	run(e)

## Starts a new round: builds the turn order by Initiative and writes RoundStarted.
func start_round() -> void:
	var e := RoundStartEffect.new()
	e.source = 0
	run(e)

## Starts the next living unit's turn in the round's order; entities that died or were
## removed are skipped. Returns null when every turn of the round is done.
func begin_next_turn() -> Entity:
	while state.turn_index + 1 < state.turn_order.size():
		state.turn_index += 1
		var e: Entity = state.get_entity(state.turn_order[state.turn_index])
		if e == null or not e.alive: continue
		start_turn(e)
		return e
	state.current_turn = -1
	return null

## Writes RoundEnded and counts down round-based statuses.
func end_round() -> void:
	var e := RoundEndEffect.new()
	e.source = 0
	run(e)

## Runs a command until the queue is empty; only then is the next command accepted.
## (C# throws InvalidOperationException when a command is already resolving: push_error and return.)
func run(command: Effect) -> void:
	if _queue.size() > 0:
		push_error("A command is already resolving.")
		return
	var scope = log.begin_action(ActionKind.Command, command.source, command.name) # joins the caller's action when one is open
	_recheck_passives(null)
	_queue.push_front(command)

	while _queue.size() > 0:
		var item: Effect = _queue.pop_front()
		var ctx := ResolveContext.new(self)

		log.begin_beat() # one beat per queue item
		if item is BatchEffect: _run_batch(item, ctx)
		else: _process(item, ctx)

		# checkpoint: its own beat, so deaths play after the hits that caused them
		log.begin_beat()
		_resolve_deaths(ctx)
		_recheck_passives(ctx)
		log.end_beat()
		var reacts: Array = _process_pending()

		_push_front(ctx.children)  # rule 7: children to the front, in authored order
		_push_front(reacts)        # rule 10: reactions in front of the children
	scope.dispose()

func _push_front(effects: Array) -> void:
	for i in range(effects.size() - 1, -1, -1): _queue.push_front(effects[i])

# ------------------------------------------------------------------ one effect

func _process(e: Effect, ctx: ResolveContext) -> void:
	if e.depth > state.rules.max_depth:
		log.warnings.append("Dropped %s: depth %d exceeds %d." % [e.name, e.depth, state.rules.max_depth])
		return

	ctx.current = e
	if not e.is_valid(state):
		var f := GameEvent.new()
		f.type = GameEventType.Fizzled
		f.source = e.source
		f.target = e.target_id
		f.detail = e.name
		ctx.write(e, f)
		return

	_apply_replacements(e, ctx)
	if e.cancelled: return

	e.apply(ctx)

# ------------------------------------------------------------------ batches

## Chains in canonical target order; HitResolved at each chain's end; forced moves last.
func _run_batch(batch: BatchEffect, ctx: ResolveContext) -> void:
	batch.build_chains(state)
	var attack: AttackContext = batch.attack

	for chain in batch.chains:
		var target: Entity = state.get_entity(chain.target)
		if target == null or not target.alive:
			var f := GameEvent.new()
			f.type = GameEventType.Fizzled
			f.source = attack.caster
			f.target = chain.target
			f.detail = "Chain"
			ctx.write(batch, f)
			continue

		ctx.chain = chain
		ctx.chain_index = 0
		while ctx.chain_index < chain.effects.size():
			if chain.stopped: break
			var e: Effect = chain.effects[ctx.chain_index]
			if e is PushEffect: batch.forced_moves.append(e) # rule 6
			else: _process(e, ctx)
			ctx.chain_index += 1
		ctx.chain = null

		# facts are filled before writing: reactions are gathered (and OnHitTaken checks Hit) at write time
		var hit := GameEvent.new()
		hit.type = GameEventType.HitResolved
		hit.source = attack.caster
		hit.target = chain.target
		hit.tags = attack.tags.duplicate()
		hit.facts["Hit"] = Num.bool_num(not chain.vars.has("Hit") or chain.var_("Hit"))
		hit.facts["IsCrit"] = Num.bool_num(chain.var_("IsCrit"))
		hit.facts["Damage"] = chain.vars.get("Damage", 0.0)
		hit.facts["FinalDamage"] = chain.vars.get("FinalDamage", 0.0)
		ctx.write(batch, hit)

	# Pushes away from the aim go farthest unit first, pulls nearest first; ties by unit id (then authored order: OrderBy is stable).
	var aim: Vector2i = attack.aim.tile
	var keyed: Array = []
	for i in batch.forced_moves.size():
		var p: PushEffect = batch.forced_moves[i]
		var d: int = _dist(p, aim)
		keyed.append([1 if p.pull else 0, d if p.pull else -d, p.target_id, i, p])
	keyed.sort_custom(func(a, b):
		for k in 4:
			if a[k] != b[k]: return a[k] < b[k]
		return false)
	for k in keyed: _process(k[4], ctx)

func _dist(p: PushEffect, aim: Vector2i) -> int:
	var u: Entity = state.get_entity(p.target_id)
	if u == null: return 0
	return maxi(absi(u.pos.x - aim.x), absi(u.pos.y - aim.y))

# ------------------------------------------------------------------ replacements

## Cancels first, then one redirect, then a replace. Replacements read state but never change it.
func _apply_replacements(e: Effect, ctx: ResolveContext) -> void:
	if e.kind == EffectKind.Other: return

	var matches: Array = [] # [rule, owner]
	for owner in state.entities:
		if not owner.alive and not owner.is_environment: continue
		for rule in RuleSources.replacements(state, owner):
			if rule.matches != e.kind: continue
			if rule.with_tags != null:
				var missing := false
				for t in rule.with_tags:
					if not e.tags.has(t): missing = true; break
				if missing: continue
			var ectx := EvalContext.new()
			ectx.self_ = owner
			ectx.source = state.get_entity(e.source)
			ectx.target = state.get_entity(e.target_id)
			ectx.vars = ctx.vars(e)
			ectx.rng = state.rng
			ectx.mode = mode
			if not rule.condition.evaluate(state.vocab, ectx): continue
			matches.append([rule, owner])
	if matches.is_empty(): return

	for m in matches:
		var rule = m[0]
		if rule.action != ReplaceAction.Cancel: continue
		e.cancelled = true
		var p := GameEvent.new()
		p.type = GameEventType.Prevented
		p.source = e.source
		p.target = e.target_id
		p.detail = "%s by %s" % [e.name, rule.name]
		ctx.write(e, p)
		return

	for m in matches:
		var rule = m[0]
		if rule.action != ReplaceAction.Redirect or e.redirected: continue
		e.target_id = m[1].id
		e.redirected = true
		break

	for m in matches:
		var rule = m[0]
		var owner: Entity = m[1]
		if rule.action != ReplaceAction.Replace: continue
		e.cancelled = true
		var pe := GameEvent.new()
		pe.type = GameEventType.Prevented
		pe.source = e.source
		pe.target = e.target_id
		pe.detail = "%s replaced by %s" % [e.name, rule.name]
		var prevented: GameEvent = ctx.write(e, pe)
		var t: Entity = state.get_entity(e.target_id)
		var sc := StepContext.new()
		sc.state = state
		sc.ability = e.ability
		sc.self_ = owner
		sc.effect_source = owner.id
		sc.target = t
		sc.aim = Aim.new(t.pos if t != null else owner.pos, Dirs.NONE)
		sc.tags = e.tags.duplicate()
		sc.cause = prevented.id
		sc.depth = e.depth + 1
		ctx.push_all(Step.expand_list(rule.instead, sc))
		return

# ------------------------------------------------------------------ checkpoint

## Every entity with HP at 0 dies, by EntityId. EntityDied is written while its statuses are
## still held (their OnDeath reactions respond); then statuses clear, except those that
## persist through death, and summons that die with their summoner are queued for removal.
func _resolve_deaths(ctx: ResolveContext) -> void:
	for u in state.entities.duplicate():
		if u.is_environment or not u.alive or not u.has_hp or u.hp > 0: continue
		var tile: Vector2i = u.pos
		u.life = LifeState.Dead
		var rec := DeathRecord.new()
		rec.killer = u.hp_zero_by
		rec.tile = tile
		u.death = rec
		u.position = null
		var team_before: int = state.effective_team(u)
		var died := GameEvent.new()
		died.type = GameEventType.EntityDied
		died.source = u.hp_zero_by
		died.target = u.id
		died.from = tile
		if u.death_tag != null and u.death_tag != "": died.tags[u.death_tag] = true
		u.death_tag = ""
		ctx.write(null, died)

		var kept: Array = []
		for st in u.statuses:
			if st.def.persists_through_death: kept.append(st)
		u.statuses.clear()
		u.statuses.append_array(kept)
		ctx.check_team(null, u, team_before)

		for summon in state.entities:
			if summon.summoner == u.id and summon.def != null and summon.def.die_with_summoner and summon.life != LifeState.Removed:
				var r := RemoveEffect.new()
				r.target_id = summon.id
				r.source = u.id
				r.reason = "summoner died"
				ctx.push(r)

## Passive conditions are re-checked (with optional hysteresis); status gates too. At a
## checkpoint a passive that changes writes PassiveActivated/Deactivated; at Run start it is silent.
func _recheck_passives(ctx: ResolveContext) -> void:
	for u in state.entities:
		if not u.alive or u.is_environment: continue
		var ectx := EvalContext.new()
		ectx.self_ = u
		ectx.rng = state.rng
		ectx.mode = mode
		for p in u.passives:
			var was: bool = p.active
			if p.active and not p.def.off_condition.is_empty:
				p.active = not p.def.off_condition.evaluate(state.vocab, ectx)
			else:
				p.active = p.def.condition.evaluate(state.vocab, ectx)
			if ctx != null and was != p.active:
				var ev := GameEvent.new()
				ev.type = GameEventType.PassiveActivated if p.active else GameEventType.PassiveDeactivated
				ev.source = u.id
				ev.target = u.id
				ev.detail = p.def.name
				ctx.write(null, ev)
		for st in u.statuses:
			st.active = st.def.passive_condition.evaluate(state.vocab, ectx)

# ------------------------------------------------------------------ reactions

## Collects the reactions an event triggers, in rule-9 order: the event's source side,
## then its target side, then every other entity by EntityId; each owner's rules in definition order.
func gather(e: GameEvent) -> void:
	if not reactions: return
	var owners: Array = []
	var src: Entity = state.get_entity(e.source)
	var tgt: Entity = state.get_entity(e.target)
	if src != null: owners.append(src)
	if tgt != null and tgt != src: owners.append(tgt)
	for u in state.entities:
		if u != src and u != tgt: owners.append(u)

	for owner in owners:
		for r in RuleSources.reactions(state, owner):
			var def: ReactionDef = r.def
			if not owner.alive and not owner.is_environment and not def.works_when_dead and def.trigger != Trigger.OnDeath: continue
			if not RuleSources.matches(def.trigger, e, owner, state): continue
			var p := PendingReaction.new()
			p.owner = owner
			p.def = def
			p.event = e
			p.effect_source = r.effect_source
			p.rule_key = r.key
			p.status = r.status
			_pending.append(p)

## Checks, rolls and expands the collected reactions, in collection order.
func _process_pending() -> Array:
	var responses: Array = []
	var batch: Array = _pending.duplicate()
	_pending.clear()

	for p in batch:
		var owner: Entity = p.owner
		var def: ReactionDef = p.def
		var e: GameEvent = p.event

		# removed entities drop everything; ones that died in this item drop what they collected, unless marked
		if owner.life == LifeState.Removed: continue
		if not owner.alive and not owner.is_environment and not def.works_when_dead and def.trigger != Trigger.OnDeath: continue
		if def.ignore_tags != null:
			var ignored := false
			for t in def.ignore_tags:
				if e.tags.has(t): ignored = true; break
			if ignored: continue

		var ability: AbilityInstance = e.ability
		if def.limit == Limit.OncePerAbility and ability != null and ability.fired.has(p.rule_key): continue
		if def.limit == Limit.OncePerTurn and owner.fired_this_turn.has(p.rule_key): continue

		var ectx := EvalContext.new()
		ectx.self_ = owner
		ectx.source = state.get_entity(e.source)
		ectx.target = state.get_entity(e.target)
		ectx.vars = Resolver._merge(e.facts, p.vars())
		ectx.rng = state.rng
		ectx.mode = mode
		if not def.condition.evaluate(state.vocab, ectx): continue # only reactions that pass their condition roll

		var pass_: bool
		if def.roll_per == RollPer.Attack and ability != null and e.attack_id > 0:
			var roll_key: String = "%s@%d" % [p.rule_key, e.attack_id]
			if ability.attack_rolls.has(roll_key):
				pass_ = ability.attack_rolls[roll_key]
			else:
				pass_ = roll(def.chance.evaluate(state.vocab, ectx))
				ability.attack_rolls[roll_key] = pass_
		else:
			pass_ = roll(def.chance.evaluate(state.vocab, ectx))
		if not pass_: continue

		if def.limit == Limit.OncePerAbility and ability != null: Effect.set_add(ability.fired, p.rule_key)
		if def.limit == Limit.OncePerTurn: Effect.set_add(owner.fired_this_turn, p.rule_key)

		if def.timing == Timing.AfterAbility and ability != null and state.open_abilities.has(ability):
			ability.deferred.append(p)
			continue
		responses.append_array(expand_response(p, e.id))
	return responses

## A reaction's response steps, with Self = owner and the event's facts as variables.
func expand_response(p: PendingReaction, cause: int) -> Array:
	var e: GameEvent = p.event
	var target: Entity = state.get_entity(e.target)
	var sc := StepContext.new()
	sc.state = state
	sc.self_ = p.owner
	sc.effect_source = p.effect_source
	sc.target = target
	sc.event = e
	sc.aim = Aim.new(target.pos if target != null else p.owner.pos, Dirs.between(p.owner.pos, target.pos) if target != null else Dirs.NONE)
	sc.tags = {}
	sc.cause = cause
	sc.depth = e.depth + 1
	sc.vars = p.vars()
	return Step.expand_list(p.def.response, sc)

static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var d: Dictionary = a.duplicate()
	for k in b: d[k] = b[k]
	return d

## No draw at ≥ 1 or ≤ 0; previews count uncertain rolls as failing (a chance reaction, a crit), except an attack's hit (RollHitEffect).
func roll(chance: float) -> bool:
	if chance >= 1.0: return true
	if chance <= 0.0: return false
	if mode != EvalMode.Execute: return false
	return state.rng.chance(chance)
