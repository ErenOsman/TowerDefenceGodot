class_name TokenAsset
extends ContentAsset
## A token kind (Workshop — Design, Content/Tokens.json): the meta currency that unlocks tower forms ("Fire Arrow —
## An arrowhead that still smoulders."). Where it drops is not stored here: it comes from the catalog's drop lists.

## Stable token ID, stored in saves (TokenWallet), e.g. "fire-arrow". Empty falls back to the asset name.
var id: String = ""
var display_name: String = ""
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## TokenRarity: Common / Rare (a hint only).
var rarity: int = TokenRarity.Common

## The id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

## The display name, else the asset name.
func get_display_name() -> String:
	return name if display_name.is_empty() else display_name
