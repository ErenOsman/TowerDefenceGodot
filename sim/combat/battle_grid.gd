class_name BattleGrid
extends RefCounted
## The map: size, each tile's terrain, build tiles and paths. Part of the battle state: terrain can change
## during a battle (Tiles — Design), so every state copy has its own terrain (paths are still shared).

var width: int
var height: int
var _terrain: Array = []

## Where towers may be placed; empty = anywhere a tower may stand. A Dictionary used as a set: {Vector2i: true}.
var buildable: Dictionary = {}
## Array of PathDef.
var paths: Array = []

func _init(p_width: int = 0, p_height: int = 0) -> void:
	width = p_width
	height = p_height
	_terrain.resize(maxi(0, p_width * p_height))

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

## The terrain of a tile (Ground unless set); outside the map, Wall.
func terrain_at(p: Vector2i) -> TerrainDef:
	if not in_bounds(p): return TerrainDef.Wall
	var t = _terrain[p.y * width + p.x]
	return TerrainDef.Ground if t == null else t

## Sets a tile's terrain (null: Ground). Outside the map does nothing.
func set_terrain(p: Vector2i, t: TerrainDef) -> void:
	if in_bounds(p): _terrain[p.y * width + p.x] = t

## Out of bounds or terrain that stops straight projectiles (a wall).
func blocks_projectiles(p: Vector2i) -> bool:
	return terrain_at(p).blocks_projectiles

## Out of bounds or terrain that stops line of sight (a wall).
func blocks_sight(p: Vector2i) -> bool:
	return terrain_at(p).blocks_sight

## Whether a unit may stand on the tile's terrain (flyers also over chasms); occupancy and paths aside.
func can_stand_on(p: Vector2i, flying: bool) -> bool:
	return in_bounds(p) and terrain_at(p).can_stand(flying)

## Out of bounds or terrain not everyone stands on (walls, chasms): blocks walking, pushes and placing.
func blocks_movement(p: Vector2i) -> bool:
	return not can_stand_on(p, false)

func is_path(p: Vector2i) -> bool:
	for path in paths:
		if path.contains(p): return true
	return false

func tile(p: Vector2i) -> int:
	var t := terrain_at(p)
	if t.stand == Standing.Nobody: return TileType.Wall
	if t.stand == Standing.Flyers: return TileType.Chasm
	if is_path(p): return TileType.Path
	return TileType.Buildable if buildable.has(p) else TileType.Ground

## Whether a tower may be placed here: the level marks no buildable tiles, or this is one.
func can_build(p: Vector2i) -> bool:
	return buildable.is_empty() or buildable.has(p)

func path(id: int) -> PathDef:
	return paths[id] if id >= 0 and id < paths.size() else null

## Adds a path from its tiles in walking order and returns it: add_path(p1, p2, ...) or add_path([p1, p2, ...]).
func add_path(...tiles: Array) -> PathDef:
	var p := PathDef.new()
	p.id = paths.size()
	p.tiles = Array(tiles[0]).duplicate() if tiles.size() == 1 and tiles[0] is Array else tiles.duplicate()
	paths.append(p)
	return p

## A copy with its own terrain and build tiles; paths do not change during a battle, so copies share them.
func clone() -> BattleGrid:
	var g := BattleGrid.new(width, height)
	g._terrain = _terrain.duplicate()
	g.buildable = buildable.duplicate()
	g.paths = paths.duplicate()
	return g
