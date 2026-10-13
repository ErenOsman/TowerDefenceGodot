class_name SpawnAt
extends RefCounted
## Where a spawned entity appears.

const AimTile := 0
const Target := 1
const Self := 2

const NAMES := ["AimTile", "Target", "Self"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
