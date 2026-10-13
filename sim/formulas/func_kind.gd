class_name FuncKind
extends RefCounted
## Built-in function of a FuncNode.

const Min := 0
const Max := 1
const Clamp := 2
const Floor := 3
const Round := 4

const NAMES := ["Min", "Max", "Clamp", "Floor", "Round"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
