class_name TeleportStepData
extends StepData

var on: int = StepTarget.Self

func to_core(_c: AssetConverter) -> Step:
	var s := TeleportStep.new()
	s.on = on
	return s
