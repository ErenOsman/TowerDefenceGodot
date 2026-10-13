class_name Footing
extends RefCounted
## Which tiles an entity may stand on (besides never on walls and chasms): enemies keep to their
## own path (OnPath), towers keep off every path (OffPath), anything else may stand anywhere.

const Any := 0
const OnPath := 1
const OffPath := 2

const NAMES := ["Any", "OnPath", "OffPath"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
