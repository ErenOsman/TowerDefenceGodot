class_name LevelEventDef
extends RefCounted
## A scripted action in a round of a wave. Not a pipeline event such as HitResolved.

var round: int = 1
var kind: int = LevelEventKind.SpawnEnemies

# SpawnEnemies
var enemy: EntityDef = null
var count: int = 1
## -1 = a random path for each enemy.
var path: int = -1
## True: random tiles of the path; false: the path's first tile.
var random_tiles: bool = false
var facing: int = SpawnFacing.AlongPath

# GiveEnergy
var energy: int = 0

# ShowMessage
var message: String = ""

# ChangeTerrain (Tiles — Design)
var terrain: TerrainDef = null
var tiles: Array = []
var build: int = BuildChange.Keep
