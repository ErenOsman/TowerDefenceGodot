class_name LogicOp
extends RefCounted
## Operator of a LogicNode.

const And := 0
const Or := 1

const NAMES := ["And", "Or"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
