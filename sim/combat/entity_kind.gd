class_name EntityKind
extends RefCounted
## Unit, Object, Hazard or Environment decides occupancy, turns and default targeting.
## Godot owns the names Object and Environment, so those members are Object_ and Environment_ (NAMES keeps the C# names).

const Unit := 0
const Object_ := 1
const Hazard := 2
const Environment_ := 3

const NAMES := ["Unit", "Object", "Hazard", "Environment"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
