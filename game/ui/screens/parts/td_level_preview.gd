class_name TdLevelPreview
extends Control
## Level select's picture of the selected level (mockup screens-b/level-select.html ".map"): the level's board as a
## 3D diorama (BoardView from the map kit, bases and starting units on it, TdDiorama's light), rendered once per level
## in its own SubViewport, kept as a texture (static cache: later visits and other screens get it at once) and swapped
## in when it is ready. Until then the flat minimap (MenuLogic.minimap_image) stands in. One render at a time; a level
## asked for while another renders waits its turn (only the last one asked for).
##   var p := TdLevelPreview.new(); p.size = Vector2(640, 320); add_child(p); p.show_level(level)

## Rendered boards by level id (Texture2D).
static var cache: Dictionary = {}

## The render's size against the shown size (1.5: sharp after the linear downscale).
var supersample := 1.5
## Camera pitch (degrees below the horizon) and turn (degrees; negative = seen from the front left).
var pitch := 52.0
var yaw := -16.0
## Turned off by tools/tests that must not build 3D (the minimap only).
var render_boards := true

var level: LevelAsset = null
var _pic: TextureRect
var _fallback: TextureRect
var _busy := false
var _pending: LevelAsset = null

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	_fallback = _rect(TextureRect.STRETCH_KEEP_ASPECT_CENTERED, CanvasItem.TEXTURE_FILTER_NEAREST)
	_fallback.anchor_left = 0.08; _fallback.anchor_right = 0.92
	_fallback.anchor_top = 0.1; _fallback.anchor_bottom = 0.9
	_pic = _rect(TextureRect.STRETCH_KEEP_ASPECT_COVERED, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	_pic.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _rect(stretch: int, filter: int) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = stretch
	r.texture_filter = filter
	r.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(r)
	return r

## Shows a level: its cached board at once, else the minimap while the board renders.
func show_level(lv: LevelAsset) -> void:
	level = lv
	if _pic == null: return
	var id := lv.get_id() if lv != null else ""
	if cache.has(id):
		_show_board(cache[id], false)
		return
	_pic.texture = null
	_pic.visible = false
	var img := MenuLogic.minimap_image(lv, 16)
	_fallback.texture = ImageTexture.create_from_image(img) if img != null else null
	_fallback.visible = true
	_fallback.modulate.a = 1.0
	if lv == null or not render_boards: return
	if _busy:
		_pending = lv
		return
	_render(lv)

## Whether the board of the shown level is up (not the minimap).
func is_board_shown() -> bool:
	return _pic != null and _pic.visible and _pic.texture != null

func _show_board(tex: Texture2D, fade: bool) -> void:
	_pic.texture = tex
	_pic.visible = true
	if fade:
		_pic.modulate.a = 0.0
		var tw := TdTheme.tween(_pic)
		tw.tween_property(_pic, "modulate:a", 1.0, TdTheme.motion("normal"))
		tw.tween_callback(func(): _fallback.visible = false)
	else:
		_pic.modulate.a = 1.0
		_fallback.visible = false

func _render(lv: LevelAsset) -> void:
	_busy = true
	var tex := await render_board(self, lv, Vector2i((maxf(size.x, 64.0) * supersample) as int, (maxf(size.y, 32.0) * supersample) as int), pitch, yaw)
	_busy = false
	if not is_inside_tree(): return
	var id := lv.get_id()
	if tex != null: cache[id] = tex
	if level == lv and tex != null: _show_board(tex, true)
	if _pending != null:
		var next := _pending
		_pending = null
		if next == level and not cache.has(next.get_id()): _render(next)

## Renders a level's board into a texture (null when it cannot): a SubViewport under `host` for a few frames.
static func render_board(host: Node, lv: LevelAsset, px: Vector2i, p_pitch := 46.0, p_yaw := -16.0) -> Texture2D:
	var app := TdMenu.app()
	if app == null or lv == null or host == null or not host.is_inside_tree(): return null
	var def: LevelDef = app.convert.level(lv)
	if def == null: return null
	var vp := SubViewport.new()
	vp.size = px
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	TdDiorama._add_light(root, Color("#1A130F"))
	var grid := def.build_grid()
	var board := BoardView.new()
	root.add_child(board)
	var kit: Array = app.lib.rules.tiles if app.lib.rules != null else []
	board.build(grid, lv, kit, func(p): return app.model_scene(p))
	for b in lv.bases:
		if b != null and b.entity != null: _model(root, app, b.entity.view, b.tile)
	for u in lv.starting_units:
		if u != null and u.entity != null: _model(root, app, u.entity.view, u.tile)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	_fit(cam, Vector2(px), Vector2i(grid.width, grid.height), p_pitch, p_yaw)
	var tree := host.get_tree()
	for i in 4: await tree.process_frame
	await RenderingServer.frame_post_draw
	var tex: Texture2D = null
	if is_instance_valid(vp):
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
		vp.queue_free()
	return tex

static func _model(root: Node3D, app: Node, view: String, tile: Vector2i) -> void:
	var sc: PackedScene = app.model_scene(view)
	if sc == null: return
	var m: Node3D = sc.instantiate()
	m.position = GridSpace.to_world(tile)
	root.add_child(m)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).to_lower() == "hitbox": n.visible = false

## Places the camera so the whole board (with its frame, trees up to ~1.2 high) fills the picture: three passes of
## "measure the corners on screen, scale the distance", then the offsets centre it.
static func _fit(cam: Camera3D, px: Vector2, grid: Vector2i, p_pitch: float, p_yaw: float) -> void:
	var c := Vector3((grid.x - 1) / 2.0, 0.0, -(grid.y - 1) / 2.0)
	var corners := []
	for x in [-0.8, grid.x - 0.2]:
		for z in [0.8, 0.2 - float(grid.y)]:
			for y in [-0.25, 0.6]: corners.append(Vector3(x, y, z))
	var dir := Vector3(0, sin(deg_to_rad(p_pitch)), cos(deg_to_rad(p_pitch))).rotated(Vector3.UP, deg_to_rad(p_yaw))
	var dist := float(maxi(grid.x, grid.y)) * 2.2
	var half_tan := tan(deg_to_rad(cam.fov) * 0.5)
	for pass_i in 4:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.position = c + dir * dist
		cam.look_at(c, Vector3.UP)
		# corners in camera space → normalised screen units (-1..1 on the height)
		var inv := cam.global_transform.affine_inverse()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for w in corners:
			var l: Vector3 = inv * w
			var d := maxf(-l.z, 0.01)
			var s := Vector2(l.x / d, l.y / d) / half_tan
			lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
			hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
		var aspect := px.x / maxf(px.y, 1.0)
		var need := maxf((hi.x - lo.x) / (2.0 * aspect), (hi.y - lo.y) / 2.0) / 0.97
		if pass_i < 3:
			dist *= need
		else:
			var mid := (lo + hi) * 0.5 # screen units; offsets are world units at the look distance
			cam.h_offset = mid.x * half_tan * dist
			cam.v_offset = mid.y * half_tan * dist
