class_name Round
extends RefCounted
## Rounding applied once, at a slot's output — never inside a formula.

const None := 0
const Floor := 1
const FloorMin0 := 2
const Nearest := 3

const NAMES := ["None", "Floor", "FloorMin0", "Nearest"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
