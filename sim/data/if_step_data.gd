class_name IfStepData
extends StepData

## [Slot("Step")]
var condition: Condition = Condition.new()
var then: StepList = StepList.new()
var otherwise: StepList = StepList.new()

func to_core(c: AssetConverter) -> Step:
	var s := IfStep.new()
	s.condition = condition
	s.then = c.steps(then)
	s.else_ = c.steps(otherwise)
	return s
