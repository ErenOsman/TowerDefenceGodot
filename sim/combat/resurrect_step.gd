class_name ResurrectStep
extends Step
## Returns a Dead entity to Alive on its death tile (or the nearest free tile) with HP from the formula.

var hp: Formula = Formula.new("Target.MaxHp * 0.5")
var on: int = StepTarget.Target

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := ResurrectEffect.new()
	e.target_id = t.id
	e.hp = hp
	return [c.init(e)]
