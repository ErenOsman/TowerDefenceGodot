class_name AttackEffect
extends Effect

var step: AttackStep
var aim: Aim
## EntityId (int).
var caster: int = -1

func _kind() -> int: return EffectKind.Other

## A Dead caster may still attack (an exploding barrel's OnDeath); a Removed one may not.
func is_valid(s: GameState) -> bool:
	var c: Entity = s.get_entity(caster)
	return c != null and c.life != LifeState.Removed

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var c: Entity = s.get_entity(caster)
	var vars: Dictionary = ctx.vars(self)

	# Attack phase: Power freezes once for every hit of this attack (snapshot rule)
	var ectx: EvalContext = ctx.eval(self, c, c, null, vars)
	var power: float = step.power.evaluate(s.vocab, ectx)
	power = ModifierPipeline.apply(power, s.value_modifiers("ActionPower", c, null, tags, ability, vars), null, null, ectx.trace, "ActionPower")

	var a := AttackContext.new()
	a.id = s.next_attack_id()
	a.step = step
	a.caster = caster
	a.aim = aim
	a.power = power
	a.tags = tags.duplicate()
	a.ability = ability
	a.targets = Targeting.area_targets(s, caster, step, aim, tags)
	attack = a
	if ability != null: ability.frozen["ActionPower"] = power

	var started := GameEvent.new()
	started.type = GameEventType.AttackStarted
	started.source = caster
	started.targets = a.targets.duplicate()
	started.tags = tags.duplicate()
	started.facts["ActionPower"] = power
	ctx.write(self, started)

	var sc := StepContext.new()
	sc.state = s
	sc.ability = ability
	sc.attack = a
	sc.self_ = c
	sc.effect_source = caster
	sc.aim = aim
	sc.tags = tags.duplicate()
	sc.cause = started.id
	sc.depth = depth + 1
	a.step_context = sc

	var hits: int = maxi(1, Effect.floor_int(step.hits.evaluate(s.vocab, ectx)))
	var bounces: int = maxi(0, Effect.floor_int(step.bounces.evaluate(s.vocab, ectx)))

	for i in hits:
		var b := BatchEffect.new()
		b.targets = a.targets
		ctx.push(sc.init(b))
	if bounces > 0 and a.targets.size() > 0:
		var last: int = a.targets[a.targets.size() - 1]
		var bounce := BounceEffect.new()
		bounce.remaining = bounces
		bounce.last = last
		bounce.last_pos = s.get_entity(last).pos
		ctx.push(sc.init(bounce))
	ctx.push(sc.init(AttackEndEffect.new()))
