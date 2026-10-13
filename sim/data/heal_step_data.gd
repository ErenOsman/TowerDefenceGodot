class_name HealStepData
extends StepData

## [Slot("OnHit")]
var amount: Formula = Formula.new("ActionPower")
var tags: Array[String] = []
var on: int = StepTarget.Target

func to_core(_c: AssetConverter) -> Step:
	var s := HealStep.new()
	s.amount = amount
	s.tags = tags.duplicate() if tags != null else []
	s.on = on
	return s
