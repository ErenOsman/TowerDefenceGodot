class_name FaceStep
extends Step
## Turns an entity toward the aim tile, in a set direction or along its path (only when facing is enabled).

var on: int = StepTarget.Self
var mode: int = FaceMode.TowardAim
var direction: int = CardinalDirection.Down

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := FaceEffect.new()
	e.target_id = t.id
	match mode:
		FaceMode.Direction:
			e.direction = Directions.to_dir(direction)
		FaceMode.AlongPath:
			e.along_path = true
		_:
			if c.aim == null: return []
			e.toward = c.aim.tile
	return [c.init(e)]
