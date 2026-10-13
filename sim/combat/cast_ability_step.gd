class_name CastAbilityStep
extends Step
## Casts another ability with its own instance (e.g. a counter or overwatch shot).

var ability: AbilityDef

## The entity whose tile the new ability aims at.
var aim_at: int = StepTarget.Target

## Ignore aim_at: the cast ability's instinct chooses among its valid aims (e.g. "shoot the weakest enemy in range"). No aim, no cast.
var aim_by_instinct: bool = false

func expand(c: StepContext) -> Array:
	var aim: Aim
	if aim_by_instinct:
		aim = Instinct.choose(c.state, c.self_, ability)
		if aim == null: return []
	else:
		var t: Entity = c.resolve(aim_at)
		if t == null: return []
		aim = Aim.at(c.self_.pos, t.pos)
	var cast := CastAbilityEffect.new()
	cast.def = ability
	cast.caster = c.self_.id
	cast.aim = aim
	c.init(cast)
	cast.ability = null # a new root ability gets its own instance
	cast.source = c.self_.id
	if c.event != null: cast.tags[Tags.Reaction] = true
	return [cast]
