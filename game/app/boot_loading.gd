extends Control
## The Boot scene's plain loading panel (UI_BootLoading.cs): a bar that fills over at least
## MINIMUM_DISPLAY_TIME while the content loads, "Complete!", then Welcome on a first launch (no profile in
## the save) or the main menu.
## Preload stage (so the first Camp / menu opening does not hitch): after the content, the camp props
## (art/camp/layout.json), the map-kit ground and board-edge pieces, the starting towers' models and the menu
## miniatures, the shared menu background, the UI theme and the menu screens' scenes load in the background (threaded; on the web a few
## per frame), the bar showing real progress; each loaded scene is then drawn once in a hidden SubViewport so
## GL Compatibility compiles its materials (shader pre-warm). Loaded resources stay alive in GameApp.keep().

const MINIMUM_DISPLAY_TIME := 1.5
const POST_LOAD_DELAY := 0.5

var _fill: ProgressBar
var _status: Label
var _percent: Label
var _timer := 0.0
var _progress := 0.0   # real work done (content loaded)
var _done := false
var _last_usec := 0

const CONTENT_SHARE := 0.1   # bar share of the content load
const WARM_SHARE := 0.1      # bar share of the shader pre-warm (the rest: the preload)
const SYNC_PER_FRAME := 2    # web / no threads: files loaded per frame
const MENU_MODELS := ["Archer", "Guardian", "Mage"]
const TILE_PIECES := ["Ground A", "Ground B", "Ground C", "Ground D", "Board Edge Side", "Board Edge Corner"]
const BACKGROUND := "res://art/ui/Backgrounds/Spitters Blurred.png"
const THEME := "res://game/ui/theme/td_theme.tres"

var _queue: Array[String] = []    # paths to preload
var _loaded := {}                 # path → Resource (or null when it failed)
var _threaded := false
var _requested := false
var _preload_done := false

func _ready() -> void:
	_build()
	_set_status("Loading…")
	_last_usec = Time.get_ticks_usec()
	# let the panel draw once, then load the content (synchronous; one long frame)
	await get_tree().process_frame
	await get_tree().process_frame
	GameApp.ensure_loaded()
	_progress = CONTENT_SHARE
	# TD_NO_PRELOAD=1 skips the stage (to measure the Camp's first open without it)
	_queue = preload_paths() if OS.get_environment("TD_NO_PRELOAD") == "" else ([] as Array[String])
	_threaded = not OS.has_feature("web") and OS.has_feature("threads")
	var t := Time.get_ticks_msec()
	await _preload()
	var t_load := Time.get_ticks_msec() - t
	await _prewarm()
	print("[Boot] preloaded %d files in %d ms, pre-warm %d ms" % [_loaded.size(), t_load, Time.get_ticks_msec() - t - t_load])
	_progress = 1.0

## Everything the Boot loads ahead: camp props, map-kit pieces, tower models, menu background, UI theme.
static func preload_paths() -> Array[String]:
	var out: Array[String] = []
	var add := func(p: String):
		if p != "" and not out.has(p) and ResourceLoader.exists(p): out.append(p)
	for prop in _camp_props(): add.call(ArtPaths.camp(prop))
	for piece in TILE_PIECES: add.call("res://art/tiles/%s.fbx" % piece)
	var catalog: GameCatalogAsset = GameApp.catalog
	if catalog != null:
		for t in catalog.starting_towers:
			if t != null and t.entity != null: add.call(ArtPaths.model(t.entity.view))
	for m in MENU_MODELS: add.call("res://art/models/%s.fbx" % m)
	add.call(BACKGROUND)
	add.call(THEME)
	# the screens between levels themselves (their scripts compile now; SceneFlow then opens them from the cache)
	for id in [SceneFlow.Welcome, SceneFlow.MainMenu, SceneFlow.Camp, SceneFlow.LevelSelect, SceneFlow.Loading]:
		add.call(SceneFlow.path_of(id))
	return out

## The prop names in res://art/camp/layout.json (every "prop" value), Camp Ground first when it exists.
static func _camp_props() -> Array:
	var names := []
	if ResourceLoader.exists("res://art/camp/Camp Ground.fbx"): names.append("Camp Ground")
	var text := FileAccess.get_file_as_string("res://art/camp/layout.json")
	var json := JSON.new()
	if text != "" and json.parse(text) == OK: _collect_props(json.data, names)
	return names

static func _collect_props(v, names: Array) -> void:
	if v is Dictionary:
		for k in v:
			if k == "prop" and v[k] is String and not names.has(v[k]): names.append(v[k])
			else: _collect_props(v[k], names)
	elif v is Array:
		for e in v: _collect_props(e, names)

