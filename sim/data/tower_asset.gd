class_name TowerAsset
extends ContentAsset
## A tower type (Archer): the entity it fights as and its energy cost. The player owns individual
## towers of a type (OwnedTower), each with its own tower ID; saves refer to the type by Id.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Stable type ID stored in saves, e.g. "archer". Empty falls back to the asset name (fragile).
var id: String = ""
## The name players see; empty = the entity's display name.
var display_name: String = ""
## Player-facing text for tooltips.
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""

## The tower's entity: a Unit with footing OffPath.
var entity: EntityAsset = null

## Energy to place it. Selling refunds cost × 0.5 × Hp / MaxHp.
var cost: int = 3

## Upgrades — Design: the level ladder, Array of TowerLevelData (the step to level 2 first); max level = size + 1.
var levels: Array = []

## Not serialized: the type's forms (FormAsset whose tower is this one) in content order, linked by ContentLibrary.
var forms: Array = []

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

## C# DisplayName: the display name, else the entity's, else the asset name.
func get_display_name() -> String:
	if not display_name.is_empty(): return display_name
	if entity != null and not entity.display_name.is_empty(): return entity.display_name
	return name
