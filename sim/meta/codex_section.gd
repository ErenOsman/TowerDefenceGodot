class_name CodexSection
extends RefCounted
## The Codex's sections; a discovery key is the section plus the content id.

const Towers := 0
const Enemies := 1
const Statuses := 2
const Tips := 3

const NAMES := ["Towers", "Enemies", "Statuses", "Tips"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
