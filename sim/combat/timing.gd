class_name Timing
extends RefCounted
## When a reaction's response runs: after the queue item, or after the whole ability.

const AfterItem := 0
const AfterAbility := 1

const NAMES := ["AfterItem", "AfterAbility"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
