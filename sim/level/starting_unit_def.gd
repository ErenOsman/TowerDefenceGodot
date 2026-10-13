class_name StartingUnitDef
extends RefCounted
## A unit on the map when the level starts (Level data — starting units).

var entity: EntityDef = null
var tile: Vector2i = Vector2i.ZERO
var side: int = StartingSide.Ally
## Enemies: the road it walks (-1: the road through its tile).
var path: int = -1
var facing: int = SpawnFacing.AlongPath
