class_name TileKind
extends RefCounted
## What a map piece is for: a tile's ground, a road on it, a terrain's rim where it meets another, a prop standing on
## it, or the board's frame (Border: the slab's cut side, on the ring of tiles just outside the map).

const Ground := 0
const Road := 1
const Edge := 2
const Prop := 3
const Border := 4

const NAMES := ["Ground", "Road", "Edge", "Prop", "Border"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
