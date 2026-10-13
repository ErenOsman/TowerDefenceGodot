class_name PassiveAsset
extends ContentAsset
## A passive as data (Create > Game > Passive); AssetConverter.passive() makes its PassiveDef.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Shown in the right bar and info popups; empty uses the asset name.
var display_name: String = ""
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## Not shown to players: rules that only make something else work (e.g. a hazard's mechanics).
var hidden: bool = false

## [Slot("Passive")]
var condition: Condition = Condition.new()
## [Slot("Passive")]
var off_condition: Condition = Condition.new()
## Array of Modifier.
var modifiers: Array = []
## Array of ReplacementData.
var replacements: Array = []
## Array of ReactionAsset.
var reactions: Array = []

## Non-empty: the rules apply to the entities this filter covers instead of the owner. [Slot("TargetFilter")]
var aura: Condition = Condition.new()
