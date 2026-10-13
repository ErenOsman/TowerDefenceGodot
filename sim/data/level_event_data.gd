class_name LevelEventData
extends RefCounted
## A scripted action in a round of a wave. Fields not used by its kind are ignored.

var round: int = 1
var kind: int = LevelEventKind.SpawnEnemies

# Spawn Enemies
var enemy: EntityAsset = null
var count: int = 1
## -1 = a random path for each enemy.
var path: int = -1
## Random tiles of the path instead of its first tile.
var random_tiles: bool = false
var facing: int = SpawnFacing.AlongPath

# Give Energy
var energy: int = 0

# Show Message
var message: String = ""

# Change Terrain
var terrain: TerrainAsset = null
var tiles: Array[Vector2i] = []
var build: int = BuildChange.Keep
