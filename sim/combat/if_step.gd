class_name IfStep
extends Step
## Step evaluation point: evaluated when it runs, then its branch runs in its place.

var condition: Condition = Condition.new()
## Array of Step.
var then: Array = []
## C# `else` (a GDScript keyword). Array of Step.
var else_: Array = []

func expand(c: StepContext) -> Array:
	var e := IfEffect.new()
	e.step = self
	e.target_id = c.target.id if c.target != null else -1
	return [c.init(e)]
