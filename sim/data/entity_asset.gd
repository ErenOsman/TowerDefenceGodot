class_name EntityAsset
extends ContentAsset
## An entity definition: kind, tags, base stats, abilities and passives. Spawn steps and battle setup read it.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Stable ID that rules and saves refer to. Empty falls back to the asset name.
var id: String = ""
## The name players see.
var display_name: String = ""
## Player-facing text for tooltips.
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## The full figure on its plinth (a Unity sprite path; "" = render the model).
var miniature: String = ""
## The model prefab shown on the board (a Unity prefab path; "" = a placeholder shape).
var view: String = ""
## 0 = automatic HP bar height; else tiles over the model's centre.
var plate_offset: float = 0.0

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

var kind: int = EntityKind.Unit

## Inherent tags: Undead, Beast, Flying…
var tags: Array[String] = []

## Base stats (MaxHp, Initiative, Str…). Values are exact decimals as text. Array of StatValue.
var stats: Array = [StatValue.of("MaxHp", "100"), StatValue.of("Initiative", "0"), StatValue.of("Speed", "1")]

## OnPath: enemies. OffPath: towers. Any: everything else.
var footing: int = Footing.Any

## Line patterns that stop at the first blocker stop at this entity.
var blocks_projectiles: bool = true

## Array of AbilityAsset.
var abilities: Array = []
## Array of PassiveAsset.
var passives: Array = []

## As a summon: removed when its summoner dies.
var die_with_summoner: bool = false

## Lines the base speaks the first time the player meets this unit on the board. Null: none.
var entrance: SequenceAsset = null
