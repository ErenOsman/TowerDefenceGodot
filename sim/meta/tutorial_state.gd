class_name TutorialState
extends RefCounted
## Where the player stands with the tutorial.

const NotStarted := 0
const Done := 1
const Skipped := 2

const NAMES := ["NotStarted", "Done", "Skipped"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