func _preload() -> void:
	var total := maxi(_queue.size(), 1)
	if _threaded:
		for p in _queue:
			if ResourceLoader.load_threaded_request(p, "", true) != OK: _loaded[p] = load(p)
		while _loaded.size() < _queue.size():
			var sum := 0.0
			for p in _queue:
				if _loaded.has(p):
					sum += 1.0
					continue
				var prog := []
				var st := ResourceLoader.load_threaded_get_status(p, prog)
				if st == ResourceLoader.THREAD_LOAD_LOADED:
					_loaded[p] = ResourceLoader.load_threaded_get(p)
					sum += 1.0
				elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					sum += float(prog[0]) if not prog.is_empty() else 0.0
				else:
					_loaded[p] = null
					sum += 1.0
			_progress = CONTENT_SHARE + (1.0 - CONTENT_SHARE - WARM_SHARE) * sum / total
			await get_tree().process_frame
	else:
		var i := 0
		while i < _queue.size():
			for k in SYNC_PER_FRAME:
				if i >= _queue.size(): break
				_loaded[_queue[i]] = load(_queue[i])
				i += 1
			_progress = CONTENT_SHARE + (1.0 - CONTENT_SHARE - WARM_SHARE) * float(i) / total
			await get_tree().process_frame
	for p in _loaded:
		GameApp.keep(p, _loaded[p])
	if _loaded.has(THEME) and _loaded[THEME] != null: TdTheme.theme()
	_progress = 1.0 - WARM_SHARE

## Draws every loaded scene once in a hidden SubViewport (same light/environment as the menus' dioramas, shadows
## on) so their shaders compile now, not on the Camp's first frame; then frees it.
func _prewarm() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	TdDiorama._add_light(root, Color(0.1, 0.1, 0.1))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 3, 8)
	cam.look_at_from_position(cam.position, Vector3.ZERO)
	var n := 0
	for p in _loaded:
		var sc := _loaded[p] as PackedScene
		if sc == null or not p.begins_with("res://art/"): continue # art only: screens would run their _ready
		var inst := sc.instantiate()
		root.add_child(inst)
		if inst is Node3D: inst.position = Vector3((n % 5) - 2.0, 0, -(n / 5))
		n += 1
	# a TextureRect using the background, so its texture uploads now too
	var bg := _loaded.get(BACKGROUND) as Texture2D
	var tr: TextureRect = null
	if bg != null:
		tr = TextureRect.new()
		tr.texture = bg
		tr.size = Vector2(4, 4)
		vp.add_child(tr)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.queue_free()

func _process(_delta: float) -> void:
	if _done: return
	var now := Time.get_ticks_usec()
	# capped: a frame stalled by the load would otherwise fill the bar at once
	_timer += minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now
	var shown := minf(clampf(_timer / MINIMUM_DISPLAY_TIME, 0.0, 1.0), _progress)
	_update(shown)
	if _timer >= MINIMUM_DISPLAY_TIME and _progress >= 1.0:
		_done = true
		_update(1.0)
		_set_status("Complete!")
		await get_tree().create_timer(POST_LOAD_DELAY, true, false, true).timeout
		SceneFlow.go(destination())

## Welcome on a first launch, else the main menu.
static func destination() -> int:
	return SceneFlow.Welcome if SaveData.profile.is_first_run else SceneFlow.MainMenu

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Boot keeps the plain dark wood backdrop + vignette (user decision 2026-10-13: like the Unity boot screen);
	# the blurred diorama is for Welcome, Main menu and Loading only.
	if ClassDB.class_exists("TdMenu") or ResourceLoader.exists("res://game/ui/screens/parts/td_menu.gd"):
		TdMenu.wood_background(self, true)
	# the Unity boot: a centred rounded dark plaque (700×135) with the name, "Loading…" above a cobalt bar
	# (710×35) with the percentage centred in white inside it
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(710, 0)
	box.add_theme_constant_override("separation", 0)
	center.add_child(box)
	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(700, 135)
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plaque.add_theme_stylebox_override("panel", TdTheme.stylebox("menu_panel", Color.WHITE, [24, 8, 24, 12]))
	box.add_child(plaque)
	var title := Label.new()
	title.text = "Tower Defence"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.apply_type(title, "display", TdTheme.color("cream.100"), 72)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 4)
	plaque.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 72)
	box.add_child(gap)
	_status = Label.new()
	TdTheme.apply_type(_status, "small", TdTheme.color("cream.100"), 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap2)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(710, 35)
	bar.add_theme_stylebox_override("panel", TdTheme.stylebox("loadbar_track"))
	box.add_child(bar)
	_fill = ProgressBar.new() # kept as the value holder; drawn by _fill_box
	_fill.max_value = 1.0
	_fill.visible = false
	bar.add_child(_fill)
	_fill_box = Panel.new()
	_fill_box.add_theme_stylebox_override("panel", TdTheme.stylebox("loadbar_fill"))
	_fill_box.size = Vector2(0, 35)
	bar.add_child(_fill_box)
	_percent = Label.new()
	TdTheme.apply_type(_percent, "header", Color.WHITE, 22)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent.set_anchors_preset(Control.PRESET_FULL_RECT)
	TdTheme.outline(_percent, 4)
	bar.add_child(_percent)

var _fill_box: Panel

func _update(p: float) -> void:
	_fill.value = p
	_fill_box.size = Vector2(710.0 * clampf(p, 0.0, 1.0), 35)
	_fill_box.visible = p > 0.01
	_percent.text = "%d%%" % roundi(p * 100.0)

func _set_status(t: String) -> void:
	_status.text = t
