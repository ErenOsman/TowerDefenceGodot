class_name Subject
extends RefCounted
## Who a formula reads: the effect's source, its target, or the owner (Self).

const Source := 0
const Target := 1
const Self := 2

const NAMES := ["Source", "Target", "Self"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
