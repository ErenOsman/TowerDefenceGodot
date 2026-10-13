class_name SpawnEntry
extends RefCounted
## One enemy spawned in one round of a wave (rounds counted from the wave's start, 1 = its first). More enemies, more entries.

var round: int = 1
var enemy: EntityDef = null
var path: int = 0
var facing: int = SpawnFacing.AlongPath
