class_name LevelAsset
extends ContentAsset
## A level as data: its map, paths, bases, hand cap, energy and waves (Game Overview — Level data, Tiles — Design).
## The map is three text layers of the same size, one character per tile, top row first: terrain
## (a character per terrain, named in terrain_keys), build ('+' where towers may be placed) and road
## (a box-drawing character per tile: the sides the road joins). Paths are the enemy routes, tiles in walking
## order. Coordinates: x grows to the right, y grows upward, (0, 0) is the bottom-left tile — the last row of each layer.
## Characters are one-character Strings.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

## Layer characters: ground, wall and chasm (by convention) in the terrain layer, a build tile, no road.
const Ground := "."
const Wall := "#"
const Chasm := "~"
const Buildable := "+"
const NoRoad := "."

## Stable level ID stored in saves (progress, unlocks), e.g. "meadow-1". Empty falls back to the asset name (fragile).
var id: String = ""
## The name players see in level select; empty = the asset name.
var display_name: String = ""
## Player-facing text for level select.
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## Background music (a Unity audio clip path); "" = the game scene's default track.
var music: String = ""

## C# Id: the id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

## C# DisplayName: the display name, else the asset name.
func get_display_name() -> String:
	return name if display_name.is_empty() else display_name

## The terrain layer, top row first: one character per tile, each named in terrain_keys. Its rows set the map's size.
var terrain: Array[String] = ["............", "............", "............", "............"]
## What each terrain character stands for: Array of TerrainKey.
var terrain_keys: Array = []
## The build layer, top row first: '+' where towers may be placed, '.' elsewhere.
var build: Array[String] = []
## The road layer, top row first: the road on each tile as a box-drawing character of the sides it joins.
var road: Array[String] = []
## The visual layer (looks only), top row first, cells separated by spaces: '.' automatic, or a Tile id (turned with -N/-E/-S/-W).
var visual: Array[String] = []
## The props layer (looks only), top row first, cells separated by spaces: '.' nothing, or a Tile id.
var props: Array[String] = []

## The enemy routes: Array of PathData.
var paths: Array = []
## Array of BaseData.
var bases: Array = []
## Units on the map when the level starts: Array of StartingUnitData.
var starting_units: Array = []

## How many towers of the hand come into the level.
var hand_cap: int = 4
## The level's own towers (Array of TowerAsset); when set, they replace the player's hand.
var fixed_hand: Array = []
## Speech-bubble lines before round 1, the first time the level is played.
var intro: SequenceAsset = null

var start_energy: int = 165
var energy_per_round: int = 33

## Array of WaveData.
var waves: Array = []

# ------------------------------------------------------------------ size and layers

## The map's size (C# Size tuple): the terrain layer's widest row (x) and its row count (y).
var size: Vector2i:
	get:
		var width := 0
		for row in terrain: width = maxi(width, row.length())
		return Vector2i(width, terrain.size())

func inside(t: Vector2i) -> bool:
	var s := size
	return t.x >= 0 and t.y >= 0 and t.x < s.x and t.y < s.y

## A layer's character at (x, y) (y = 0 the last row); empty outside its rows.
static func char_at(layer: Array, x: int, y: int, empty: String) -> String:
	if layer == null: return empty
	var row := layer.size() - 1 - y
	if row < 0 or row >= layer.size() or layer[row] == null or x < 0 or x >= layer[row].length(): return empty
	return layer[row][x]

## A copy of a layer with one character changed, sized to the map (missing rows and columns filled).
func with_char(layer: Array, x: int, y: int, c: String, fill: String) -> Array[String]:
	var s := size
	var rows: Array[String] = []
	for r in s.y:
		var old: String = layer[r] if layer != null and r < layer.size() and layer[r] != null else ""
		rows.append(old.substr(0, s.x) if old.length() >= s.x else old.rpad(s.x, fill))
	var at := s.y - 1 - y
	if at >= 0 and at < s.y and x >= 0 and x < s.x:
		rows[at] = rows[at].substr(0, x) + c + rows[at].substr(x + 1)
	return rows

## The terrain layer's character at (x, y).
func terrain_char_at(x: int, y: int) -> String:
	return char_at(terrain, x, y, Ground)

## The Terrain asset a terrain character stands for, or null when terrain_keys do not name it.
func terrain_of(c: String) -> TerrainAsset:
	for k in terrain_keys:
		if k != null and not k.symbol.is_empty() and k.symbol[0] == c: return k.terrain
	return null

## The tile's terrain asset, or null when its character has no key.
func terrain_at(x: int, y: int) -> TerrainAsset:
	return terrain_of(terrain_char_at(x, y))

## Who may stand on the tile at (x, y): its terrain's rule (unknown terrain: everyone).
func standing_at(x: int, y: int) -> int:
	var t := terrain_at(x, y)
	return t.stand if t != null else Standing.Everyone

## Whether towers may be built on the tile at (x, y).
func build_at(x: int, y: int) -> bool:
	return char_at(build, x, y, ".") == Buildable

