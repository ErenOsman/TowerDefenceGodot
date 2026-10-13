class_name LifeState
extends RefCounted
## Whether an entity is alive, a corpse (Dead) or gone (Removed).

const Alive := 0
const Dead := 1
const Removed := 2

const NAMES := ["Alive", "Dead", "Removed"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
