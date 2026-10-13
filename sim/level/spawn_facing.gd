class_name SpawnFacing
extends RefCounted
## The direction a spawned enemy starts facing.

const AlongPath := 0
const Up := 1
const Down := 2
const Left := 3
const Right := 4

const NAMES := ["AlongPath", "Up", "Down", "Left", "Right"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
