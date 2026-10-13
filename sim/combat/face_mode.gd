class_name FaceMode
extends RefCounted
## How a Face step turns an entity: TowardAim (the aimed tile), Direction (a set direction), AlongPath (its own path at its tile).

const TowardAim := 0
const Direction := 1
const AlongPath := 2

const NAMES := ["TowardAim", "Direction", "AlongPath"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
