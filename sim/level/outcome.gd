class_name Outcome
extends RefCounted
## How a level stands.

const Running := 0
const Won := 1
const Lost := 2

const NAMES := ["Running", "Won", "Lost"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
