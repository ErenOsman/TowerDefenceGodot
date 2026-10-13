class_name RemoveStatusStepData
extends StepData

## Name: every instance of one status (Permanent too). Tag: a cleanse, newest first, skipping Permanent.
var by: int = RemoveBy.Name
## By Name: the status to remove.
var status: StatusAsset = null
## By Name: how many stacks to take off (e.g. 1); empty removes the status entirely. [Slot("OnHit", optional: true)]
var stacks: Formula = Formula.new()
## By Tag: e.g. Debuff (cleanse) or Buff (dispel).
var tag: String = Tags.Debuff
## By Tag: how many to remove at most; 0 = all.
var limit: int = 0
var on: int = StepTarget.Target

func to_core(_c: AssetConverter) -> Step:
	var s := RemoveStatusStep.new()
	s.by = by
	s.status_name = status.get_id() if status != null else "" # C# null
	s.stacks = stacks
	s.tag = tag
	s.limit = limit
	s.on = on
	return s

func _display_name() -> String:
	return "Cleanse" if by == RemoveBy.Tag else "RemoveStatus"
