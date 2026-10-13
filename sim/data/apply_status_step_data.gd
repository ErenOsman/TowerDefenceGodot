class_name ApplyStatusStepData
extends StepData

var status: StatusAsset = null
## [Slot("OnHit")]
var stacks: Formula = Formula.new("1")
## How long it lasts, e.g. 2 or Self.Duration; empty uses the status's own duration. -1 is permanent.
## [Slot("OnHit", optional: true)]
var duration: Formula = Formula.new()
var on: int = StepTarget.Target
## Tags for this application only: Hidden (the UI does not show it), Permanent (cleanses skip it)…
var add_tags: Array[String] = []

func to_core(c: AssetConverter) -> Step:
	var s := ApplyStatusStep.new()
	s.status = c.status(status)
	s.stacks = stacks
	s.duration = duration
	s.on = on
	s.add_tags = add_tags.duplicate() if add_tags != null else []
	return s
