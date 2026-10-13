class_name TerrainKey
extends RefCounted
## A terrain character of a level and the Terrain asset it stands for.

## One character, used in the terrain layer.
var symbol: String = "."
var terrain: TerrainAsset = null

static func of(p_symbol: String, p_terrain: TerrainAsset) -> TerrainKey:
	var k := TerrainKey.new()
	k.symbol = p_symbol
	k.terrain = p_terrain
	return k
