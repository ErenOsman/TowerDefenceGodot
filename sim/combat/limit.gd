class_name Limit
extends RefCounted
## How often a reaction may fire.

const None := 0
const OncePerAbility := 1
const OncePerTurn := 2

const NAMES := ["None", "OncePerAbility", "OncePerTurn"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
