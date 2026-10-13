class_name ChapterThumbs
extends Node
## Small board thumbnails for the chapter cards (the same approach as the level preview): a level's board
## (BoardView from the map kit, with its bases) built in its own world in a hidden SubViewport, drawn a few frames,
## then kept as a texture (cached per key for the session: built once, reused every time the chapter select opens).
## One render at a time (a queue), so opening the picker never builds several boards in one frame.
##   ChapterThumbs.request(self, "chapter1-1", level, func(tex): rect.texture = tex)
## Until it is ready, show placeholder(level) (the minimap image).

## The render size (2× the card's thumbnail, so it stays sharp at 1080p).
const SIZE := Vector2i(576, 456)
## The view: degrees below the horizon, degrees turned to the side, and the empty margin around the board.
const PITCH := 58.0
const YAW := 40.0
const MARGIN := 0.04
## Frames drawn before the image is taken (models and shadows settle).
const SETTLE_FRAMES := 4

static var cache := {}          # key -> Texture2D
static var _queue: Array = []   # {key, level, host, done: [Callable]}
static var _busy := false

## The cached thumbnail for a key, or null.
static func cached(key: String) -> Texture2D:
	return cache.get(key)

## The minimap of a level as a texture (the placeholder while the board renders); null for no level.
static func placeholder(level: LevelAsset) -> Texture2D:
	var img := MenuLogic.minimap_image(level, 12)
	return ImageTexture.create_from_image(img) if img != null else null

## Calls done(texture) with the level's board thumbnail: at once when cached, else after it has rendered (the
## render hangs off `host`; if host leaves the tree first, the job is dropped and done is never called).
static func request(host: Node, key: String, level: LevelAsset, done: Callable) -> void:
	if cache.has(key):
		done.call(cache[key])
		return
	if level == null or host == null: return
	for j in _queue:
		if j.key == key:
			j.done.append(done)
			return
	_queue.append({"key": key, "level": level, "host": host, "done": [done]})
	_next()

static func _next() -> void:
	if _busy: return
	while not _queue.is_empty():
		var j: Dictionary = _queue.pop_front()
		var host: Node = j.host
		if not is_instance_valid(host) or not host.is_inside_tree(): continue
		_busy = true
		var r := ChapterThumbs.new()
		r._job = j
		host.add_child(r)
		return

var _job: Dictionary
var _vp: SubViewport
var _frames := 0

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	if not _build_world(_job.level):
		_finish(null)

func _exit_tree() -> void:
	if not _job.is_empty():
		# the host closed before the render finished: drop it, carry on with the next one
		_job = {}
		_busy = false
		_next.call_deferred()

func _process(_delta: float) -> void:
	if _job.is_empty(): return
	_frames += 1
	if _frames < SETTLE_FRAMES: return
	var img := _vp.get_texture().get_image()
	_finish(ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null)

func _finish(tex: Texture2D) -> void:
	var j := _job
	_job = {}
	_busy = false
	if tex != null: cache[j.key] = tex
	for d in j.done:
		if tex != null and d.is_valid(): d.call(tex)
	queue_free()
	_next.call_deferred()

## The board world: light like the menus' dioramas, the level's tiles and bases, a camera framing the whole board.
func _build_world(lv: LevelAsset) -> bool:
	var app := TdMenu.app()
	if app == null or lv == null: return false
	var def: LevelDef = app.convert.level(lv)
	if def == null: return false
	var root := Node3D.new()
	_vp.add_child(root)
	TdDiorama._add_light(root, TdTheme.color("wood.900"))
	var grid := def.build_grid()
	var board := BoardView.new()
	root.add_child(board)
	var kit: Array = app.lib.rules.tiles if app.lib.rules != null else []
	board.build(grid, lv, kit, func(p): return app.model_scene(p))
	for b in lv.bases:
		if b == null or b.entity == null: continue
		var sc: PackedScene = app.model_scene(b.entity.view)
		if sc == null: continue
		var m: Node3D = sc.instantiate()
		m.position = GridSpace.to_world(b.tile)
		root.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	_frame(cam, Vector2i(grid.width, grid.height))
	return true

## Places the camera so the whole board (plus its edge) fills the thumbnail: a three-quarter view (PITCH below the
## horizon, turned YAW to the side, so a long board fills a card-shaped picture), the distance found by bisection on
## the board's projected corners, then shifted so the board sits in the middle.
func _frame(cam: Camera3D, grid: Vector2i) -> void:
	var c := Vector3((grid.x - 1) / 2.0, 0.0, -(grid.y - 1) / 2.0)
	var p := deg_to_rad(PITCH)
	var yaw := deg_to_rad(YAW)
	var dir := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p))
	var corners := []
	for x in [-0.7, grid.x - 0.3]:
		for z in [0.7, -(grid.y - 0.3)]:
			for y in [-0.35, 0.5]: corners.append(Vector3(x, y, z))
	var lo := 1.0
	var hi := 120.0
	for i in 28:
		var d := (lo + hi) / 2.0
		cam.position = c + dir * d
		cam.look_at(c, Vector3.UP)
		var r := _bounds(cam, corners)
		if r.size.x <= SIZE.x * (1.0 - 2.0 * MARGIN) and r.size.y <= SIZE.y * (1.0 - 2.0 * MARGIN): hi = d
		else: lo = d
	cam.position = c + dir * hi
	cam.look_at(c, Vector3.UP)
	var b := _bounds(cam, corners)
	var off := b.get_center() - Vector2(SIZE) / 2.0
	var units_per_px := 2.0 * hi * tan(deg_to_rad(cam.fov) * 0.5) / float(SIZE.y)
	cam.h_offset = off.x * units_per_px
	cam.v_offset = -off.y * units_per_px

static func _bounds(cam: Camera3D, pts: Array) -> Rect2:
	var r := Rect2(cam.unproject_position(pts[0]), Vector2.ZERO)
	for q in pts: r = r.expand(cam.unproject_position(q))
	return r
