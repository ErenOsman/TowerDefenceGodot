class_name RuleEntry
extends RefCounted
## One rule source as seen by a receiver: who carries it, and whether it reached the receiver as an aura.

## IRuleSource (StatusDef, PassiveDef, ItemDef or GameRules).
var source = null

## The entity carrying the source: the receiver itself, or an aura's owner.
var holder: Entity = null

var status: StatusInstance = null
var is_aura: bool = false

## Unique per receiver and source, for reaction limits.
var key: String = ""

func _init(p_source = null, p_holder: Entity = null, p_key: String = "", p_status: StatusInstance = null, p_is_aura: bool = false) -> void:
	source = p_source
	holder = p_holder
	key = p_key
	status = p_status
	is_aura = p_is_aura
