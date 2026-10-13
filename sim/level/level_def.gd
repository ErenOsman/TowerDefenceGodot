class_name LevelDef
extends RefCounted
## A level is data: the map and everything scheduled on it.

var name: String = ""
var width: int = 10
var height: int = 10
## Each tile's terrain where it is not Ground (walls, chasms, content terrains): Vector2i → TerrainDef.
var terrain: Dictionary = {}
## Where towers may be placed (a set: Vector2i → true); empty = anywhere off the paths.
var buildable: Dictionary = {}
## Each path's tiles in walking order (see PathDef); a tile repeats where the path loops. Array of Array[Vector2i].
var paths: Array = []
var bases: Array = []  # of BaseDef
var starting_units: Array = []  # of StartingUnitDef
## How many towers of the hand come into the level (4–5).
var hand_cap: int = 4
var start_energy: int = 0
var energy_per_round: int = 0
var waves: Array = []  # of WaveDef

func build_grid() -> BattleGrid:
	var grid := BattleGrid.new(width, height)
	grid.buildable = buildable.duplicate()
	for t in terrain: grid.set_terrain(t, terrain[t])
	for tiles in paths: grid.add_path(Array(tiles).duplicate())
	return grid
