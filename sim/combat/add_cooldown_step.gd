class_name AddCooldownStep
extends Step
## Puts abilities on (more) cooldown, e.g. "using this damage spell makes the others wait a turn".
## Ability null = every ability of the unit except the one being cast. Held cooldowns stay held.

var ability: AbilityDef
var on: int = StepTarget.Self
## [Slot("OnHit")]
var turns: Formula = Formula.new("1")

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := AddCooldownEffect.new()
	e.target_id = t.id
	e.which = ability
	e.turns = turns
	e.casting = c.ability.def if c.ability != null else null
	return [c.init(e)]
