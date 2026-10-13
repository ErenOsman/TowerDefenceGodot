extends TestCase
## A level's look (TileLook): automatic pieces from terrain, build and road, hand overrides, props, and turning.

func _tile(id: String, kind: int, sides := "") -> TileAsset:
	var t := TileAsset.new()
	t.name = id
	t.id = id
	t.kind = kind
	t.sides = sides
	return t

func _terrain(n: String) -> TerrainAsset:
	var t := TerrainAsset.new()
	t.name = n
	return t

func _has_piece(frame: Array, x: int, y: int, piece: TilePiece) -> bool:
	for f in frame:
		if f[0] == x and f[1] == y and piece.equals(f[2]): return true
	return false

func test_cells_parse_ids_and_facings() -> void:
	var r := TileLook.try_parse("road_corner-E")
	assert_true(r.ok)
	assert_eq([r.id, r.turns], ["road_corner", 1])
	r = TileLook.try_parse("tree_pine")
	assert_true(r.ok)
	assert_eq([r.id, r.turns], ["tree_pine", 0])
	r = TileLook.try_parse(".")
	assert_true(r.ok)
	assert_null(r.id)
	assert_false(TileLook.try_parse("road-X").ok, "unknown direction")
	assert_false(TileLook.try_parse("stone-wall-E").ok, "a dash inside an id")

func test_layers_are_written_a_cell_at_a_time() -> void:
	var layer := TileLook.with_cell([], 3, 2, 2, 1, "tree-E")
	assert_seq(layer, [". . tree-E", ". . ."], "y up: (2, 1) is the top row's last cell")
	assert_eq(TileLook.cell_at(layer, 3, 2, 2, 1), "tree-E")
	assert_seq(TileLook.resized(TileLook.with_cell(layer, 3, 2, 2, 1, "."), 2, 2), [". .", ". ."])
	assert_eq(TileLook.resized([], 4, 4).size(), 0, "an empty layer stays empty")

func test_pieces_turn_to_fit_their_sides() -> void:
	assert_eq(TileLook.fit("NS", "NS"), 0)
	assert_eq(TileLook.fit("NS", "EW"), 1)
	assert_eq(TileLook.fit("NE", "ES"), 1, "a corner a quarter clockwise")
	assert_eq(TileLook.fit("NE", "NW"), 3)
	assert_eq(TileLook.fit("NS", "NE"), -1, "a straight never fits a corner")

func test_the_look_is_automatic_with_overrides_and_props() -> void:
	var ground := _terrain("Ground")
	var wall := _terrain("Wall")
	var chasm := _terrain("Chasm")
	var grass := _tile("grass", TileKind.Ground)
	var build_grass := _tile("build_grass", TileKind.Ground)
	var rock := _tile("rock", TileKind.Ground)
	var void_tile := _tile("void", TileKind.Ground)
	var rim := _tile("rim_1", TileKind.Edge, "N")
	var straight := _tile("road_straight", TileKind.Road, "NS")
	var corner := _tile("road_corner", TileKind.Road, "NE")
	var bridge := _tile("bridge", TileKind.Ground)
	var tree := _tile("tree", TileKind.Prop)
	ground.tiles.append(grass)
	ground.build_tiles.append(build_grass)
	wall.tiles.append(rock)
	chasm.tiles.append(void_tile)
	chasm.edge_tiles.append(rim)
	var kit := [grass, build_grass, rock, void_tile, rim, straight, corner, bridge, tree]

	var level := LevelAsset.new()
	level.name = "Level"
	level.paths.append(PathData.of(Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)))
	level.set_tiles(["..+", "...", "#~~"], ground, wall, chasm)
	level.visual.assign([". . .", ". . .", ". . bridge-E"])
	level.props.assign(["tree-S . .", ". . .", ". . ."])

	var problems := []
	var look := TileLook.ground(level, kit, problems)
	var props := TileLook.props(level, kit, problems)

	assert_eq(problems.size(), 0, str(problems))
	assert_eq(look[1][1].tile, straight, "a road joined left and right")
	assert_eq(look[1][1].turns, 1, "a straight (N–S) turned to run east–west")
	assert_true(look[2][1].equals(TilePiece.new(corner, 3)), "the road turns up: a corner (N–E) turned to join N–W")
	assert_eq(look[2][2].tile, build_grass, "the road's end has no piece in this kit: the build tile's ground")
	assert_eq(look[0][0].tile, rock, "a wall")
	assert_eq(look[1][0].tile, void_tile, "a chasm bordering ground north and a wall west: no rim fits N–W, so its plain piece")
	assert_true(look[2][0].equals(TilePiece.new(bridge, 1)), "the visual layer's override, facing east")
	assert_true(props[0][2].equals(TilePiece.new(tree, 2)), "a prop facing south")
	assert_null(props[1][1].tile)

