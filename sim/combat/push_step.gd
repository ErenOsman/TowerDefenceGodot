class_name PushStep
extends Step
## Push (or pull) the target. Inside an attack the move runs after all chains of the batch.

## OnHit; floored, at least 0.
var distance: Formula = Formula.new("1")
var pull: bool = false
var on: int = StepTarget.Target

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	# away from the aim tile; when the target stands on it, away from the step's owner
	var origin: Vector2i = c.aim.tile if c.aim != null and c.aim.tile != t.pos else c.self_.pos
	var e := PushEffect.new()
	e.target_id = t.id
	e.distance = distance
	e.pull = pull
	e.origin = origin
	return [c.init(e)]
