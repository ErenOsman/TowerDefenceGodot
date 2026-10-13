class_name SpawnData
extends RefCounted
## One enemy in one round of a wave; several enemies are several entries.

var round: int = 1
var enemy: EntityAsset = null
var path: int = 0
## The direction it starts facing: along its path (the way the path goes from where it appears) or a set direction.
var facing: int = SpawnFacing.AlongPath
