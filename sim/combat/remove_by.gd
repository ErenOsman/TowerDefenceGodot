class_name RemoveBy
extends RefCounted
## How a Remove Status step chooses: by status name, or a cleanse by tag.

const Name := 0
const Tag := 1

const NAMES := ["Name", "Tag"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