func test_the_frame_goes_round_the_map_facing_out() -> void:
	var ground := _terrain("Ground")
	var side := _tile("edge_side", TileKind.Border, "N")
	var corner := _tile("edge_corner", TileKind.Border, "NW")
	var level := LevelAsset.new()
	level.name = "Level"
	level.set_tiles(["....", "....", "...."], ground, ground, ground)

	var frame := TileLook.frame(level, [side, corner])

	assert_eq(frame.size(), 2 * 2 + 2 * 1 + 4, "on the 4×3 map's outer tiles: a side piece on each edge tile, the corner piece alone on the corners")
	assert_true(_has_piece(frame, 1, 2, TilePiece.new(side, 0)), "the top edge faces north")
	assert_true(_has_piece(frame, 2, 0, TilePiece.new(side, 2)), "the bottom edge faces south")
	assert_true(_has_piece(frame, 3, 1, TilePiece.new(side, 1)), "the right edge faces east")
	assert_true(_has_piece(frame, 0, 1, TilePiece.new(side, 3)), "the left edge faces west")
	assert_true(_has_piece(frame, 0, 2, TilePiece.new(corner, 0)), "the top-left corner as drawn (N–W)")
	assert_true(_has_piece(frame, 3, 2, TilePiece.new(corner, 1)))
	assert_true(_has_piece(frame, 3, 0, TilePiece.new(corner, 2)))
	assert_true(_has_piece(frame, 0, 0, TilePiece.new(corner, 3)))
	assert_eq(frame.filter(func(f): return f[0] == 0 and f[1] == 2).size(), 1, "a corner tile gets only the corner piece")
	assert_eq(TileLook.frame(level, [_tile("grass", TileKind.Ground)]).size(), 0, "no Border pieces: no frame")

## Port check: a real level's look matches the C# (variants and turns come from the C# 32-bit hash): First Steps,
## as the C# TileLook gives it (cells listed row by row from y = 0 up, x across; all 11 levels were compared once).
func test_first_steps_look_matches_the_csharp() -> void:
	var lib := ContentLibrary.load("res://data/content")
	var level: LevelAsset = lib.get_asset("Levels/Chapter 1/1 First Steps")
	var look := TileLook.ground(level, lib.rules.tiles)
	var props := TileLook.props(level, lib.rules.tiles)
	var s := level.size
	var cells := []
	for y in s.y:
		for x in s.x:
			var g: TilePiece = look[x][y]
			var p: TilePiece = props[x][y]
			cells.append("%s/%d%s" % [g.tile.get_id() if g.tile != null else "-", g.turns, ("+%s/%d" % [p.tile.get_id(), p.turns]) if p.tile != null else ""])
	assert_eq(" ".join(cells), FIRST_STEPS_LOOK)
	var frame := TileLook.frame(level, lib.rules.tiles).map(func(f): return "%d,%d:%s/%d" % [f[0], f[1], f[2].tile.get_id(), f[2].turns])
	assert_eq(" ".join(frame), FIRST_STEPS_FRAME)

const FIRST_STEPS_LOOK := "ground_a/0 ground_d/2 ground_c/3 ground_d/0 ground_a/3 ground_a/3 ground_d/3 build_ground_b/2 build_ground_b/0 build_ground_b/2 ground_b/3 ground_c/3 ground_d/2 ground_d/3 ground_d/2 ground_a/3 wall_a/0 build_ground_a/3 build_ground_b/2 build_ground_b/1 road_straight/1 road_straight/1 road_straight/1 road_straight/1 road_straight/1 road_straight/1 road_straight/1 road_straight/1 road_end/3 ground_a/3 ground_a/1 ground_d/2 ground_d/1 wall_a/3 ground_a/2 ground_a/1 ground_d/2 build_ground_a/1 build_ground_a/2 build_ground_b/2 ground_a/1 ground_c/0 ground_d/0 ground_a/3 ground_a/2 ground_b/1 ground_b/0 build_ground_b/3 build_ground_b/2 build_ground_a/3"
const FIRST_STEPS_FRAME := "1,4:board_edge_side/0 1,0:board_edge_side/2 2,4:board_edge_side/0 2,0:board_edge_side/2 3,4:board_edge_side/0 3,0:board_edge_side/2 4,4:board_edge_side/0 4,0:board_edge_side/2 5,4:board_edge_side/0 5,0:board_edge_side/2 6,4:board_edge_side/0 6,0:board_edge_side/2 7,4:board_edge_side/0 7,0:board_edge_side/2 8,4:board_edge_side/0 8,0:board_edge_side/2 9,1:board_edge_side/1 0,1:board_edge_side/3 9,2:board_edge_side/1 0,2:board_edge_side/3 9,3:board_edge_side/1 0,3:board_edge_side/3 0,4:board_edge_corner/0 9,4:board_edge_corner/1 9,0:board_edge_corner/2 0,0:board_edge_corner/3"
