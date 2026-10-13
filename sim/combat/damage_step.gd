class_name DamageStep
extends Step

## OnHit slot; floored at the output.
var amount: Formula = Formula.new("ActionPower")
var tags: Array = []
var on: int = StepTarget.Target

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := DamageEffect.new()
	e.target_id = t.id
	e.amount = amount
	return [c.init(e, tags)]
