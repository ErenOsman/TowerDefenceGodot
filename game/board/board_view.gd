class_name BoardView
extends Node3D
## The board as a diorama (BoardView.cs): each tile's map-kit piece from the level's look (TileLook: automatic
## from terrain, build and road, overridden by the visual layer), the props layer's pieces and the board's frame;
## a tile without a piece gets a placeholder block. Tile previews (range, aims, area, routes, placing, enemy
## intent) are flat textured quads just above the board, redrawn every frame (clear_highlights + highlight);
## attack previews are ribbons drawn over the models (line).

const GROUND := Color(0.36, 0.45, 0.32)
const PATH_TILE := Color(0.58, 0.50, 0.36)
const WALL := Color(0.25, 0.25, 0.27)
const CHASM := Color(0.06, 0.07, 0.14)

var grid: BattleGrid = null
## Pieces placed (for tests and tools): Array of {what, tile, id, yaw}.
var pieces: Array = []

var _highlights: Array = []   # MeshInstance3D pool
var _highlights_used := 0
var _lines: Array = []        # MeshInstance3D (ImmediateMesh) pool
var _lines_used := 0
var _quad: QuadMesh = null
var _tiles_root: Node3D = null
var _marks_root: Node3D = null
var _camera: Camera3D = null  # for view-aligned lines

func _init() -> void:
	name = "Board"

## Builds the board: the kit's pieces (scene_of: a TileAsset view path → PackedScene, or null), placeholders where
## none fits (no level, no kit, or nothing fits).
func build(p_grid: BattleGrid, level: LevelAsset = null, kit: Array = [], scene_of: Callable = Callable()) -> void:
	grid = p_grid
	for c in get_children(): c.queue_free()
	pieces.clear()
	_highlights.clear()
	_lines.clear()
	_highlights_used = 0
	_lines_used = 0
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	add_child(_tiles_root)
	_marks_root = Node3D.new()
	_marks_root.name = "Marks"
	add_child(_marks_root)
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_quad.orientation = PlaneMesh.FACE_Y
	_underlay()

	var has_look := level != null and kit != null and kit.size() > 0 and scene_of.is_valid()
	if has_look:
		var s := level.size
		has_look = s.x == grid.width and s.y == grid.height
	var look: Array = TileLook.ground(level, kit) if has_look else []
	var props: Array = TileLook.props(level, kit) if has_look else []
	for x in grid.width:
		for y in grid.height:
			var p := Vector2i(x, y)
			if has_look and props[x][y].tile != null: _piece(p, props[x][y], "Prop", scene_of)
			if has_look and look[x][y].tile != null and _piece(p, look[x][y], "Tile", scene_of): continue
			match grid.tile(p):
				TileType.Wall: _block(p, WALL, 0.9)
				TileType.Chasm: _block(p, CHASM, 0.02, -0.3)
				TileType.Path: _block(p, PATH_TILE, 0.1)
				_: _block(p, GROUND, 0.1)
	if has_look:
		for f in TileLook.frame(level, kit):
			_piece(Vector2i(f[0], f[1]), f[2], "Frame", scene_of)

## A map-kit piece on a tile, turned a quarter clockwise per turn (seen from above). False when it has no model.
func _piece(p: Vector2i, piece: TilePiece, what: String, scene_of: Callable) -> bool:
	if piece == null or piece.tile == null or piece.tile.view == "": return false
	var scene: PackedScene = scene_of.call(piece.tile.view)
	if scene == null: return false
	var node: Node3D = scene.instantiate()
	node.name = "%s %d,%d %s" % [what, p.x, p.y, piece.tile.get_id()]
	_tiles_root.add_child(node)
	node.position = GridSpace.to_world(p)
	node.rotation.y = GridSpace.piece_yaw(piece.turns)
	pieces.append({"what": what, "tile": p, "id": piece.tile.get_id(), "turns": piece.turns, "yaw": node.rotation.y})
	return true

## A dark slab under the whole board, so no gap between pieces shows the background.
func _underlay() -> void:
	var slab := MeshInstance3D.new()
	slab.name = "Board Underlay"
	var box := BoxMesh.new()
	box.size = Vector3(grid.width, 0.05, grid.height)
	slab.mesh = box
	slab.material_override = BoardMaterials.lit(Color(0.14, 0.12, 0.1))
	slab.position = Vector3((grid.width - 1) / 2.0, -0.42, -(grid.height - 1) / 2.0)
	_tiles_root.add_child(slab)

