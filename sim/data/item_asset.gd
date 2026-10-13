class_name ItemAsset
extends ContentAsset
## An equipped item: a rule source (modifiers, replacements, reactions) active while equipped.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Array of Modifier.
var modifiers: Array = []
## Array of ReplacementData.
var replacements: Array = []
## Array of ReactionAsset.
var reactions: Array = []
