class_name JumpStep
extends Step
## Straight to the aim tile, over anything in between: resolves like Teleport, tagged Jump.

func expand(c: StepContext) -> Array:
	if c.aim == null: return []
	var e := TeleportEffect.new()
	e.target_id = c.self_.id
	e.to = c.aim.tile
	return [c.init(e, ["Jump"])]
