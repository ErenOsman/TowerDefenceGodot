class_name Step
extends RefCounted
## A step of an ability (or a reaction's response): expands into effects when it runs.

## Returns an Array of Effect.
func expand(_c: StepContext) -> Array:
	push_error("abstract")
	return []

static func expand_all(steps, c: StepContext) -> Array:
	var out: Array = []
	if steps == null: return out
	for step in steps:
		out.append_array(step.expand(c))
	return out

static func expand_list(steps, c: StepContext) -> Array:
	return expand_all(steps, c)
