class_name ResurrectStepData
extends StepData

## [Slot("OnHit")]
var hp: Formula = Formula.new("Target.MaxHp * 0.5")
var on: int = StepTarget.Target

func to_core(_c: AssetConverter) -> Step:
	var s := ResurrectStep.new()
	s.hp = hp
	s.on = on
	return s
