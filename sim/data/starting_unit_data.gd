class_name StartingUnitData
extends RefCounted
## A unit on the map when the level starts.

var entity: EntityAsset = null
var tile: Vector2i = Vector2i.ZERO
var side: int = StartingSide.Neutral
## Enemies: the road it walks (-1: the road through its tile).
var path: int = -1
## The direction it starts facing (enemies: along their road by default).
var facing: int = SpawnFacing.AlongPath
