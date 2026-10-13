class_name Relation
extends RefCounted
## How two entities stand to each other (GameState.relation).

const Ally := 0
const Enemy := 1
const Neutral := 2

const NAMES := ["Ally", "Enemy", "Neutral"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
