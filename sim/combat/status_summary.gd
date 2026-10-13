class_name StatusSummary
extends RefCounted
## One status as the UI shows it: every visible instance of a definition on one entity, with total
## stacks and the longest remaining duration (-1 if any instance is permanent). instances lists
## the details (who applied each, its stacks and duration).

var def: StatusDef = null
var stacks: int = 0
var turns_left: int = 0
## Array of StatusInstance.
var instances: Array = []

var name: String:
	get: return def.name
