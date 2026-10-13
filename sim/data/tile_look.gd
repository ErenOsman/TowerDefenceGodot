class_name TileLook
extends RefCounted
## A level's look (Tiles — Design, "Look: the visual and props layers"): each tile's ground piece, automatic from
## terrain, build and road unless the visual layer names one, and the props layer's pieces. Engine-free, so the
## editor, the offline checks and the board all agree.
## Port notes: C# string[,] / TilePiece[,] grids are Arrays of columns, grid[x][y]; out parameters become a
## returned Dictionary ({"ok", "id", "turns"}); Frame's (x, y, piece) tuples are [x, y, TilePiece] Arrays.

const Directions := "NESW"

## Reads a layer cell: "." (none), "id" (default facing) or "id-N|E|S|W".
## Returns {"ok": false} when it is not one of those, else {"ok": true, "id": id or null, "turns": n}.
static func try_parse(cell) -> Dictionary:
	var result := {"ok": true, "id": null, "turns": 0}
	if cell == null or cell == "" or cell == ".": return result
	var nm: String = cell
	var dash: int = cell.rfind("-")
	if dash > 0:
		if dash != cell.length() - 2 or not Directions.contains(cell[dash + 1]): return {"ok": false, "id": null, "turns": 0}
		result["turns"] = Directions.find(cell[dash + 1])
		nm = cell.substr(0, dash)
	if nm.is_empty() or not _id_chars(nm): return {"ok": false, "id": null, "turns": 0}
	result["id"] = nm
	return result

## Letters, digits and _ only (C# char.IsLetterOrDigit; uncased Unicode letters such as CJK are not recognised here).
static func _id_chars(s: String) -> bool:
	for c in s:
		if c == "_" or (c >= "0" and c <= "9") or c.to_upper() != c.to_lower(): continue
		return false
	return true

static func _grid(width: int, height: int, fill) -> Array:
	var g := []
	for x in width:
		var col := []
		for y in height: col.append(fill.call() if fill is Callable else fill)
		g.append(col)
	return g

## A layer's cells: rows top first, cells separated by spaces; grid[x][y] with y up (row 0 is the top row); null where none.
static func cells(layer: Array, width: int, height: int) -> Array:
	var c := _grid(width, height, null)
	if layer == null: return c
	var row := 0
	while row < height and row < layer.size():
		var parts: PackedStringArray = (layer[row] if layer[row] != null else "").split(" ", false)
		var x := 0
		while x < width and x < parts.size():
			c[x][height - 1 - row] = parts[x]
			x += 1
		row += 1
	return c

## A layer sized to the map with one cell set ("." clears it): rows top first, cells separated by spaces, missing
## cells filled with ".". (x, y) with y up.
static func with_cell(layer: Array, width: int, height: int, x: int, y: int, cell) -> Array[String]:
	var c := cells(layer, width, height)
	if x >= 0 and x < width and y >= 0 and y < height: c[x][y] = "." if cell == null or cell == "" else cell
	return _rows(c, width, height)

## A layer resized to the map (cells kept where they still fit, new ones "."); an empty layer stays empty.
static func resized(layer: Array, width: int, height: int) -> Array[String]:
	if layer == null or layer.is_empty():
		var empty: Array[String] = []
		return empty
	return _rows(cells(layer, width, height), width, height)

## The cell at (x, y) with y up, or "." when the layer has none.
static func cell_at(layer: Array, width: int, height: int, x: int, y: int) -> String:
	if x < 0 or x >= width or y < 0 or y >= height: return "."
	var c = cells(layer, width, height)[x][y]
	return c if c != null else "."

static func _rows(c: Array, width: int, height: int) -> Array[String]:
	var rows: Array[String] = []
	for row in height:
		var parts := PackedStringArray()
		for x in width:
			var v = c[x][height - 1 - row]
			parts.append(v if v != null else ".")
		rows.append(" ".join(parts))
	return rows

## How many quarter turns clockwise make a piece with these sides (at its default facing) show the wanted sides;
## -1 when no turn does. Sides are letters of NESW in any order.
static func fit(piece_sides, wanted) -> int:
	var piece := _mask(piece_sides)
	var want := _mask(wanted)
	for t in 4:
		if _turn(piece, t) == want: return t
	return -1

## The road's joined sides on a tile as NESW letters ("" for a road of one tile), or null when there is no road.
static func road_sides(level: LevelAsset, x: int, y: int):
	var lrud = level.road_at(x, y) # L R U D, "C" for one tile, "" for none
	if lrud == null or lrud == "": return null
	if lrud == "C": return ""
	var out := ""
	for c in lrud:
		out += "N" if c == "U" else ("E" if c == "R" else ("S" if c == "D" else "W"))
	return out

## Every tile's ground piece (grid[x][y] of TilePiece): the visual layer's override, else automatic (a road piece on
## a road, a terrain's edge piece where it borders another terrain, a build variant on a build tile, else a terrain
## variant). tiles is every Tile a layer may name (Game Rules); a tile no piece fits is left empty (problems says where).
static func ground(level: LevelAsset, tiles: Array, problems = null) -> Array:
	var s := level.size
	var width := s.x
	var height := s.y
	var pieces := _grid(width, height, func(): return TilePiece.new())
	var visual := cells(level.visual, width, height)
	var by_id := _by_id(tiles)
	var roads := []
	if tiles != null:
		for t in tiles:
			if t != null and t.kind == TileKind.Road: roads.append(t)
	for x in width:
		for y in height:
			if visual[x][y] != null and visual[x][y] != ".":
				var parsed := try_parse(visual[x][y])
				if parsed.ok and parsed.id != null and by_id.has(parsed.id):
					pieces[x][y] = TilePiece.new(by_id[parsed.id], parsed.turns)
				elif problems != null:
					problems.append("visual (%d, %d): '%s' is not a Tile" % [x, y, visual[x][y]])
				continue
			var auto := _automatic(level, roads, x, y)
			if auto != null: pieces[x][y] = auto
			elif problems != null:
				var t := level.terrain_at(x, y)
				problems.append("(%d, %d): no piece fits (%s)" % [x, y, t.get_id() if t != null else "no terrain"])
	return pieces

