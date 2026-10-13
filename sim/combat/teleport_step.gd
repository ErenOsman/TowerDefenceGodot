class_name TeleportStep
extends Step

var on: int = StepTarget.Self

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null or c.aim == null: return []
	var e := TeleportEffect.new()
	e.target_id = t.id
	e.to = c.aim.tile
	return [c.init(e)]
