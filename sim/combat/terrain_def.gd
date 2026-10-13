class_name TerrainDef
extends RefCounted
## What a tile's ground does for the rules (Tiles — Design): who stands on it, whether it stops straight
## projectiles and line of sight, its tags. Ground, Wall and Chasm are built in; other terrains are content.
## display_name: assigning stores the raw field (_display_name); reading gives the C# DisplayName (name when empty).

var name: String = ""
var _display_name: String = ""
var display_name: String:
	get: return name if _display_name.is_empty() else _display_name
	set(v): _display_name = "" if v == null else v
var description: String = ""
var stand: int = Standing.Everyone
var blocks_projectiles: bool = false
var blocks_sight: bool = false
var tags: Array = []
var when_unstandable: int = WhenUnstandable.Die

func has_tag(tag: String) -> bool:
	return tags.has(tag)

## Whether a unit may stand here (flying units also on Flyers terrain).
func can_stand(flying: bool) -> bool:
	return stand == Standing.Everyone or (stand == Standing.Flyers and flying)

static func _make(p_name: String, p_display: String, p_stand: int, p_blocks: bool, p_tags: Array, p_when: int) -> TerrainDef:
	var t := TerrainDef.new()
	t.name = p_name
	t.display_name = p_display
	t.stand = p_stand
	t.blocks_projectiles = p_blocks
	t.blocks_sight = p_blocks
	t.tags = p_tags
	t.when_unstandable = p_when
	return t

## Walkable ground: everyone stands on it.
static var Ground: TerrainDef = _make("ground", "Ground", Standing.Everyone, false, ["Solid"], WhenUnstandable.Die)

## Nobody stands on it; it stops straight projectiles and line of sight; a unit caught by one is pushed out.
static var Wall: TerrainDef = _make("wall", "Wall", Standing.Nobody, true, ["Solid"], WhenUnstandable.Push)

## Only flyers stand over it; shots and sight pass; a walker on a tile that becomes one falls.
static var Chasm: TerrainDef = _make("chasm", "Chasm", Standing.Flyers, false, [], WhenUnstandable.Die)

## Alias of reading display_name (the C# DisplayName), for code written against a get_display_name() convention.
func get_display_name() -> String:
	return display_name
