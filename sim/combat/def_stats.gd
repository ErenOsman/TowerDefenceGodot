class_name DefStats
extends IEntity
## C# AbilityText.DefStats (a nested class; a global class here, one per file).
## An entity that is not on the board yet (a tower in the hand): its definition's base stats.

var _def: EntityDef

func _init(p_def: EntityDef) -> void:
	_def = p_def
	var dn = p_def.get("display_name")
	name = dn if dn is String and dn != "" else p_def.name

## The definition whose base stats these are.
var def: EntityDef:
	get: return _def

func stat(p_stat: String) -> float:
	if p_stat == "Hp": p_stat = "MaxHp" # full health before it exists
	return float(_def.base_stats.get(p_stat, 0.0))
