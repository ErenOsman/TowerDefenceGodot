class_name Standing
extends RefCounted
## Who may stand on (and walk over) a terrain.

const Everyone := 0
const Flyers := 1
const Nobody := 2

const NAMES := ["Everyone", "Flyers", "Nobody"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
