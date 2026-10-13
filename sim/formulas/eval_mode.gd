class_name EvalMode
extends RefCounted
## Execute uses the RNG; previews pin rand() to its bounds and never touch the RNG.

const Execute := 0
const PreviewMin := 1
const PreviewMax := 2

const NAMES := ["Execute", "PreviewMin", "PreviewMax"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
