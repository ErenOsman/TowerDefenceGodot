class_name ApplyStatusStep
extends Step

var status: StatusDef
var stacks: Formula = Formula.new("1")

## How long it lasts (e.g. 2, Self.Duration); empty uses the status's own duration. -1 is permanent.
var duration: Formula = Formula.new()

var on: int = StepTarget.Target

## Tags for this application only, e.g. Hidden (the UI skips it) or Permanent (cleanses skip it).
var add_tags: Array = []

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := ApplyStatusEffect.new()
	e.target_id = t.id
	e.status = status
	e.stacks = stacks
	e.duration = duration
	e.add_tags = add_tags
	return [c.init(e, Tags.union(status.tags, add_tags).keys())]
