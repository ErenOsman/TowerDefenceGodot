class_name ChapterThumbs
extends RefCounted
## Board thumbnails for the chapter cards, framed like the co-op cards and level select (UI/UX rule 2026-10-14):
## the shared renderer CoopBoardPic.render (35° camera, "contain": the whole board, never cropped), and the margin
## left over filled with a darkened, blurred copy of the render, all baked into one texture (the card shows a single
## TextureRect). The board is the level's pre-rendered PNG (LevelPreviewCache) when it has a fresh one (composed at
## once, no 3D); else it renders live. Cached per key for the session; one live render at a time (a queue).
##   ChapterThumbs.request(self, "chapter1-1", level, func(tex): rect.texture = tex)
## Until it is ready, show placeholder(level) (the minimap image).

## The render size: 2× the card's thumbnail well (~292 × 228), so it stays sharp at 1080p.
const SIZE := Vector2i(576, 456)
const PITCH := 35.0
const YAW := -8.0
## The blurred margin: shrink factor (bigger = blurrier) and how dark it is.
const BLUR_SHRINK := 12
const DARK := 0.5
const BACK := Color(0.10, 0.075, 0.06)

static var cache := {}          # key -> Texture2D
static var _queue: Array = []   # {key, level, host, done: [Callable]}
static var _busy := false

## The cached thumbnail for a key (a level id: also its pre-rendered picture), or null.
static func cached(key: String) -> Texture2D:
	if not cache.has(key): _from_png(key, CoopLevels.level_asset(key))
	return cache.get(key)

## Composes the thumbnail from the level's pre-rendered PNG into the cache; false when it has no fresh one.
static func _from_png(key: String, level: LevelAsset) -> bool:
	var img := compose(LevelPreviewCache.image(level, SIZE)) if level != null else null
	if img == null: return false
	cache[key] = ImageTexture.create_from_image(img)
	return true

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
	if _from_png(key, level):
		done.call(cache[key])
		return
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
		var host = j.host   # untyped on purpose: a typed Node var throws on a freed instance
		if not is_instance_valid(host) or not (host as Node).is_inside_tree(): continue
		_busy = true
		_run(j)
		return

static func _run(j: Dictionary) -> void:
	var host: Node = j.host
	var tree := host.get_tree()
	var tex: Texture2D = await CoopBoardPic.render(host, j.level, SIZE, PITCH, YAW)
	var out: Texture2D = null
	if tex != null:
		var img := compose(tex.get_image())
		if img != null: out = ImageTexture.create_from_image(img)
	if out != null: cache[j.key] = out
	for d in j.done:
		if out != null and d.is_valid(): d.call(out)
	_busy = false
	if tree != null: _next.call_deferred()

## The board (transparent background) over a darkened, blurred, cover-scaled copy of its own pixels; opaque.
static func compose(board: Image) -> Image:
	if board == null or board.is_empty(): return null
	board = board.duplicate()
	if board.is_compressed(): board.decompress()
	board.clear_mipmaps()
	board.convert(Image.FORMAT_RGBA8)
	var w := board.get_width()
	var h := board.get_height()
	var used := board.get_used_rect()
	var src: Image = board.get_region(used) if used.size.x > 4 and used.size.y > 4 else board.duplicate()
	# cover-scale the board crop into a small image (the blur), darken it there (cheap), then scale it back up
	var sw := maxi(2, w / BLUR_SHRINK)
	var sh := maxi(2, h / BLUR_SHRINK)
	var k := maxf(float(sw) / src.get_width(), float(sh) / src.get_height())
	src.resize(maxi(sw, int(ceil(src.get_width() * k))), maxi(sh, int(ceil(src.get_height() * k))), Image.INTERPOLATE_BILINEAR)
	var small: Image = src.get_region(Rect2i((src.get_width() - sw) / 2, (src.get_height() - sh) / 2, sw, sh))
	for y in sh:
		for x in sw:
			var c := small.get_pixel(x, y)
			var rgb := BACK.lerp(Color(c.r, c.g, c.b), c.a) * DARK
			small.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, 1.0))
	small.resize(w, h, Image.INTERPOLATE_CUBIC)
	small.blend_rect(board, Rect2i(0, 0, w, h), Vector2i.ZERO)
	small.generate_mipmaps()
	return small
