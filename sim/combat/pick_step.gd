class_name PickStep
extends Step
## Chooses up to count units in an area by an instinct when it runs (Instinct — Design, Pick),
## then runs its steps on each, as their Target, in the instinct's order. Default instinct:
## the nearest to the centre. Example: Volley hits 3 random enemies in range.

var area: PatternDef = PatternDef.diamond("3")
var center: int = PickCenter.Self
## [Slot("TargetFilter")]
var filter: Condition = Condition.new()
## [Slot("Attack")]
var count: Formula = Formula.new("1")
var instinct: InstinctDef = InstinctDef.new()
## Array of Step.
var steps: Array = []

func expand(c: StepContext) -> Array:
	var e := PickEffect.new()
	e.step = self
	e.target_id = c.target.id if c.target != null else -1
	return [c.init(e)]
