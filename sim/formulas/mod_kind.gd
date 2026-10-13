class_name ModKind
extends RefCounted
## How a Modifier combines (see ModifierPipeline).

const Flat := 0
const PctAdd := 1
const PctMult := 2
const Override := 3

const NAMES := ["Flat", "PctAdd", "PctMult", "Override"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
