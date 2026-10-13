class_name StatusAsset
extends ContentAsset
## A status as data (Create > Game > Status); AssetConverter.status() makes its StatusDef.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Stable ID that rules and saves refer to (HasStatus, Remove Status by name…). Empty falls back to the asset name.
var id: String = ""
## The name players see.
var display_name: String = ""
## Player-facing text for tooltips.
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## Optional effect attached to the holder while the status is on it (a Unity prefab path, "" for none).
var loop_vfx: String = ""

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

## Control tags (Stunned, Rooted…), Debuff / Buff, Hidden, Permanent.
var tags: Array[String] = []
var stacking: int = Stacking.Stack
var max_stacks: int = 99

## -1 is permanent. Turns count down at the owner's TurnEnded, Rounds at RoundEnded.
var duration: int = -1
var duration_unit: int = DurationUnit.Turns

## Array of Modifier.
var modifiers: Array = []
## Array of ReplacementData.
var replacements: Array = []
## Array of ReactionAsset.
var reactions: Array = []

## [Slot("Passive")]
var passive_condition: Condition = Condition.new()
## Non-empty: the rules apply to the entities this filter covers instead of the holder. [Slot("TargetFilter")]
var aura: Condition = Condition.new()
## Non-empty: the status is a shield with this pool, evaluated when applied. [Slot("OnHit", optional)]
var shield_pool: Formula = Formula.new()

## Applier: charm (the applier's team). Fixed: the team below.
var team_override: int = TeamOverride.None
var fixed_team: int = 0

## Kept when the holder dies.
var persists_through_death: bool = false
