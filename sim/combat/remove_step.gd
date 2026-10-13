class_name RemoveStep
extends Step
## Takes an entity out of the battle without a death: no OnDeath or OnKill.

var reason: String = "removed"
var on: int = StepTarget.Self

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := RemoveEffect.new()
	e.target_id = t.id
	e.reason = reason
	return [c.init(e)]
