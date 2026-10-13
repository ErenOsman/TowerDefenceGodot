class_name CompareOp
extends RefCounted
## Operator of a CompareNode.

const Lt := 0
const Le := 1
const Gt := 2
const Ge := 3
const Eq := 4
const Ne := 5

const NAMES := ["Lt", "Le", "Gt", "Ge", "Eq", "Ne"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
