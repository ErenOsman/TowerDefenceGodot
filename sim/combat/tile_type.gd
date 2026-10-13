class_name TileType
extends RefCounted
## How a tile looks to tools and placeholder views, from its terrain and roads: Wall (nobody stands there),
## Chasm (flyers only), Path (a road passes), Buildable (towers may be placed), else Ground. The rules read
## the terrain itself (TerrainDef), never this.

const Ground := 0
const Path := 1
const Wall := 2
const Chasm := 3
const Buildable := 4

const NAMES := ["Ground", "Path", "Wall", "Chasm", "Buildable"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
