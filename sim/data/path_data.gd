class_name PathData
extends RefCounted
## One enemy route: its tiles in walking order.

var tiles: Array[Vector2i] = []

static func of(...p_tiles: Array) -> PathData:
	var p := PathData.new()
	p.tiles.assign(Vocabulary._flatten(p_tiles))
	return p
