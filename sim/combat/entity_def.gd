class_name EntityDef
extends RefCounted
## The read-only definition an entity is created from.
## display_name: assigning stores the raw field (_display_name); reading gives the C# DisplayName (name when empty).

## The stable ID (the asset's id; the asset name when it has none).
var name: String = ""

## The name players see; empty = name.
var _display_name: String = ""
var display_name: String:
	get: return name if _display_name.is_empty() else _display_name
	set(v): _display_name = "" if v == null else v

## Player-facing text for tooltips.
var description: String = ""

var kind: int = EntityKind.Unit

## Inherent tags: Undead, Beast, Flying…
var tags: Array = []

## Base value per stat (MaxHp, Initiative, Str…): String → float.
var base_stats: Dictionary = {}

## Line patterns with stopAtFirstBlocker stop at entities with this set.
var blocks_projectiles: bool = true

## Array of AbilityDef.
var abilities: Array = []
## Array of PassiveDef.
var passives: Array = []

## A summon with this set is removed when its summoner dies.
var die_with_summoner: bool = false

var footing: int = Footing.Any

## Upgrades: a levelled copy (TowerLevels.apply) points at the definition it was copied from, so lookups by
## definition (AssetConverter.asset_of: model, icon, presentation) still find the content asset. Null otherwise.
var levelled_from: EntityDef = null

func stat(p_stat: String, value) -> EntityDef:
	base_stats[p_stat] = float(value)
	return self

## Unit and Object occupy the blocking layer; Hazards overlay any number per tile.
var is_blocking: bool:
	get: return kind == EntityKind.Unit or kind == EntityKind.Object_

## Alias of reading display_name (the C# DisplayName), for code written against a get_display_name() convention.
func get_display_name() -> String:
	return display_name
