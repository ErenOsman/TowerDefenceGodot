class_name ReplaceAction
extends RefCounted
## What a ReplacementRule does to the effect it intercepts.

const Cancel := 0
const Redirect := 1
const Replace := 2

const NAMES := ["Cancel", "Redirect", "Replace"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
