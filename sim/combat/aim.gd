class_name Aim
extends RefCounted
## One use's aim: a tile, the caster-to-aim direction and, for walks, the path.

var tile: Vector2i
var dir: Vector2i
## Array of Vector2i, or null (not a walk).
var path = null

func _init(p_tile: Vector2i = Vector2i.ZERO, p_dir: Vector2i = Vector2i.ZERO) -> void:
	tile = p_tile
	dir = p_dir

static func at(caster_pos: Vector2i, p_tile: Vector2i) -> Aim:
	return Aim.new(p_tile, Dirs.between(caster_pos, p_tile))

## Aim.walk(p1, p2, ...) or Aim.walk([p1, p2, ...]).
static func walk(...p_path: Array) -> Aim:
	var tiles: Array = Array(p_path[0]).duplicate() if p_path.size() == 1 and p_path[0] is Array else p_path.duplicate()
	var a := Aim.new(tiles[tiles.size() - 1] if tiles.size() > 0 else Vector2i.ZERO, Dirs.NONE)
	a.path = tiles
	return a
