class_name ScopedModifier
extends RefCounted
## A modifier that lasts for one ability; EndAbility removes it.

## C# default(EntityId) = 0.
var owner: int = 0
var modifier: Modifier = null

func _init(p_owner: int = 0, p_modifier: Modifier = null) -> void:
	owner = p_owner
	modifier = p_modifier
