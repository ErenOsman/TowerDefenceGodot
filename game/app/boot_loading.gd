extends Control
## The Boot scene's plain loading panel (UI_BootLoading.cs): a bar that fills over at least
## MINIMUM_DISPLAY_TIME while the content loads, "Complete!", then Welcome on a first launch (no profile in
## the save) or the main menu.
## After the content, the pre-warm runs so no screen hitches on its first open (docs/Implementation Notes.md
## "Boot"). Three kinds of work, in priority order (STEPS: the first screen's needs first):
##   fonts: one Label per font + size (+ outline) the UI uses (font_variants()) with the Latin alphabet, digits and
##      the Turkish letters, so the glyph atlases are built now;
##   art: a group of files (preload_groups(): menu, camp, places, level) loads (threaded; on the web a time slice
##      per frame), then each loaded model is drawn once in a hidden SubViewport (the place dioramas' light and an
##      omni light, shadows on) so GL Compatibility compiles its materials; the "shared" step draws the board's
##      materials, the place props' overlays, one effect per VFX material variant and the UI's canvas shaders;
##   screens: each heavy popup (SCREENS_A, SCREENS_B) is instantiated and opened once under a CanvasLayer behind
##      the Boot panel, drawn, then freed (its scripts, styleboxes, textures and model previews ready).
## Everything after the menu step has a budget (BUDGET_WEB_MS from the Boot's start on the web, so the Boot stays
## under ~3 s; BUDGET_NATIVE_MS natively): what does not fit is skipped (it loads on first use, as before) and the
## "[Boot]" log line names it, with each stage's ms. TD_NO_PRELOAD=1 skips the whole pre-warm. Loaded resources stay
## alive in GameApp.keep().

const MINIMUM_DISPLAY_TIME := 1.5
const POST_LOAD_DELAY := 0.5

var _fill: ProgressBar
var _status: Label
var _percent: Label
var _timer := 0.0
var _progress := 0.0   # real work done (0..1)
var _done := false
var _last_usec := 0

## Bar share of the content load; the steps share the rest by their weights (STEPS).
const CONTENT_SHARE := 0.08
## The pre-warm in priority order: [step, bar weight]. "art:<group>" = a preload_groups() group loaded then drawn;
## "screens:A|B" = those popups opened once.
const STEPS := [["fonts", 0.06], ["art:menu", 0.12], ["shared", 0.05], ["art:camp", 0.25], ["screens:A", 0.12],
	["art:places", 0.15], ["screens:B", 0.09], ["art:level", 0.08]]
## Synchronous work (the web) per frame before the bar redraws (ms).
const FRAME_SLICE_MS := 30
## The work budget from the Boot's start (ms) for everything after the menu step. Web (desktop browser, no
## threads): the Boot must end by ~3 s, MINIMUM_DISPLAY_TIME and POST_LOAD_DELAY included. Native: a safety net for
## slow machines. TD_BOOT_BUDGET_MS overrides both (measurements).
const BUDGET_WEB_MS := 2300
const BUDGET_NATIVE_MS := 4000
const MENU_MODELS := ["Archer", "Guardian", "Mage"]
const TILE_PIECES := ["Ground A", "Ground B", "Ground C", "Ground D", "Board Edge Side", "Board Edge Corner"]
const BACKGROUND := "res://art/ui/Backgrounds/Spitters Blurred.png"
const THEME := "res://game/ui/theme/td_theme.tres"
const HUD := "res://game/ui/hud/hud.tscn"
const SCREENS := "res://game/ui/screens/"
## The places whose kits load (res://art/<kit>/layout.json): the Camp in the camp group, the others in places.
const PLACES := ["camp", "guild", "blacksmith"]
## The heavy popups warmed once (a scene game/ui/screens/<name>.tscn, else the script <name>.gd): A = opened from
## the main menu and the Camp, B = from the Blacksmith and the Guild.
const SCREENS_A := ["settings", "hand_editor", "codex"]
const SCREENS_B := ["workshop", "upgrade", "mission_board", "backpack", "rewards"]
## Glyphs drawn per font variant: the Latin alphabet, digits, Turkish letters, the punctuation the UI prints.
const GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 ÇĞİÖŞÜçğıöşü .,:;!?%+-–—×/()[]'\"…·•→←✓"
## Explicit sizes the screens use besides the type scale and the theme (grep of apply_type / TdMenu.label /
## font_size overrides, 2026-10-18), by FONT_FILES key.
const FONT_SIZES := {
	"plinth": [18, 20, 22, 24, 26, 28, 30, 32, 34, 40, 44, 48, 52, 56, 64, 72, 76],
	"nunito_bold": [18, 20, 22, 24, 26],
	"nunito_extrabold": [18, 20, 22],
	"nunito_medium": [20, 22, 24],
}
## Outlined text (over the board and the HUD: OverlayStyle.world_label, TdTheme.outline): [family, size, outline].
const OUTLINED := [["plinth", 18, 4], ["plinth", 20, 4], ["plinth", 22, 4], ["plinth", 24, 4], ["plinth", 26, 4],
	["plinth", 28, 4], ["plinth", 22, 6], ["plinth", 26, 6], ["nunito_extrabold", 18, 4], ["nunito_extrabold", 20, 4]]
