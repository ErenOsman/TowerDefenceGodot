class_name HealStep
extends Step

var amount: Formula = Formula.new("ActionPower")
var tags: Array = []
var on: int = StepTarget.Target

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := HealEffect.new()
	e.target_id = t.id
	e.amount = amount
	return [c.init(e, tags)]
