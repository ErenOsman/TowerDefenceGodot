class_name TilePiece
extends RefCounted
## A map piece on a tile: which one and how far it is turned (quarter turns clockwise from its default facing, north).
## A C# struct: compare with equals(), not ==.

var tile: TileAsset = null
var turns: int = 0

func _init(p_tile: TileAsset = null, p_turns: int = 0) -> void:
	tile = p_tile
	turns = ((p_turns % 4) + 4) % 4

func equals(o) -> bool:
	return o is TilePiece and o.tile == tile and o.turns == turns

func _to_string() -> String:
	return "(%s, %d)" % [tile.get_id() if tile != null else "null", turns]