## Labels added per drawn frame in the font step.
const FONT_BATCH := 10

var _groups := {}                 # group name → Array[String] (preload_groups)
var _loaded := {}                 # path → Resource (or null when it failed)
var _threaded := false
var _start_ms := 0
var _budget_ms := BUDGET_NATIVE_MS
var _layer: CanvasLayer           # behind the Boot panel: fonts, canvas shaders and screens draw there
var _vp: SubViewport              # the hidden 3D world the models are drawn in
var _root3d: Node3D
var _skipped: Array[String] = []  # what did not fit the budget or could not be made
var _stats := {"fonts": 0, "art": 0, "screens": 0, "files": 0, "models": 0, "materials": 0, "effects": 0, "screens_done": 0, "font_variants": 0}
var _step_ms: Array[String] = []
var _base := 0.0                  # bar progress before the running step
var _weight := 0.0                # the running step's bar weight

func _ready() -> void:
	_build()
	_set_status("Loading…")
	_last_usec = Time.get_ticks_usec()
	# let the panel draw once, then load the content (synchronous; one long frame)
	await get_tree().process_frame
	await get_tree().process_frame
	_start_ms = Time.get_ticks_msec()
	GameApp.ensure_loaded()
	var content_ms := Time.get_ticks_msec() - _start_ms
	_progress = CONTENT_SHARE
	# TD_NO_PRELOAD=1 skips the whole pre-warm (to measure the first openings without it)
	if OS.get_environment("TD_NO_PRELOAD") != "":
		print("[Boot] content %d ms; pre-warm skipped (TD_NO_PRELOAD)" % content_ms)
		_progress = 1.0
		return
	_threaded = not OS.has_feature("web") and OS.has_feature("threads")
	_budget_ms = BUDGET_WEB_MS if OS.has_feature("web") else BUDGET_NATIVE_MS
	if OS.get_environment("TD_BOOT_BUDGET_MS").is_valid_int(): _budget_ms = OS.get_environment("TD_BOOT_BUDGET_MS").to_int()
	_groups = preload_groups()
	_layer = CanvasLayer.new()
	_layer.layer = -10 # under the Boot panel (opaque): drawn for real, never seen
	add_child(_layer)
	_build_world()
	_base = CONTENT_SHARE
	for st in STEPS:
		var step: String = st[0]
		_weight = st[1]
		var t := Time.get_ticks_msec()
		if step == "fonts": await _prewarm_fonts()
		elif step == "shared": await _prewarm_shared()
		elif step.begins_with("art:"): await _prewarm_art(step.substr(4))
		elif step == "screens:A": await _prewarm_screens(SCREENS_A)
		elif step == "screens:B": await _prewarm_screens(SCREENS_B)
		var ms := Time.get_ticks_msec() - t
		_step_ms.append("%s %d" % [step, ms])
		var kind := "fonts" if step == "fonts" else ("screens" if step.begins_with("screens") else "art")
		_stats[kind] += ms
		_base += _weight
		_progress = _base
	if _vp != null: _vp.queue_free()
	_layer.queue_free()
	for p in _loaded:
		GameApp.keep(p, _loaded[p])
	var total := Time.get_ticks_msec() - _start_ms
	print("[Boot] content %d ms | fonts %d ms (%d variants) | art %d ms (%d files loaded, %d models + %d materials + %d effects drawn) | screens %d ms (%d popups) | total %d ms, budget %d ms | steps: %s%s" % [
		content_ms, _stats.fonts, _stats.font_variants, _stats.art, _stats.files, _stats.models, _stats.materials,
		_stats.effects, _stats.screens, _stats.screens_done, total, _budget_ms, ", ".join(_step_ms),
		"" if _skipped.is_empty() else " | skipped %d: %s" % [_skipped.size(), ", ".join(_skipped)]])
	_progress = 1.0

