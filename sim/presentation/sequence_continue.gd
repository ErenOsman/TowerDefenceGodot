class_name SequenceContinue
extends RefCounted
## When a line gives way to the next: Click, Seconds (after `seconds`), Event (when `wait_for` happens).

const Click := 0
const Seconds := 1
const Event := 2

const NAMES := ["Click", "Seconds", "Event"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
