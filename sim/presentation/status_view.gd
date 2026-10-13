class_name StatusView
extends RefCounted
## One status as the UI shows it (visible instances only, grouped).

var def: StatusDef = null
var name: String = ""
var stacks: int = 0
## Longest remaining duration; -1 = permanent.
var turns_left: int = 0
## Damage its shield pools still absorb (0 for statuses without a shield).
var shield: int = 0
## The display names of who applied it (each once; empty when nobody did, e.g. a level event).
var applied_by: Array = []  # of String
