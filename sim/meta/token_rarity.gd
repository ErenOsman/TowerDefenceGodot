class_name TokenRarity
extends RefCounted
## How rare a token kind is (Workshop — Design, TokenAsset.rarity): a hint for the token header's order and the
## drop tables; no rule reads it. Godot-first (the Unity repo has no Workshop content yet; see docs/Implementation Notes.md).

const Common := 0
const Rare := 1

const NAMES := ["Common", "Rare"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
