extends Node
## Autoload `GameApp`: the content (ContentLibrary + AssetConverter + catalog + rules), loaded once on first use
## (the Boot scene warms it), art lookups shared by every scene, the level launch request, the Camp rules
## (Camp.cs: home, Continue) and the dev shortcuts (DevShortcuts.cs).

const CONTENT_FOLDER := "res://data/content"

var _lib: ContentLibrary = null
var _convert: AssetConverter = null
var _rules: GameRules = null
var _tex_cache := {}    # res path → Texture2D or null
var _scene_cache := {}  # res path → PackedScene or null

## The content library (every asset in res://data/content, with res://data/content-godot merged over it).
var lib: ContentLibrary:
	get:
		ensure_loaded()
		return _lib

## The one AssetConverter (its cache keeps asset → def identities stable across the app).
var convert: AssetConverter:
	get:
		ensure_loaded()
		return _convert

## The game catalog (chapters, levels, tower types, tutorial, camp unlock, codex).
var catalog: GameCatalogAsset:
	get: return lib.catalog

## The engine rules, converted once.
var rules: GameRules:
	get:
		ensure_loaded()
		return _rules

## Whether the content has been loaded (it loads on first use).
var loaded: bool:
	get: return _lib != null

## Loads the content once; cheap afterwards.
func ensure_loaded() -> void:
	if _lib != null: return
	var t := Time.get_ticks_msec()
	_lib = ContentLibrary.load_game() # data/content + the Godot-only overlay data/content-godot (Workshop)
	_convert = AssetConverter.new()
	_rules = _convert.rules(_lib.rules) if _lib.rules != null else null
	for p in _lib.problems: push_warning("[GameApp] content: " + p)
	print("[GameApp] content loaded: %d assets in %d ms" % [_lib.all.size(), Time.get_ticks_msec() - t])

# ---------------------------------------------------------------- Workshop

## A tower type by id, converted once (its forms included), or null.
func tower_type(type_id: String) -> TowerType:
	var a: TowerAsset = catalog.find_tower(type_id) if catalog != null else null
	return convert.tower_type(a) if a != null else null

## What a level builds for an owned tower: its type as its current form (Workshop.resolve), or null.
func resolved_type(owned: OwnedTower) -> TowerType:
	return Workshop.resolve(owned, tower_type(owned.type)) if owned != null else null

# ---------------------------------------------------------------- art

## The Texture2D of an icon reference ("Assets/Art/Icons/…/X.png#X"), or of any UI sprite path; null when missing.
func icon_texture(unity_path: String) -> Texture2D:
	return _texture(ArtPaths.sprite(unity_path))

## A KitB sprite ("Assets/Art/UI/KitB/<group>/<name>.png", or "<group>/<name>" for short); null when missing.
func kit_texture(unity_path: String) -> Texture2D:
	var p := unity_path
	if not p.begins_with("Assets/") and not p.begins_with("res://"):
		p = "res://art/ui/KitB/" + p + ("" if p.ends_with(".png") else ".png")
	return _texture(ArtPaths.kit(p))

## A unit's portrait (res://art/portraits/<Unit>.png); null when there is none.
func portrait_texture(unit_name: String) -> Texture2D:
	return _texture(ArtPaths.portrait(unit_name))

## The model scene of a view path ("Assets/Art/Models/<Unit>/<Unit> Blender.prefab" → res://art/models/<Unit>.fbx,
## map kit pieces → res://art/tiles/); null when missing. Instantiate the result.
func model_scene(view_path: String) -> PackedScene:
	return _scene(ArtPaths.model(view_path))

## A Camp prop model (res://art/camp/<name>.fbx); null when missing.
func camp_scene(prop_name: String) -> PackedScene:
	return _scene(ArtPaths.camp(prop_name))

## A font from a content font reference or a file name ("Nunito-Bold"); null when missing.
func font_file(unity_path: String) -> Font:
	var p := ArtPaths.font(unity_path)
	return load(p) as Font if p != "" and ResourceLoader.exists(p) else null

## Keeps a resource loaded ahead of time (the Boot preload) alive and serves it from the caches above, so
## model_scene / icon_texture / load() of that path never hit the disk again.
func keep(path: String, res: Resource) -> void:
	if res == null: return
	if res is PackedScene: _scene_cache[path] = res
	elif res is Texture2D: _tex_cache[path] = res
	_kept[path] = res

var _kept := {}

func _texture(path: String) -> Texture2D:
	if path == "": return null
	if _tex_cache.has(path): return _tex_cache[path]
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

func _scene(path: String) -> PackedScene:
	if path == "": return null
	if _scene_cache.has(path): return _scene_cache[path]
	var s: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_scene_cache[path] = s
	return s

# ---------------------------------------------------------------- level launch

func _ready() -> void:
	_hook_coop.call_deferred() # the Net autoload comes after this one

## A co-op match started by the relay (Net.match_ready) opens the level (CoopLaunch).
func _hook_coop() -> void:
	var net := get_node_or_null("/root/Net")
	if net != null: CoopLaunch.hook(net)

## The level the Game scene should play (LevelLaunch.level); null = none requested.
var level_launch: LevelAsset:
	get: return LevelLaunch.level
	set(v): LevelLaunch.request(v)

## Requests a level and loads the Game scene (through the loading screen).
func play_level(level: LevelAsset) -> void:
	if level == null: return
	LevelLaunch.request(level)
	SceneFlow.go(SceneFlow.Game)

## Whether a level is the catalog's tutorial.
func is_tutorial(level: LevelAsset) -> bool:
	return NewGame.is_tutorial(level, catalog)

# ---------------------------------------------------------------- Camp (Camp.cs)

## The Camp is open: the catalog's camp_unlock level (Chapter 1's last) is won.
func camp_unlocked() -> bool:
	return catalog != null and catalog.camp_unlocked(SaveData.progress)

## The scene between levels: SceneFlow.Camp once unlocked, SceneFlow.LevelSelect before.
func home() -> int:
	return SceneFlow.Camp if camp_unlocked() else SceneFlow.LevelSelect

## What a button leading home says.
func home_label() -> String:
	return "Camp" if home() == SceneFlow.Camp else "Level select"

## Goes home (Camp or level select).
func go_home() -> void:
	SceneFlow.go(home())

## The next main-chapter level not won yet, or null.
func next_main_level() -> LevelAsset:
	return catalog.next_main_level(SaveData.progress) if catalog != null else null

## The level the main menu's Continue plays: the next main-chapter level, but none while that is still the
## very first level (Play starts it; Continue is for coming back to the story).
func continue_level() -> LevelAsset:
	var next := next_main_level()
	if next == null or catalog == null: return null
	var first: CatalogEntry = null
	for e in catalog.to_catalog().entries:
		var c = catalog.chapters[e.chapter]
		if c == null or c.kind == ChapterKind.Main:
			first = e
			break
	return null if first != null and first.level_id == next.get_id() else next

## Plays the Continue level; false when there is none.
func continue_game() -> bool:
	var next := continue_level()
	if next == null: return false
	play_level(next)
	return true

# ---------------------------------------------------------------- dev shortcuts (DevShortcuts.cs)

## Wins every level of Chapter 1 not won yet (with rewards), saves; returns how many. Then go_home() opens the Camp.
func complete_chapter1() -> int:
	var n := DevShortcuts.complete_chapter1(SaveData.data, catalog)
	SaveData.save()
	return n

## Wins the first count main-chapter levels not won yet (with rewards), saves; returns how many.
func win_first_levels(count: int) -> int:
	var n := DevShortcuts.win_first_levels(SaveData.data, catalog, count)
	SaveData.save()
	return n
