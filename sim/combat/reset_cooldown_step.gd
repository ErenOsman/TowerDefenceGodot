class_name ResetCooldownStep
extends Step
## Frees an ability from its cooldown (e.g. "ready again on a kill"), or shortens it. Ability null
## = every ability of the unit. Turns empty = a full reset (held cooldowns included); a number
## shortens turn cooldowns by that much and leaves held ones held.

var ability: AbilityDef
var on: int = StepTarget.Self
## [Slot("OnHit")]
var turns: Formula = Formula.new()

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := ResetCooldownEffect.new()
	e.target_id = t.id
	e.which = ability
	e.turns = turns
	return [c.init(e)]
