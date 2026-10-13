class_name RollPer
extends RefCounted
## Whether a reaction's chance is rolled per hit or once per attack.

const Hit := 0
const Attack := 1

const NAMES := ["Hit", "Attack"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
