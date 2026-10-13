class_name TerrainAsset
extends ContentAsset
## A kind of ground for a level's tiles (Tiles — Design): who stands on it, whether it stops shots and sight,
## its tags, and its look. Ground ('.'), Wall ('#') and Chasm ('~') by convention; used in a level through its legend.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Stable ID rules use (conditions, Change Terrain), e.g. "bridge". Empty falls back to the asset name.
var id: String = ""
## The name players see; empty = the asset name.
var display_name: String = ""
var description: String = ""

## Who may stand on it and walk over it.
var stand: int = Standing.Everyone
## Straight shots (rays, lines) stop here, like at a wall.
var blocks_projectiles: bool = false
## Line of sight stops here, like at a wall.
var blocks_sight: bool = false
## For conditions and abilities, e.g. Solid, Liquid.
var tags: Array[String] = []
## A unit on a tile that becomes this terrain, when it cannot stand on it: dies, or is pushed.
var when_unstandable: int = WhenUnstandable.Die

## The tile's look (art only): its ground pieces (Array of TileAsset); one is picked by a fixed hash of the position.
var tiles: Array = []
## The ground pieces on build tiles (empty: the plain ones).
var build_tiles: Array = []
## Rim pieces where it borders another terrain, chosen by the bordering sides and turned to fit. Empty: no rim.
var edge_tiles: Array = []

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id
