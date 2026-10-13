class_name ModDirection
extends RefCounted
## Outgoing modifiers come from an effect's source, incoming ones from its target.

const Outgoing := 0
const Incoming := 1

const NAMES := ["Outgoing", "Incoming"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
