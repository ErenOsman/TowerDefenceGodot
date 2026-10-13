class_name PushStepData
extends StepData

## [Slot("OnHit")]
var distance: Formula = Formula.new("1")
var pull: bool = false
var on: int = StepTarget.Target

func to_core(_c: AssetConverter) -> Step:
	var s := PushStep.new()
	s.distance = distance
	s.pull = pull
	s.on = on
	return s
