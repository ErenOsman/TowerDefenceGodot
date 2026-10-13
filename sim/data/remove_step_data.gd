class_name RemoveStepData
extends StepData

var reason: String = "removed"
var on: int = StepTarget.Self

func to_core(_c: AssetConverter) -> Step:
	var s := RemoveStep.new()
	s.reason = reason
	s.on = on
	return s
