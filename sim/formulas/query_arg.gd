class_name QueryArg
extends RefCounted
## How a query's argument is interpreted: None (Target.IsAlive), Name (Target.HasStatus(Poison)), Subject (Self.DistanceTo(Target)).

const None := 0
const Name := 1
const Subject := 2

const NAMES := ["None", "Name", "Subject"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