func _elapsed() -> int:
	return Time.get_ticks_msec() - _start_ms

## The budget is spent.
func _over() -> bool:
	return _elapsed() > _budget_ms

## One frame drawn (headless, where nothing is drawn: one processed frame, so tools and probes do not hang).
func _drawn() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

func _step_progress(f: float) -> void:
	_progress = _base + _weight * clampf(f, 0.0, 1.0)

# ------------------------------------------------------------------ what loads

## Everything the Boot loads ahead, flattened in priority order (see preload_groups).
static func preload_paths() -> Array[String]:
	var out: Array[String] = []
	var groups := preload_groups()
	for g in ["menu", "camp", "places", "level"]:
		for p in groups[g]:
			if not out.has(p): out.append(p)
	return out

## The preload by group (each path in the first group that names it):
##   menu: the theme, the menu background, the Welcome / main menu / loading scenes, the menu diorama's tiles and
##     miniatures (the first screen's needs; never skipped);
##   camp: the Camp's and level select's scenes, the Camp kit, the whole map kit, the starting and hand towers;
##   places: the Guild's and the Blacksmith's kits and scenes;
##   level: the level and its HUD, the coming level's enemies, the board decals (the level loads behind its
##     loading screen, so these come last).
static func preload_groups() -> Dictionary:
	var taken := {}
	var groups := {"menu": [] as Array[String], "camp": [] as Array[String], "places": [] as Array[String], "level": [] as Array[String]}
	var add := func(g: String, p: String):
		if p == "" or taken.has(p) or not ResourceLoader.exists(p): return
		taken[p] = true
		groups[g].append(p)
	add.call("menu", THEME)
	add.call("menu", BACKGROUND)
	for id in [SceneFlow.Welcome, SceneFlow.MainMenu, SceneFlow.Loading]: add.call("menu", SceneFlow.path_of(id))
	for piece in TILE_PIECES: add.call("menu", "res://art/tiles/%s.fbx" % piece)
	for m in MENU_MODELS: add.call("menu", "res://art/models/%s.fbx" % m)
	for id in [SceneFlow.Camp, SceneFlow.LevelSelect]: add.call("camp", SceneFlow.path_of(id))
	add.call("camp", SCREENS + "chapter_select.tscn")
	for p in place_paths("camp"): add.call("camp", p)
	var catalog: GameCatalogAsset = GameApp.catalog
	var rules = GameApp.lib.rules if GameApp.loaded else null
	if rules != null:
		for tile in rules.tiles:
			if tile != null and "view" in tile: add.call("camp", ArtPaths.model(tile.view))
	if catalog != null:
		for t in catalog.starting_towers:
			if t != null and t.entity != null: add.call("camp", ArtPaths.model(t.entity.view))
		for id in SaveData.towers.hand:
			var owned = SaveData.towers.find(str(id))
			var ta: TowerAsset = catalog.find_tower(owned.type) if owned != null else null
			if ta != null and ta.entity != null: add.call("camp", ArtPaths.model(ta.entity.view))
	for kit in PLACES:
		if kit != "camp":
			for p in place_paths(kit): add.call("places", p)
	for id in [SceneFlow.Guild, SceneFlow.Blacksmith]: add.call("places", SceneFlow.path_of(id))
	add.call("level", SceneFlow.path_of(SceneFlow.Game))
	add.call("level", HUD)
	if catalog != null:
		var levels := []
		if SaveData.profile.is_first_run or SaveData.profile.tutorial_pending: levels.append(catalog.tutorial)
		levels.append(GameApp.next_main_level())
		for l in levels:
			for e in CodexAsset.enemies_of(l):
				if e != null: add.call("level", ArtPaths.model(e.view))
	for f in ResourceLoader.list_directory("res://art/ui/KitB/board/"):
		if f.ends_with(".png"): add.call("level", "res://art/ui/KitB/board/" + f)
	return groups

