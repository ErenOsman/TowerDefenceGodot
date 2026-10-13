class_name RequirementKind
extends RefCounted
## What opens a level: Previous (the entry before it must be won; default), Open (from the start), Levels (the listed levels: all, or any one).

const Previous := 0
const Open := 1
const Levels := 2

const NAMES := ["Previous", "Open", "Levels"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
