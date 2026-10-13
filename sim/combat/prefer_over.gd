class_name PreferOver
extends RefCounted
## What a preference scores: the candidate's target (Target), the formula summed over the units the aim's area hits (AreaSum), or how many it hits (AreaCount).

const Target := 0
const AreaSum := 1
const AreaCount := 2

const NAMES := ["Target", "AreaSum", "AreaCount"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
