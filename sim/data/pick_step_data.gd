class_name PickStepData
extends StepData

## Where it looks for units, around the Center.
var area: PatternDef = PatternDef.diamond("3")
var center: int = PickCenter.Self
## [Slot("TargetFilter")]
var filter: Condition = Condition.new()
## How many units it picks (fewer when fewer are there). [Slot("Attack")]
var count: Formula = Formula.new("1")
## Which ones: Default = the nearest to the centre; Random, Weakest, First…
var instinct: InstinctDef = InstinctDef.new()
## Run on each picked unit, as the Target.
var steps: StepList = StepList.new()

func to_core(c: AssetConverter) -> Step:
	var s := PickStep.new()
	s.area = area if area != null else PatternDef.diamond("3")
	s.center = center
	s.filter = filter
	s.count = count
	s.instinct = instinct if instinct != null else InstinctDef.new()
	s.steps = c.steps(steps)
	return s
