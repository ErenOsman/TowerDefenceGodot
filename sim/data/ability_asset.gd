class_name AbilityAsset
extends ContentAsset
## An ability as data (Create > Game > Ability); AssetConverter.ability() makes its AbilityDef.

## Hidden content number (1, 2, 3… per asset type), given by the editor when the asset is made; never changed or reused.
var number: int = 0

## Stable ID that rules and saves refer to (HasStatus, Remove Status by name…). Empty falls back to the asset name.
var id: String = ""
## The name players see.
var display_name: String = ""
## Player-facing text for tooltips.
var description: String = ""
## An art path ("art/icons/Abilities/<Name>.png"; "" for none); the presentation layer maps it (ArtPaths).
var icon: String = ""

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

var tags: Array[String] = []
## Array of Cost.
var costs: Array = []

## [Slot("CastGate")]
var cast_gate: Condition = Condition.new()
var targeting: PatternDef = PatternDef.self_()
## [Slot("TargetFilter")]
var target_filter: Condition = Condition.new()

## Aims at corpses (Dead entities) instead of living ones: resurrection, corpse explosion.
var targets_dead: bool = false
## Only tiles the caster could stand on, free (teleports).
var needs_free_tile: bool = false
## Turns until it can be cast again; 1 = no cooldown (once a turn, every turn).
var cooldown: int = 1
## After a cast it stays on cooldown until a Reset Cooldown step frees it; Cooldown's number is ignored.
var cooldown_until_reset: bool = false
## Turns it starts on cooldown when its owner appears. -1: locked until a Reset Cooldown step frees it.
var start_cooldown: int = 0
## Where it goes when nobody aims it (enemy turns, quick cast).
var instinct: InstinctDef = InstinctDef.new()

var steps: StepList = StepList.new()

## Optional: how it looks and sounds. Null: the defaults its attack-kind tag picks.
var presentation: AbilityPresentationAsset = null
## The caster turns toward the aimed tile as it casts (looks only).
var face_target_on_cast: bool = false
