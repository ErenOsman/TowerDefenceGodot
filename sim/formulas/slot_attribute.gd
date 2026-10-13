class_name SlotAttribute
extends RefCounted
## Declares which evaluation point a Formula or Condition field belongs to, by ContextSpec name
## ("Targeting", "Attack", "OnHit", "Mitigation", "Modifier", "CastGate", "TargetFilter",
## "ReactionTrigger", "Passive", "Replacement", "Step", "Instinct"). C# attribute; GDScript has none, so
## the data layer keeps its own field → SlotAttribute table.

var spec: String
## Empty is allowed (it means a default, e.g. the status's own duration): no error for it.
var optional: bool

func _init(p_spec: String = "", p_optional: bool = false) -> void:
	spec = p_spec
	optional = p_optional
