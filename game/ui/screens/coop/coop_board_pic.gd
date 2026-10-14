class_name CoopBoardPic
extends Control
## A level's 3D board picture for the co-op screens, rendered at this control's own size (TdLevelPreview.render_board,
## framed to fill the box) and cached per level and size, so a wide strip and a card each get a board that fits them.
## The flat minimap stands in until it is ready. Renders one at a time (a queue hung off the scene root).
## Thumbnail rule (UI review round 3): "contain", never crop; a low camera (~35°) so the board fills ~90 % of the
## width; the margin left over shows a darkened, blurred copy of the same render instead of black.
##   var p := CoopBoardPic.new(); p.custom_minimum_size = Vector2(80, 54); add_child(p); p.show_level("chapter1-1")

static var cache := {}       # "id@WxH" → Texture2D
static var _queue: Array = []
static var _busy := false

## Render size against the shown size.
const SUPERSAMPLE := 2.0

var level_id := ""
## Desaturated (a locked mission's picture).
var grey := false:
	set(v):
		grey = v
		if _pic != null: _pic.material = grey_material() if v else null
var pitch := 35.0
var yaw := -8.0
var _pic: TextureRect
var _back: TextureRect
var _wanted := false

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	_back = TextureRect.new() # the blurred, darkened copy filling the margins
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back.mouse_filter = MOUSE_FILTER_IGNORE
	_back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_back.material = _blur_material()
	_back.visible = false
	add_child(_back)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.mouse_filter = MOUSE_FILTER_IGNORE
	_pic.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_pic)
	resized.connect(func(): if _wanted: _request())

## Shows a level (minimap now, the board once rendered).
func show_level(id: String) -> void:
	if id == level_id and _pic.texture != null: return
	level_id = id
	var key := _key()
	if cache.has(key):
		_set_board(cache[key])
		return
	_pic.texture = CoopUi.thumb(id, 8)
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wanted = true
	if is_inside_tree(): _request.call_deferred()
	else: ready.connect(func(): _request.call_deferred(), CONNECT_ONE_SHOT)

func is_board_shown() -> bool:
	return cache.has(_key()) and _pic.texture == cache[_key()]

func _key() -> String:
	var s := size if size.x > 4.0 else custom_minimum_size
	return "%s@%dx%d" % [level_id, int(s.x), int(s.y)]

func _set_board(tex: Texture2D) -> void:
	_wanted = false
	_pic.texture = tex
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # contain: the whole board, never cropped
	_back.texture = _backdrop(tex)
	_back.visible = true
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _request() -> void:
	if not _wanted or not is_inside_tree() or level_id == "": return
	if size.x < 8.0 and custom_minimum_size.x < 8.0: return # not laid out yet: resized asks again
	var key := _key()
	if cache.has(key):
		_set_board(cache[key])
		return
	for j in _queue:
		if j.key == key:
			if not j.pics.has(self): j.pics.append(self)
			return
	var s := size if size.x > 4.0 else custom_minimum_size
	_queue.append({"key": key, "id": level_id, "px": Vector2i(int(s.x * SUPERSAMPLE), int(s.y * SUPERSAMPLE)),
		"pitch": pitch, "yaw": yaw, "pics": [self]})
	_run(get_tree())

static func _run(tree: SceneTree) -> void:
	if _busy or _queue.is_empty() or tree == null: return
	_busy = true
	var j: Dictionary = _queue.pop_front()
	var lv := CoopLevels.level_asset(j.id)
	var tex: Texture2D = await render(tree.root, lv, j.px, j.pitch, j.yaw) if lv != null else null
	if tex != null: cache[j.key] = tex
	for p in j.pics:
		if is_instance_valid(p) and p.level_id == j.id and tex != null and p._key() == j.key: p._set_board(tex)
	_busy = false
	_run(tree)

static var _backdrops := {}   # board texture → its board-only crop (the blurred margin's source)

## The part of a render the board covers (its alpha's used rect) as a texture, so the blurred, cover-scaled copy
## behind spreads the board's own colours into the margins instead of the empty background.
static func _backdrop(tex: Texture2D) -> Texture2D:
	if _backdrops.has(tex): return _backdrops[tex]
	var out: Texture2D = tex
	var img := tex.get_image() if tex != null else null
	if img != null and not img.is_empty():
		var used := img.get_used_rect()
		if used.size.x > 4 and used.size.y > 4:
			var crop := img.get_region(used)
			crop.generate_mipmaps()
			out = ImageTexture.create_from_image(crop)
	_backdrops[tex] = out
	return out

static var _grey_mat: ShaderMaterial = null

## Desaturates and darkens a picture (locked missions).
static func grey_material() -> ShaderMaterial:
	if _grey_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = COLOR;\n\tfloat l = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(l) * 0.8, c.a);\n}\n"
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = sh
	return _grey_mat

static var _blur: ShaderMaterial = null

## A heavy blur (a high mip level of the mipmapped render) darkened to 45 %, opaque.
static func _blur_material() -> ShaderMaterial:
	if _blur == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float lod = 3.5;
uniform float dark = 0.5;
void fragment() {
	vec4 c = textureLod(TEXTURE, UV, lod);
	vec3 bg = vec3(0.10, 0.075, 0.06);
	COLOR = vec4(mix(bg, c.rgb / max(c.a, 0.001), c.a) * dark, 1.0);
}
"""
		_blur = ShaderMaterial.new()
		_blur.shader = sh
	return _blur

## Renders a level's board into a texture with a transparent background (TdLevelPreview.render_board's scene and
## framing; transparent so the blurred copy can show around it). null when it cannot.
static func render(host: Node, lv: LevelAsset, px: Vector2i, p_pitch: float, p_yaw: float) -> Texture2D:
	var app := TdMenu.app()
	if app == null or lv == null or host == null or not host.is_inside_tree(): return null
	var def: LevelDef = app.convert.level(lv)
	if def == null: return null
	var vp := SubViewport.new()
	vp.size = px
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	# every frame only for the few frames before the capture below; then the viewport is freed and the picture is
	# the cached texture (per level and size: a new level or size renders again, nothing else does)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	TdDiorama._add_light(root, Color("#1A130F"), true) # clear background (transparent)
	var grid := def.build_grid()
	var board := BoardView.new()
	root.add_child(board)
	var kit: Array = app.lib.rules.tiles if app.lib.rules != null else []
	board.build(grid, lv, kit, func(p): return app.model_scene(p))
	for b in lv.bases:
		if b != null and b.entity != null: TdLevelPreview._model(root, app, b.entity.view, b.tile)
	for u in lv.starting_units:
		if u != null and u.entity != null: TdLevelPreview._model(root, app, u.entity.view, u.tile)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	TdLevelPreview._fit(cam, Vector2(px), Vector2i(grid.width, grid.height), p_pitch, p_yaw)
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
