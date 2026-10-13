class_name PassiveInstance
extends RefCounted
## A passive on an entity: the shared definition and whether its condition currently holds.

var def: PassiveDef = null
var active: bool = true

func clone() -> PassiveInstance:
	var p := PassiveInstance.new()
	p.def = def
	p.active = active
	return p
