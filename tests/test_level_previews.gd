extends TestCase
## The pre-rendered level pictures (LevelPreviewCache, res://art/levels/previews): every level of the game's content
## has a PNG whose content hash matches (else: run tools/level_previews.gd), the hash follows what the picture shows,
## and a picture can be read and sized for any box.

const REGEN := "run tools/level_previews.gd (cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot tools/level_previews.gd)"

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func setup() -> void:
	LevelPreviewCache.reset()

func test_every_level_has_a_fresh_preview() -> void:
	var levels := lib().all_of("LevelAsset")
	assert_true(levels.size() > 0, "no levels in the content")
	var bad := []
	for lv: LevelAsset in levels:
		var st := LevelPreviewCache.status(lv)
		if st != "ok": bad.append("%s: %s" % [lv.get_id(), st])
	assert_eq(bad.size(), 0, "level previews missing or stale (%s) — %s" % [", ".join(bad), REGEN])

func test_hash_follows_the_map() -> void:
	var lv: LevelAsset = lib().all_of("LevelAsset")[0]
	var h := LevelPreviewCache.content_hash(lv)
	assert_eq(h.length(), 16)
	var copy := LevelAsset.new()
	copy.name = lv.name
	copy.id = lv.id
	copy.terrain = lv.terrain.duplicate()
	copy.terrain_keys = lv.terrain_keys
	copy.build = lv.build.duplicate()
	copy.road = lv.road.duplicate()
	copy.visual = lv.visual.duplicate()
	copy.props = lv.props.duplicate()
	copy.paths = lv.paths
	copy.bases = lv.bases
	copy.starting_units = lv.starting_units
	copy.description = "something else"
	assert_eq(LevelPreviewCache.content_hash(copy), h, "waves and texts do not change the picture")
	copy.visual.append("x")
	assert_ne(LevelPreviewCache.content_hash(copy), h, "the visual layer does")

func test_preview_reads_and_fits_any_box() -> void:
	var lv: LevelAsset = null
	for l: LevelAsset in lib().all_of("LevelAsset"):
		if LevelPreviewCache.status(l) == "ok": lv = l
	if lv == null:
		fail("no fresh preview to read — " + REGEN)
		return
	var full := LevelPreviewCache.image(lv, LevelPreviewCache.RENDER_SIZE)
	assert_not_null(full, "the PNG loads (keep importer)")
	if full == null: return
	assert_eq(full.get_size(), LevelPreviewCache.RENDER_SIZE)
	var card := LevelPreviewCache.image(lv, Vector2i(152, 100))
	assert_eq(card.get_size(), Vector2i(152, 100), "a card of another aspect gets a picture of its own size")
	var used := card.get_used_rect()
	assert_true(used.size.x >= 130 or used.size.y >= 86, "the board fills ~92 %% of the limiting side (%s)" % used)
	assert_null(LevelPreviewCache.image(null, Vector2i(10, 10)))
