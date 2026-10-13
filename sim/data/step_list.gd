class_name StepList
extends RefCounted
## A list of steps edited in the Inspector. The wrapper exists so one drawer can give every
## step list (ability steps, onHit, If branches, reaction responses) a type picker.

## [SerializeReference] StepData items (null entries are kept: the validator reports them).
var items: Array = []

static func of(...steps: Array) -> StepList:
	var l := StepList.new()
	l.items = Vocabulary._flatten(steps).duplicate()
	return l
