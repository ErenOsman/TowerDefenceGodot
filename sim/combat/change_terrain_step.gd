class_name ChangeTerrainStep
extends Step
## Changes the terrain of the aimed tile, or of the step's area around it (Tiles — Design): fill a chasm, drop a
## bridge, break a wall. only_on limits it to tiles of those terrains (names); build
## can switch building on or off there. Units that can no longer stand fall or are pushed (the terrain decides).

var terrain: TerrainDef
var area: PatternDef = PatternDef.single()
## Terrain names the change applies to (e.g. "chasm"); empty = every tile of the area.
var only_on: Array = []
var build: int = BuildChange.Keep

func expand(c: StepContext) -> Array:
	if terrain == null or c.aim == null: return []
	var dir: Vector2i = Dirs.cardinal_between(c.self_.pos, c.aim.tile)
	var tiles: Array = []
	for t in Targeting.tiles(c.state, c.self_, area if area != null else PatternDef.single(), c.aim.tile, dir, c.tags):
		tiles.append(t[0])
	var e := ChangeTerrainEffect.new()
	e.tiles = tiles
	e.terrain = terrain
	e.only_on = only_on if only_on != null else []
	e.build = build
	return [c.init(e)]