## The model files of a place's kit: every prop named in res://art/<kit>/layout.json (slots, centre, decor), looked
## up in the layout's "kits" (default: the kit itself), then the map kit (res://art/tiles/, e.g. the Camp's
## Signpost); the Camp's ground piece first when it exists. When the layout cannot be read: every FBX in the folder.
static func place_paths(kit: String) -> Array[String]:
	var out: Array[String] = []
	var ground := "res://art/%s/%s Ground.fbx" % [kit, kit.capitalize()]
	if ResourceLoader.exists(ground): out.append(ground)
	var json := JSON.new()
	var text := FileAccess.get_file_as_string("res://art/%s/layout.json" % kit)
	if text == "" or json.parse(text) != OK or not (json.data is Dictionary):
		for f in ResourceLoader.list_directory("res://art/%s/" % kit):
			if f.ends_with(".fbx") and not out.has("res://art/%s/%s" % [kit, f]): out.append("res://art/%s/%s" % [kit, f])
		return out
	var names := []
	_collect_props(json.data, names)
	var kits: Array = json.data.get("kits", [kit])
	for n in names:
		var found := ""
		for k in kits:
			var p := "res://art/%s/%s.fbx" % [k, n]
			if ResourceLoader.exists(p):
				found = p
				break
		if found == "" and ResourceLoader.exists("res://art/tiles/%s.fbx" % n): found = "res://art/tiles/%s.fbx" % n
		if found != "" and not out.has(found): out.append(found)
	return out

## Every "prop" value of a layout (slots, centre, decor; null props skipped).
static func _collect_props(v, names: Array) -> void:
	if v is Dictionary:
		for k in v:
			if k == "prop" and v[k] is String and not names.has(v[k]): names.append(v[k])
			else: _collect_props(v[k], names)
	elif v is Array:
		for e in v: _collect_props(e, names)

## Every font variant the UI draws: [Font, size, outline] for the type scale (TdTokens.TYPE), every font of the
## theme's types with its size, FONT_SIZES and OUTLINED; without repeats.
static func font_variants() -> Array:
	var out := []
	var seen := {}
	var add := func(f: Font, s: int, o: int):
		if f == null or s <= 0: return
		var k := "%d|%d|%d" % [f.get_instance_id(), s, o]
		if seen.has(k): return
		seen[k] = true
		out.append([f, s, o])
	for role in TdTokens.TYPE: add.call(TdTheme.font(role), TdTheme.font_size(role), 0)
	var th := TdTheme.theme()
	if th != null:
		if th.default_font != null: add.call(th.default_font, th.default_font_size, 0)
		for type in th.get_font_type_list():
			for fname in th.get_font_list(type):
				var sname: String = "font_size" if fname == "font" else fname + "_size"
				var s := th.default_font_size
				if th.has_font_size(sname, type): s = th.get_font_size(sname, type)
				elif th.has_font_size("font_size", type): s = th.get_font_size("font_size", type)
				add.call(th.get_font(fname, type), s, 0)
	for fam in FONT_SIZES:
		for s in FONT_SIZES[fam]: add.call(TdTheme.font(fam), s, 0)
	for e in OUTLINED: add.call(TdTheme.font(e[0]), e[1], e[2])
	return out

# ------------------------------------------------------------------ fonts

## One Label per font variant with GLYPHS, FONT_BATCH per drawn frame, behind the Boot panel (the same viewport,
## so the same oversampling as the screens). Never skipped: the first screen needs them.
func _prewarm_fonts() -> void:
	var variants := font_variants()
	_stats.font_variants = variants.size()
	var labels := []
	var i := 0
	while i < variants.size():
		for k in FONT_BATCH:
			if i >= variants.size(): break
			var v: Array = variants[i]
			var l := Label.new()
			l.text = GLYPHS
			l.add_theme_font_override("font", v[0])
			l.add_theme_font_size_override("font_size", v[1])
			if v[2] > 0:
				l.add_theme_constant_override("outline_size", v[2])
				l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			l.position = Vector2(0, (i % 12) * 80)
			_layer.add_child(l)
			labels.append(l)
			i += 1
		await _drawn()
		_step_progress(float(i) / maxf(1.0, variants.size()))
	for l in labels: l.queue_free()

# ------------------------------------------------------------------ art

## The hidden 3D world: the place dioramas' light (shadows on), an omni light like the Guild's hearth and the
## Smithy's embers (GL Compatibility draws positional lights in their own pass: their variant compiles too), a
## camera on the origin, where every model is put.
func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 256)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	add_child(_vp)
	_root3d = Node3D.new()
	_vp.add_child(_root3d)
	TdDiorama._add_light(_root3d, Color(0.1, 0.1, 0.1))
	var omni := OmniLight3D.new()
	omni.omni_range = 30.0
	omni.position = Vector3(0, 2, 2)
	_root3d.add_child(omni)
	var cam := Camera3D.new()
	cam.fov = 60.0
	_root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3, 7), Vector3(0, 0.5, 0))
	cam.current = true

