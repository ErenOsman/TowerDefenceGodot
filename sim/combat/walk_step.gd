class_name WalkStep
extends Step
## Walk along the aim's path: one StepEffect per tile, each its own queue item.

func expand(c: StepContext) -> Array:
	if c.aim == null or c.aim.path == null: return []
	var out: Array = []
	var from: Vector2i = c.self_.pos
	for to in c.aim.path:
		var e := StepEffect.new()
		e.target_id = c.self_.id
		e.from = from
		e.to = to
		out.append(c.init(e))
		from = to
	return out