## The props layer's pieces (grid[x][y] of TilePiece; tile null where it has none).
static func props(level: LevelAsset, tiles: Array, problems = null) -> Array:
	var s := level.size
	var width := s.x
	var height := s.y
	var pieces := _grid(width, height, func(): return TilePiece.new())
	var c := cells(level.props, width, height)
	var by_id := _by_id(tiles)
	for x in width:
		for y in height:
			if c[x][y] == null or c[x][y] == ".": continue
			var parsed := try_parse(c[x][y])
			if parsed.ok and parsed.id != null and by_id.has(parsed.id):
				pieces[x][y] = TilePiece.new(by_id[parsed.id], parsed.turns)
			elif problems != null:
				problems.append("props (%d, %d): '%s' is not a Tile" % [x, y, c[x][y]])
	return pieces

## The board's frame (Tiles — Design, "Look"): on the map's outer tiles, a Border piece facing out (one with one
## side along the edges, one with two sides on the four corner tiles), turned to fit. Border pieces are thin skins
## on their tile's outer edge (the slab's cut side), drawn over the ground piece. Empty when the kit has no Border
## pieces. Returns an Array of [x, y, TilePiece].
static func frame(level: LevelAsset, tiles: Array) -> Array:
	var result := []
	var borders := []
	if tiles != null:
		for t in tiles:
			if t != null and t.kind == TileKind.Border: borders.append(t)
	if borders.is_empty(): return result
	var s := level.size
	var w := s.x
	var h := s.y
	var put := func(x: int, y: int, facing: String) -> void:
		for b in borders:
			var t := fit(b.sides, facing)
			if t >= 0:
				result.append([x, y, TilePiece.new(b, t)])
				return
	if w < 2 or h < 2: return result # a map one tile wide has no room for corners
	for x in range(1, w - 1):
		put.call(x, h - 1, "N")
		put.call(x, 0, "S") # corner tiles get the corner piece only
	for y in range(1, h - 1):
		put.call(w - 1, y, "E")
		put.call(0, y, "W")
	put.call(0, h - 1, "NW")
	put.call(w - 1, h - 1, "NE")
	put.call(w - 1, 0, "ES")
	put.call(0, 0, "SW")
	return result

# ------------------------------------------------------------------ helpers

static func _automatic(level: LevelAsset, roads: Array, x: int, y: int) -> TilePiece:
	var terrain := level.terrain_at(x, y)
	var road = road_sides(level, x, y)
	# a road shows only on ground walkers stand on: over a chasm (flyers' paths) the tile shows its terrain
	if road != null and (terrain == null or terrain.stand == Standing.Everyone):
		for r in roads:
			var t := fit(r.sides, road)
			if t >= 0: return TilePiece.new(r, t)
	if terrain == null: return null

	var edges := _edges(level, terrain, x, y)
	if edges.length() > 0 and terrain.edge_tiles != null:
		for e in terrain.edge_tiles:
			if e == null: continue
			var t := fit(e.sides, edges)
			if t >= 0: return TilePiece.new(e, t)

	var source: Array = terrain.build_tiles if level.build_at(x, y) and terrain.build_tiles != null and terrain.build_tiles.size() > 0 else terrain.tiles
	var variants := []
	if source != null:
		for v in source:
			if v != null: variants.append(v)
	if variants.is_empty(): return null
	var pick := _hash(x, y)
	return TilePiece.new(variants[pick % variants.size()], (pick / variants.size()) % 4) # a fixed variant and turn per tile

## The sides where a tile borders a different terrain (the map's outside counts as the same).
static func _edges(level: LevelAsset, terrain: TerrainAsset, x: int, y: int) -> String:
	var sides := ""
	var s := level.size
	if y + 1 < s.y and level.terrain_at(x, y + 1) != terrain: sides += "N"
	if x + 1 < s.x and level.terrain_at(x + 1, y) != terrain: sides += "E"
	if y > 0 and level.terrain_at(x, y - 1) != terrain: sides += "S"
	if x > 0 and level.terrain_at(x - 1, y) != terrain: sides += "W"
	return sides

static func _by_id(tiles: Array) -> Dictionary:
	var by_id := {}
	if tiles != null:
		for t in tiles:
			if t != null and not by_id.has(t.get_id()): by_id[t.get_id()] = t
	return by_id

static func _mask(sides) -> int:
	var m := 0
	for c in (sides if sides != null else ""):
		var i := Directions.find(c.to_upper())
		if i >= 0: m |= 1 << i
	return m

## Turns a side mask clockwise by quarter turns (N→E→S→W).
static func _turn(mask: int, turns: int) -> int:
	for i in turns: mask = ((mask << 1) | (mask >> 3)) & 0xF
	return mask

## C# int arithmetic wraps at 32 bits (unchecked).
static func _i32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

static func _hash(x: int, y: int) -> int:
	var h := _i32(_i32(x * 73856093) ^ _i32(y * 19349663))
	h = _i32(h ^ (h >> 13))
	h = _i32(h * 0x5bd1e995)
	return (h ^ (h >> 15)) & 0x7fffffff