## The name of the tile's terrain at (x, y), for messages.
func terrain_name_at(x: int, y: int) -> String:
	var t := terrain_at(x, y)
	if t == null: return "'%s'" % terrain_char_at(x, y)
	return t.name if t.display_name.is_empty() else t.display_name

## The sides the road joins on the tile at (x, y), as letters L R U D ("LR", "LU"…); "C" for a road of one tile,
## "" for none (null for a character that is not a road piece).
func road_at(x: int, y: int):
	return sides_of(char_at(road, x, y, NoRoad))

## Whether the road on the tile at (x, y) reaches the given side (L, R, U, D).
func road_reaches(x: int, y: int, side: String) -> bool:
	var r = road_at(x, y)
	return r != null and r.contains(side)

## A path's tiles in walking order (a tile repeats where it loops); empty for no such path.
func tiles_of(path: int) -> Array:
	if path >= 0 and path < paths.size() and paths[path] != null: return paths[path].tiles
	return []

# ------------------------------------------------------------------ building a map

## Sets the terrain and build layers from sketch rows (top row first; '.' ground, '+' buildable ground,
## '#' wall, '~' chasm; anything else ground), names the three terrains in terrain_keys and draws the road
## from the paths (rebuild_road). For builders and tests.
func set_tiles(rows: Array, ground_asset: TerrainAsset, wall_asset: TerrainAsset, chasm_asset: TerrainAsset) -> void:
	var height := rows.size()
	var width := 0
	for r in rows: width = maxi(width, r.length() if r != null else 0)
	var t: Array[String] = []
	var b: Array[String] = []
	for r in height:
		var tc := ""
		var bc := ""
		for x in width:
			var c: String = rows[r][x] if rows[r] != null and x < rows[r].length() else Ground
			tc += Wall if c == Wall else (Chasm if c == Chasm else Ground)
			bc += Buildable if c == Buildable else "."
		t.append(tc)
		b.append(bc)
	terrain = t
	build = b
	terrain_keys = [TerrainKey.of(Ground, ground_asset), TerrainKey.of(Wall, wall_asset), TerrainKey.of(Chasm, chasm_asset)]
	rebuild_road()

## Draws the road layer from the paths: each tile a path passes gets the sides it comes in and leaves by
## (a path that starts on the map's edge, leading inward, comes in from that edge). Replaces the layer.
func rebuild_road() -> void:
	var s := size
	var sides := {} # Vector2i → {side letter: true}
	for p in paths.size():
		var path := tiles_of(p)
		for i in path.size():
			if not inside(path[i]): continue
			if not sides.has(path[i]): sides[path[i]] = {}
			var set_: Dictionary = sides[path[i]]
			set_["C"] = true # on the road even with no neighbour on it (a part of one tile); dropped where sides join
			if i > 0 and touch(path[i - 1], path[i]): set_[side_of(path[i - 1] - path[i])] = true
			if i + 1 < path.size() and touch(path[i], path[i + 1]): set_[side_of(path[i + 1] - path[i])] = true
			if i == 0 and i + 1 < path.size() and touch(path[i], path[i + 1]):
				var behind: Vector2i = path[i] - (path[i + 1] - path[i])
				if not inside(behind): set_[side_of(behind - path[i])] = true # comes in from outside the map
	var rows: Array[String] = []
	for r in s.y:
		var chars := ""
		for x in s.x:
			var at := Vector2i(x, s.y - 1 - r)
			chars += char_of("".join(sides[at].keys())) if sides.has(at) else NoRoad
		rows.append(chars)
	road = rows

# ------------------------------------------------------------------ road characters

const ROAD_CHARS := [
	["LR", "─"], ["UD", "│"], ["RD", "┌"], ["LD", "┐"], ["RU", "└"], ["LU", "┘"],
	["LRD", "┬"], ["LRU", "┴"], ["RUD", "├"], ["LUD", "┤"], ["LRUD", "┼"],
	["L", "╴"], ["R", "╶"], ["U", "╵"], ["D", "╷"], ["C", "•"],
]

static func _sorted(sides: String) -> String:
	var out := ""
	for c in "LRUDC":
		if sides.contains(c): out += c
	return out

## The box-drawing character for a set of sides ("LR" → ─, "LU" → ┘); '.' for none, "C" (a road of one tile) → •.
static func char_of(sides) -> String:
	var key := _sorted(sides if sides != null else "")
	if key.length() > 1: key = key.replace("C", "")
	if key.is_empty(): return NoRoad
	for pair in ROAD_CHARS:
		if _sorted(pair[0]) == key: return pair[1]
	return "?"

## The sides a road character joins (─ → "LR"); "" for '.', null for a character that is not a road piece.
static func sides_of(c: String):
	if c == NoRoad or c == " ": return ""
	for pair in ROAD_CHARS:
		if pair[1] == c: return _sorted(pair[0])
	return null

## Whether two tiles share an edge.
static func touch(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

## The side letter of a neighbour's offset: L, R, U (up, +y), D (down).
static func side_of(d: Vector2i) -> String:
	return "L" if d.x < 0 else ("R" if d.x > 0 else ("U" if d.y > 0 else "D"))
