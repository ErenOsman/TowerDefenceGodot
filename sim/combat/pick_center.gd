class_name PickCenter
extends RefCounted
## Where a Pick looks for units: around the step's owner (Self) or the ability's aim (Aim).

const Self := 0
const Aim := 1

const NAMES := ["Self", "Aim"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
