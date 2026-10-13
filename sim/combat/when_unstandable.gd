class_name WhenUnstandable
extends RefCounted
## What happens to a unit standing on a tile that becomes this terrain when it cannot stand on it (Tiles — Design).

const Die := 0
const Push := 1

const NAMES := ["Die", "Push"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
