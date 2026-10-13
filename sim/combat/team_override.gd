class_name TeamOverride
extends RefCounted
## A status can change its owner's effective team while active (charm, confusion).

const None := 0
const Applier := 1
const Fixed := 2

const NAMES := ["None", "Applier", "Fixed"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
