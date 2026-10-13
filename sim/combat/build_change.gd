class_name BuildChange
extends RefCounted
## What a Change Terrain does to the build flag of the tiles it changes.

const Keep := 0
const On := 1
const Off := 2

const NAMES := ["Keep", "On", "Off"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
