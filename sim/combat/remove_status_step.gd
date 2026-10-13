class_name RemoveStatusStep
extends Step
## Removes a status by name (all of it, or `stacks` stacks), or cleanses by tag (newest first,
## skipping Permanent; limit 0 = all).

var by: int = RemoveBy.Name
var status_name: String = ""

## By name: how many stacks to take off (OnHit formula, floored); empty removes the status entirely.
var stacks: Formula = Formula.new()

var tag: String = Tags.Debuff
var limit: int = 0
var on: int = StepTarget.Target

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	if t == null: return []
	var e := RemoveStatusEffect.new()
	e.target_id = t.id
	if by == RemoveBy.Tag:
		e.tag = tag
		e.limit = limit
	else:
		e.status_name = status_name
		e.stacks = stacks
	return [c.init(e)]
