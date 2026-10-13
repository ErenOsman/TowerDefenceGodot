class_name StartingSide
extends RefCounted
## Whose side a unit the level starts with is on.

const Ally := 0
const Neutral := 1
const Enemy := 2

const NAMES := ["Ally", "Neutral", "Enemy"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