func _block(p: Vector2i, c: Color, height: float, top: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Tile %d,%d" % [p.x, p.y]
	var box := BoxMesh.new()
	box.size = Vector3(0.96, height, 0.96)
	mi.mesh = box
	mi.material_override = BoardMaterials.lit(c)
	mi.position = GridSpace.to_world(p, top - height / 2.0 + (height if height > 0.5 else 0.0))
	_tiles_root.add_child(mi)
	pieces.append({"what": "Block", "tile": p, "id": "", "turns": 0, "yaw": 0.0})

## The board's world centre on the ground.
func center() -> Vector3:
	return Vector3((grid.width - 1) / 2.0, 0.0, -(grid.height - 1) / 2.0) if grid != null else Vector3.ZERO

# ------------------------------------------------------------------ highlights

## Starts a new set of highlights (call before highlight each frame).
func clear_highlights() -> void:
	for i in _highlights_used: _highlights[i].visible = false
	_highlights_used = 0
	for i in _lines_used: _lines[i].visible = false
	_lines_used = 0

## Marks a tile; later calls draw on top. size < 1 draws a smaller marker (route steps). yaw (radians) turns the
## decal on the board (0: its top points north).
func highlight(p: Vector2i, c: Color, size: float = 0.96, lift: float = 0.02, tex: Texture2D = null, yaw: float = 0.0) -> void:
	if _marks_root == null: return
	if _highlights_used == _highlights.size():
		var mi := MeshInstance3D.new()
		mi.name = "Highlight"
		mi.mesh = _quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marks_root.add_child(mi)
		_highlights.append(mi)
	var h: MeshInstance3D = _highlights[_highlights_used]
	_highlights_used += 1
	h.visible = true
	h.position = GridSpace.to_world(p, lift + _highlights_used * 0.0005)
	h.rotation = Vector3(0.0, yaw, 0.0)
	h.scale = Vector3(size, 1.0, size)
	h.material_override = BoardMaterials.decal(tex, c) if tex != null else BoardMaterials.overlay(c)

## A decal at a world point on the board (not tile-snapped): a melee chevron on a tile edge, a ✕ on a blocker.
## over_models: drawn over everything (depth test off).
func decal_at(at: Vector3, tex: Texture2D, c: Color, size: float, yaw: float = 0.0, over_models: bool = false) -> void:
	highlight(Vector2i.ZERO, c, size, 0.0, tex, yaw)
	var h: MeshInstance3D = _highlights[_highlights_used - 1]
	h.position = at + Vector3.UP * (_highlights_used * 0.0005)
	if over_models: h.material_override = BoardMaterials.on_top(tex, c)

## How many highlights are drawn now (tests and tools).
var highlight_count: int:
	get: return _highlights_used

## The tile of each highlight drawn now (tests and tools).
func highlighted_tiles() -> Array:
	var out := []
	for i in _highlights_used: out.append(GridSpace.to_tile(_highlights[i].position))
	return out

## The camera the lines face (view-aligned ribbons, like Unity's LineRenderer alignment View).
func set_camera(cam: Camera3D) -> void:
	_camera = cam

## A preview line from one world point to another (attack previews): straight, or arced (a lobbed shot) as high as
## arc. The texture repeats along it (tile: dashes, dots) or stretches once (a chevron); width in world units.
## Drawn over the models (depth test off).
## flat: the ribbon lies on the ground plane (low lines) instead of facing the camera. scroll: dashes move along it
## one texture period per this many seconds (0 = still).
func line(from: Vector3, to: Vector3, tex: Texture2D, c: Color, width: float, arc: float = 0.0, tile: bool = true, flat: bool = false, scroll: float = 0.0) -> void:
	if _marks_root == null: return
	if _lines_used == _lines.size():
		var mi := MeshInstance3D.new()
		mi.name = "Preview Line"
		mi.mesh = ImmediateMesh.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marks_root.add_child(mi)
		_lines.append(mi)
	var mi2: MeshInstance3D = _lines[_lines_used]
	_lines_used += 1
	mi2.visible = true
	var im: ImmediateMesh = mi2.mesh
	im.clear_surfaces()
	var count := 16 if arc > 0.0 else 2
	var pts: Array[Vector3] = []
	for i in count:
		var t := i / float(count - 1)
		pts.append(from.lerp(to, t) + Vector3.UP * (arc * 4.0 * t * (1.0 - t)))
	var length := 0.0
	for i in range(1, count): length += pts[i].distance_to(pts[i - 1])
	var repeat := 1.0
	if tile and tex != null:
		repeat = length / maxf(0.01, width * float(tex.get_width()) / float(tex.get_height()))
	var eye := _camera.global_position if _camera != null else from + Vector3(0, 10, 10)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, BoardMaterials.on_top(tex, c))
	var run := 0.0
	var shift := 0.0
	if scroll > 0.0: shift = -fmod(Time.get_ticks_msec() / 1000.0 / scroll, 1.0)
	for i in count:
		var along: Vector3 = (pts[mini(i + 1, count - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var normal := Vector3.UP if flat else (eye - pts[i]).normalized()
		var side := along.cross(normal).normalized() * (width * 0.5)
		if i > 0: run += pts[i].distance_to(pts[i - 1])
		var u := (run / maxf(0.0001, length)) * repeat + shift
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(pts[i] + side)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(pts[i] - side)
	im.surface_end()

## The screen rects (viewport pixels) of the tiles highlighted now, e.g. for tooltips to keep clear of.
func highlight_screen_rects(cam: Camera3D, into: Array) -> void:
	if cam == null: return
	for i in _highlights_used:
		var h: MeshInstance3D = _highlights[i]
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		var behind := false
		for c in 4:
			var corner := h.global_transform * Vector3(-0.5 if (c & 1) == 0 else 0.5, 0.0, -0.5 if (c & 2) == 0 else 0.5)
			if cam.is_position_behind(corner):
				behind = true
				break
			var s := cam.unproject_position(corner)
			mn = mn.min(s)
			mx = mx.max(s)
		if not behind: into.append(Rect2(mn, mx - mn))
