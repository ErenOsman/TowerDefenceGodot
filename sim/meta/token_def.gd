class_name TokenDef
extends RefCounted
## A token kind, engine-free (Workshop — Design): the meta currency that unlocks tower forms.

## Stable ID stored in saves (TokenWallet), e.g. "fire-arrow".
var id: String = ""
## The name players see ("Fire Arrow").
var name: String = ""
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## TokenRarity (a hint only).
var rarity: int = TokenRarity.Common
