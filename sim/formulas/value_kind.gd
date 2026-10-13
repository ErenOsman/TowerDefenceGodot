class_name ValueKind
extends RefCounted
## The type of a formula's value. Booleans are 1/0.

const Number := 0
const Bool := 1

const NAMES := ["Number", "Bool"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