## A group: its files load (threaded, or a time slice per frame), then each loaded model is drawn once (a time
## slice of them per frame, each batch freed once drawn). The menu group is never skipped; the others stop when the
## budget is spent (the rest is named in the log).
func _prewarm_art(group: String) -> void:
	var paths: Array = _groups.get(group, [])
	var must := group == "menu"
	var total := maxf(1.0, paths.size() * 2.0) # loading, then drawing
	var done: Array[String] = []
	if not must and _over() and not paths.is_empty():
		_skipped.append("%s: %d files not loaded (%s…)" % [group, paths.size(), paths[0].get_file()])
		return
	if _threaded:
		var pending: Array[String] = []
		for p in paths:
			if ResourceLoader.load_threaded_request(p, "", true) == OK: pending.append(p)
			else:
				_loaded[p] = load(p)
				done.append(p)
		while not pending.is_empty():
			var sum := float(done.size())
			for p in pending.duplicate():
				var prog := []
				var st := ResourceLoader.load_threaded_get_status(p, prog)
				if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					sum += float(prog[0]) if not prog.is_empty() else 0.0
					continue
				_loaded[p] = ResourceLoader.load_threaded_get(p) if st == ResourceLoader.THREAD_LOAD_LOADED else null
				pending.erase(p)
				done.append(p)
				sum += 1.0
			if not must and _over(): # left to finish in the background; they load on first use
				_skipped.append("%s: %d files not loaded (%s…)" % [group, pending.size(), pending[0].get_file()])
				pending.clear()
			_step_progress(sum / total)
			await get_tree().process_frame
	else:
		var i := 0
		while i < paths.size():
			var slice := Time.get_ticks_msec()
			while i < paths.size() and Time.get_ticks_msec() - slice < FRAME_SLICE_MS:
				if not must and _over():
					_skipped.append("%s: %d files not loaded (%s…)" % [group, paths.size() - i, paths[i].get_file()])
					i = paths.size()
					break
				_loaded[paths[i]] = load(paths[i])
				done.append(paths[i])
				i += 1
			_step_progress(float(i) / total)
			await get_tree().process_frame
	_stats.files += done.size()
	if group == "menu" and _loaded.get(THEME) != null: TdTheme.theme()
	var scenes: Array[String] = []
	for p in done:
		if _loaded.get(p) is PackedScene and p.begins_with("res://art/"): scenes.append(p) # art only: screens run their _ready
	var i := 0
	while i < scenes.size():
		if not must and _over():
			_skipped.append("%s: %d models not drawn" % [group, scenes.size() - i])
			break
		var batch := []
		var slice := Time.get_ticks_msec()
		while i < scenes.size() and Time.get_ticks_msec() - slice < FRAME_SLICE_MS:
			var inst := (_loaded[scenes[i]] as PackedScene).instantiate()
			_root3d.add_child(inst)
			if inst is Node3D: (inst as Node3D).scale = Vector3.ONE * 0.5 # all at the origin: inside the camera's view
			TdDiorama._idle(inst) # skinned and animated, as on screen
			batch.append(inst)
			i += 1
		await _drawn()
		for n in batch: n.queue_free()
		_stats.models += batch.size()
		_step_progress((paths.size() + float(i) * paths.size() / scenes.size()) / total)

var _canvas_nodes: Array = []

## The shared look, drawn once: the board's materials (BoardMaterials lit, overlay, decal, on-top: their shader
## depends on the flags only, so one of each compiles every colour and decal) and the place props' glow / dim
## overlays in the 3D world, one effect per VFX material variant (VfxKit.warm_set, emitting for two frames), and the
## UI's canvas shaders plus the menu background behind the Boot panel.
func _prewarm_shared() -> void:
	if _over():
		_skipped.append("shared materials")
		return
	_stats.materials = _warm_materials(_root3d) + _warm_canvas()
	var fx_nodes := []
	if VfxKit.enabled:
		for n in VfxKit.warm_set():
			var fx := VfxKit.build(n)
			if fx == null: continue
			_root3d.add_child(fx)
			VfxKit.start(fx)
			fx_nodes.append(fx)
	_stats.effects = fx_nodes.size()
	_step_progress(0.3)
	await _drawn()
	_step_progress(0.7)
	await _drawn()
	for n in fx_nodes + _canvas_nodes + _material_nodes:
		if is_instance_valid(n): n.queue_free()
	_canvas_nodes.clear()
	_material_nodes.clear()

