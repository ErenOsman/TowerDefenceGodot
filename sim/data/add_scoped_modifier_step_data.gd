class_name AddScopedModifierStepData
extends StepData

var modifier: Modifier = Modifier.new()
var on: int = StepTarget.Self

func to_core(_c: AssetConverter) -> Step:
	var s := AddScopedModifierStep.new()
	s.modifier = modifier
	s.on = on
	return s
