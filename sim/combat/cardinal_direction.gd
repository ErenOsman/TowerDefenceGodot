class_name CardinalDirection
extends RefCounted
## A direction on the map as designers name it: Up is +y (towards the first row of the map text), Down is -y.

const Up := 0
const Down := 1
const Left := 2
const Right := 3

const NAMES := ["Up", "Down", "Left", "Right"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
