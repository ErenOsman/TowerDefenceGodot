class_name DeathRecord
extends RefCounted
## Kept on a Dead entity: who killed it and where, for kill credit, corpses and resurrection.

var killer: int = -1
var tile: Vector2i = Vector2i.ZERO

func clone() -> DeathRecord:
	var d := DeathRecord.new()
	d.killer = killer
	d.tile = tile
	return d
