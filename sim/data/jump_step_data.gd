class_name JumpStepData
extends StepData

func to_core(_c: AssetConverter) -> Step:
	return JumpStep.new()