var _material_nodes: Array = []

## Quads and boxes with the board's shared materials and the place props' overlays. Returns how many materials.
func _warm_materials(root: Node3D) -> int:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var mats: Array[Material] = [BoardMaterials.lit(Color(0.5, 0.5, 0.5)), BoardMaterials.overlay(Color(1, 1, 1, 0.5)),
		BoardMaterials.decal(tex, Color(1, 1, 1, 0.9)), BoardMaterials.on_top(tex, Color(1, 1, 1, 0.9))]
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	for k in mats.size():
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mats[k]
		mi.position = Vector3(k * 0.3 - 0.45, 0.05, 1.0)
		root.add_child(mi)
		_material_nodes.append(mi)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.3
	var overlays: Array[Material] = [TdStationWorld.glow_material(), TdStationWorld.dim_material()]
	for k in overlays.size():
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = BoardMaterials.lit(Color(0.6, 0.5, 0.4))
		mi.material_overlay = overlays[k]
		mi.position = Vector3(k - 0.5, 0.2, 1.5)
		root.add_child(mi)
		_material_nodes.append(mi)
	return mats.size() + overlays.size()

## TextureRects behind the Boot panel with the UI's own canvas shaders (button gold tint, round portraits and their
## greyed form, the menu diorama's blur, the Guild backdrop, the co-op picture's grey, the tutorial dims) and the menu
## background. Returns how many shaders.
func _warm_canvas() -> int:
	var img := Image.create(8, 8, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.7, 0.6, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var mats: Array[Material] = [TdButton.gold_tint_material(), TdMenu.circle_material(), TdMenu.grey_circle_material(),
		TdGuildBackdrop.material_warm(), CoopBoardPic.grey_material()]
	for sh in [TdDiorama.blur_shader(), HudSequence.dim_shader(), SequenceMarks.dim_shader()]:
		var m := ShaderMaterial.new()
		m.shader = sh
		mats.append(m)
	for k in mats.size():
		var tr := TextureRect.new()
		tr.texture = tex
		tr.material = mats[k]
		tr.size = Vector2(16, 16)
		tr.position = Vector2(k * 20, 0)
		_layer.add_child(tr)
		_canvas_nodes.append(tr)
	var bg := _loaded.get(BACKGROUND) as Texture2D
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.size = Vector2(64, 64)
		tr.position = Vector2(0, 40)
		_layer.add_child(tr)
		_canvas_nodes.append(tr)
	return mats.size()

# ------------------------------------------------------------------ screens

## Each popup once: instantiated under the CanvasLayer behind the Boot panel, opened (its content built from the
## save, as on a real opening), drawn, then freed (its _exit_tree releases the game keys). A popup that cannot be
## made is skipped and named in the log; so is the rest once the budget is spent.
func _prewarm_screens(names: Array) -> void:
	var n := 0
	for k in names.size():
		var s: String = names[k]
		if _over():
			for j in range(k, names.size()): _skipped.append("screen " + names[j])
			break
		var p := _make_screen(s)
		if p == null:
			_skipped.append("screen %s (cannot be made)" % s)
			continue
		if "free_on_close" in p: p.free_on_close = false
		_layer.add_child(p)
		if p.has_method("open"): p.open()
		await get_tree().process_frame # open()'s own frame: its window's transition starts
		if is_instance_valid(p) and "window" in p and p.window != null: p.window.modulate.a = 1.0
		await _drawn()
		await _drawn()
		if is_instance_valid(p): p.queue_free()
		n += 1
		_step_progress(float(k + 1) / names.size())
	_stats.screens_done += n

## A popup by name: its scene, else its script (MissionBoardScreen has no scene); null when neither. The Rewards
## popup gets the first mission (it shows nothing without one).
func _make_screen(s: String) -> Control:
	var scene_path: String = SCREENS + s + ".tscn"
	var script_path: String = SCREENS + s + ".gd"
	var p: Control = null
	if ResourceLoader.exists(scene_path):
		var sc := load(scene_path) as PackedScene
		if sc != null:
			_loaded[scene_path] = sc
			p = sc.instantiate() as Control
	elif ResourceLoader.exists(script_path):
		var sc := load(script_path) as Script
		if sc != null and sc.can_instantiate():
			_loaded[script_path] = sc
			p = sc.new() as Control
	if p != null and "mission_id" in p:
		var ms: Array = GameApp.missions()
		if not ms.is_empty() and ms[0] != null: p.mission_id = ms[0].id
	return p

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
