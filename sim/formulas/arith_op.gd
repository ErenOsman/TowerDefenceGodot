class_name ArithOp
extends RefCounted
## Operator of an ArithNode.

const Add := 0
const Sub := 1
const Mul := 2
const Div := 3
const Mod := 4

const NAMES := ["Add", "Sub", "Mul", "Div", "Mod"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
