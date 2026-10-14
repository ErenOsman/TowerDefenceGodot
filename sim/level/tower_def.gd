class_name TowerDef
extends RefCounted
## One tower in a level's hand: an individual the player owns (its own tower ID, lasting across
## levels and saves, unlike the battle-only EntityId) and its type. Two archers are two TowerDefs.

var id: String = ""
## The player's name for it; empty = the type's name.
var custom_name: String = ""
var type: TowerType = null

var entity: EntityDef:
	get: return type.entity if type != null else null
var cost: int:
	get: return type.cost if type != null else 0
## The form it fights as (Workshop), or null for the default form.
var form: FormDef:
	get: return type.form if type != null else null
var name: String:
	get:
		if custom_name != "": return custom_name
		if type != null and type.name != "": return type.name  # C#: type?.name ?? id (null name → id)
		return id
