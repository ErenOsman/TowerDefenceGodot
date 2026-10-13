class_name SequenceSpeaker
extends RefCounted
## Who speaks a line.

const Base := 0
const Princess := 1

const NAMES := ["Base", "Princess"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
