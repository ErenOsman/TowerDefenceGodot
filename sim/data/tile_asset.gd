class_name TileAsset
extends ContentAsset
## One piece of the map kit (Tiles — Design, "Look: the visual and props layers"): what a level's visual and props
## layers name by id, turned with "-N/E/S/W". Looks only: the rules never read it.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## What the layers write: letters, digits and _ only, e.g. road_corner. Empty falls back to the asset name.
var id: String = ""
## The model placed on the tile (a Unity map-kit prefab path).
var view: String = ""
## Ground, Road, Edge, Prop or Border (see TileKind).
var kind: int = TileKind.Ground
## At its default facing (north = toward the top row), the sides that matter, as letters of NESW.
var sides: String = ""

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id
