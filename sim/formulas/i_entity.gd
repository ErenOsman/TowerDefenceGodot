class_name IEntity
extends RefCounted
## What a formula can read from an entity. Implemented by the game (combat entities):
## extend IEntity, assign `name` (do not redeclare it) and override stat().

var name: String = ""

## The final value of a stat, stat modifiers included.
func stat(_stat: String) -> float:
	push_error("abstract")
	return 0.0
