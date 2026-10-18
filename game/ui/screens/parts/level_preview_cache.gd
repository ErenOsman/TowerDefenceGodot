class_name LevelPreviewCache
extends RefCounted
## Pre-rendered level pictures (Eren 2026-10-17: the live 3D render flickered on first open and flashed on close):
## res://art/levels/previews/<level id>.png, the board with a transparent background rendered by
## tools/level_previews.gd exactly as the live renderer does it (CoopBoardPic.render: 35° camera, yaw -8°, "contain")
## at RENDER_SIZE (2× level select's MAP_SIZE), plus previews.json with a content hash per level (the level's
## map, paths, visual/props layers, bases and starting units) so a picture of an edited level counts as stale.
## Every level picture (level select, mission detail, mission cards, co-op cards, chapter cards, the Guild backdrop)
## asks here first; only a missing or stale picture falls back to the live render (with a one-line log warning).
## The PNGs use the "keep" importer (exported as they are) and are read as bytes, so this works headless and on the web.
##   var img := LevelPreviewCache.image(level, Vector2i(160, 108))   # null: no fresh picture, render live
##   LevelPreviewCache.status(level)                                   # "ok" / "missing" / "stale"
## Regenerate: cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot tools/level_previews.gd

const DIR := "res://art/levels/previews/"
const MANIFEST := DIR + "previews.json"
## 2× TdLevelPreview's on-screen size (level select MAP_SIZE 580 × 300).
const RENDER_SIZE := Vector2i(1160, 600)
const PITCH := 35.0
const YAW := -8.0
## Bump when the renderer changes the picture (camera, light, board builder, tile kit): every preview goes stale.
const RENDER_VERSION := 1
## Within this aspect difference the whole picture is used; otherwise the board is re-framed for the box.
const ASPECT_SLACK := 0.04
## The board's share of the limiting side when re-framed (the live fit's ~92 % "contain").
const FILL := 0.92

static var _manifest = null           # Dictionary once read
static var _images := {}              # level id → Image (the fresh PNG) or null (none / stale)
static var _sized := {}               # "id@WxH" → Image
static var _warned := {}

## The content hash of what a level's picture shows: its layers, paths, bases and starting units, and the render
## settings. A changed hash = a stale picture.
static func content_hash(lv: LevelAsset) -> String:
	if lv == null: return ""
	var parts: Array[String] = ["v%d" % RENDER_VERSION, str(RENDER_SIZE), str(PITCH), str(YAW), lv.get_id()]
	parts.append("terrain:" + "|".join(lv.terrain))
	var keys: Array[String] = []
	for k in lv.terrain_keys:
		if k != null: keys.append("%s=%s" % [k.symbol, k.terrain.name if k.terrain != null else ""])
	parts.append("keys:" + "|".join(keys))
	parts.append("build:" + "|".join(lv.build))
	parts.append("road:" + "|".join(lv.road))
	parts.append("visual:" + "|".join(lv.visual))
	parts.append("props:" + "|".join(lv.props))
	for p in lv.paths: parts.append("path:" + (str(p.tiles) if p != null else ""))
	for b in lv.bases:
		if b != null: parts.append("base:%s@%s" % [b.entity.view if b.entity != null else "", b.tile])
	for u in lv.starting_units:
		if u != null: parts.append("unit:%s@%s" % [u.entity.view if u.entity != null else "", u.tile])
	return "\n".join(parts).sha256_text().substr(0, 16)

## previews.json ({} when there is none).
static func manifest() -> Dictionary:
	if _manifest == null:
		_manifest = {}
		if FileAccess.file_exists(MANIFEST):
			var d = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if d is Dictionary: _manifest = d
	return _manifest

static func png_path(level_id: String) -> String:
	return DIR + level_id + ".png"

## "ok" (a picture whose hash matches), "missing" (no picture or no manifest entry) or "stale" (hash differs).
static func status(lv: LevelAsset) -> String:
	if lv == null: return "missing"
	var e = manifest().get("levels", {}).get(lv.get_id())
	if not (e is Dictionary) or not FileAccess.file_exists(png_path(lv.get_id())): return "missing"
	return "ok" if str(e.get("hash", "")) == content_hash(lv) else "stale"

## The level's fresh pre-rendered board (RGBA8, transparent background), or null. Warns once per level when there
## is none (the caller renders live).
static func board(lv: LevelAsset) -> Image:
	if lv == null: return null
	var id := lv.get_id()
	if _images.has(id): return _images[id]
	var img: Image = null
	var st := status(lv)
	if st == "ok":
		# the raw file ("keep" importer: exported as is), read as bytes (load_from_file on res:// warns)
		img = Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(png_path(id))) == OK and not img.is_empty():
			if img.is_compressed(): img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		else:
			img = null
			st = "unreadable"
	if img == null and not _warned.has(id):
		_warned[id] = true
		print("[LevelPreview] WARNING: %s preview for %s, rendering it live (run tools/level_previews.gd)" % [st, id])
	_images[id] = img
	return img

## The level's picture at exactly px pixels (shown "contain"): the whole PNG when the aspect matches (scaled when
## the size differs), else the board re-framed to fill ~92 % of the box's limiting side. null: no fresh picture.
static func image(lv: LevelAsset, px: Vector2i) -> Image:
	if lv == null or px.x < 2 or px.y < 2: return null
	var key := "%s@%dx%d" % [lv.get_id(), px.x, px.y]
	if _sized.has(key): return _sized[key]
	var src := board(lv)
	if src == null: return null
	var out: Image
	var a_box := float(px.x) / px.y
	var a_src := float(src.get_width()) / src.get_height()
	if absf(a_box / a_src - 1.0) <= ASPECT_SLACK:
		out = src.duplicate()
	else:
		var used := src.get_used_rect()
		if used.size.x < 4 or used.size.y < 4: used = Rect2i(Vector2i.ZERO, src.get_size())
		var cw := used.size.x / FILL
		var ch := used.size.y / FILL
		if cw / ch < a_box: cw = ch * a_box
		else: ch = cw / a_box
		out = Image.create_empty(int(ceil(cw)), int(ceil(ch)), false, Image.FORMAT_RGBA8)
		out.blit_rect(src, used, Vector2i((out.get_width() - used.size.x) / 2, (out.get_height() - used.size.y) / 2))
	if out.get_size() != px: out.resize(px.x, px.y, Image.INTERPOLATE_CUBIC)
	_sized[key] = out
	return out

## image() as a mipmapped texture (the pictures are drawn with LINEAR_WITH_MIPMAPS; the blur reads a high mip).
static func texture(lv: LevelAsset, px: Vector2i) -> Texture2D:
	var img := image(lv, px)
	if img == null: return null
	var m := img.duplicate()
	m.generate_mipmaps()
	return ImageTexture.create_from_image(m)

## Forgets everything read (tests, after regenerating).
static func reset() -> void:
	_manifest = null
	_images.clear()
	_sized.clear()
	_warned.clear()
