class_name CoopBoardPic
extends Control
## A level's 3D board picture for the co-op screens, rendered at this control's own size (TdLevelPreview.render_board,
## framed to fill the box) and cached per level and size, so a wide strip and a card each get a board that fits them.
## The flat minimap stands in until it is ready. Renders one at a time (a queue hung off the scene root).
##   var p := CoopBoardPic.new(); p.custom_minimum_size = Vector2(80, 54); add_child(p); p.show_level("chapter1-1")

static var cache := {}       # "id@WxH" → Texture2D
static var _queue: Array = []
static var _busy := false

## Render size against the shown size.
const SUPERSAMPLE := 2.0

var level_id := ""
var pitch := 52.0
var yaw := -8.0
var _pic: TextureRect
var _wanted := false

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
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
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	var tex: Texture2D = await TdLevelPreview.render_board(tree.root, lv, j.px, j.pitch, j.yaw) if lv != null else null
	if tex != null: cache[j.key] = tex
	for p in j.pics:
		if is_instance_valid(p) and p.level_id == j.id and tex != null and p._key() == j.key: p._set_board(tex)
	_busy = false
	_run(tree)
