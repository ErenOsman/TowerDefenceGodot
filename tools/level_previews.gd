extends SceneTree
## Renders every level's picture to res://art/levels/previews/<level id>.png (+ previews.json with each level's
## content hash, LevelPreviewCache.content_hash) — the pre-rendered pictures every level preview shows
## (LevelPreviewCache). Same renderer as the live fallback (CoopBoardPic.render: 35°, yaw -8°, "contain",
## transparent background) at LevelPreviewCache.RENDER_SIZE (2× level select's picture). Needs a renderer:
##   cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot tools/level_previews.gd [-- <level id> …]
## With level ids only those are rendered (the others keep their manifest entries). Each PNG gets a "keep" .import
## (exported as is; LevelPreviewCache reads its bytes headless and on the web). Prints LEVEL PREVIEWS DONE.

const KEEP_IMPORT := "[remap]\n\nimporter=\"keep\"\n"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app: Node = root.get_node("GameApp")
	app.ensure_loaded()
	var only := OS.get_cmdline_user_args()
	var dir := ProjectSettings.globalize_path(LevelPreviewCache.DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var old := LevelPreviewCache.manifest()
	var levels: Dictionary = (old.get("levels", {}) as Dictionary).duplicate() if not only.is_empty() else {}
	var assets: Array = app.lib.all_of("LevelAsset")
	assets.sort_custom(func(a, b): return a.get_id() < b.get_id())
	var n := 0
	for lv: LevelAsset in assets:
		var id := lv.get_id()
		if not only.is_empty() and not only.has(id): continue
		var tex: Texture2D = await CoopBoardPic.render(root, lv, LevelPreviewCache.RENDER_SIZE, LevelPreviewCache.PITCH, LevelPreviewCache.YAW)
		if tex == null:
			print("LEVEL PREVIEW FAIL ", id)
			continue
		var img := tex.get_image()
		img.clear_mipmaps()
		var png := dir.path_join(id + ".png")
		img.save_png(png)
		var f := FileAccess.open(png + ".import", FileAccess.WRITE)
		f.store_string(KEEP_IMPORT)
		f.close()
		levels[id] = {"hash": LevelPreviewCache.content_hash(lv), "file": id + ".png"}
		n += 1
		print("level preview ", id, " ", levels[id].hash)
	var keys := levels.keys()
	keys.sort()
	var sorted := {}
	for k in keys: sorted[k] = levels[k]
	var m := {"version": LevelPreviewCache.RENDER_VERSION, "size": [LevelPreviewCache.RENDER_SIZE.x, LevelPreviewCache.RENDER_SIZE.y],
		"pitch": LevelPreviewCache.PITCH, "yaw": LevelPreviewCache.YAW, "levels": sorted}
	var mf := FileAccess.open(ProjectSettings.globalize_path(LevelPreviewCache.MANIFEST), FileAccess.WRITE)
	mf.store_string(JSON.stringify(m, "\t") + "\n")
	mf.close()
	print("LEVEL PREVIEWS DONE: %d rendered, %d in the manifest" % [n, sorted.size()])
	quit()
