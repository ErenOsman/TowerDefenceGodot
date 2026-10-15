class_name ContentLibrary
extends RefCounted
## The game's content loaded straight from the JSON files (res://data/content, the source of truth: docs/Content.md):
## every entry becomes an asset object named after its key, and references between entries are linked. References to art (sprites, prefabs, sounds: keys under "Assets/")
## stay strings; the rules never read them. Feed the objects to an AssetConverter and AssetValidator.

var _by_key := {}  # key → asset
var _keys := {}    # asset → key
var _files := {}   # asset → file name

## Problems found while loading ("Units.json: Unit/Enemy/Rabbit.stats[0]…: …").
var problems: Array[String] = []

## Files whose type is not a content asset type here (presentation settings: PresentationTimings, UITheme).
var skipped: Array[String] = []

## The parsed JSON root of each skipped file ({"type", "assets"}), by file name, for the presentation layer.
## (Not in the C#, where those files load into their own Unity classes.)
var skipped_json := {}

## Every loaded object, in file then key order.
var all: Array:
	get: return _by_key.values()

## Every loaded object of a class (C# AllOf<T>), e.g. all_of("LevelAsset").
func all_of(type_name: String) -> Array:
	var result := []
	for a in _by_key.values():
		if ContentSerializer.is_type(a, type_name): result.append(a)
	return result

## The game catalog (Catalog.json), or null.
var catalog: GameCatalogAsset:
	get:
		var list := all_of("GameCatalogAsset")
		return list[0] if not list.is_empty() else null

## The game rules (Rules.json), or null.
var rules: GameRulesAsset:
	get:
		var list := all_of("GameRulesAsset")
		return list[0] if not list.is_empty() else null

## Loads every *.json file in the folder (res://data/content), in ordinal file-name order.
## extra: a candidate folder whose files are merged over the folder's: a file of the same name adds its entries to
## that file's (an entry with the same key replaces the folder's), other files are added. Used by the content check
## (tools/content_check.gd, the wiki's Content Editor) to try candidate entries without writing them into the game's
## folder.
static func load(folder: String = ContentFiles.Folder, extra: String = "") -> ContentLibrary:
	var library := ContentLibrary.new()
	var texts := _texts_of(folder)
	if extra != "" and DirAccess.dir_exists_absolute(extra):
		for pair in _texts_of(extra):
			var merged := false
			for i in texts.size():
				if texts[i][0] == pair[0]:
					texts[i] = [pair[0], _merge(texts[i][1], pair[1])]
					merged = true
					break
			if not merged: texts.append(pair)
		texts.sort_custom(func(a, b): return a[0] < b[0])
	library.add(texts)
	return library

## The game's content (res://data/content), with an optional candidate folder merged over it (see load()).
static func load_game(extra: String = "") -> ContentLibrary:
	return ContentLibrary.load(ContentFiles.Folder, extra)

static func _texts_of(folder: String) -> Array:
	var names := []
	for f in DirAccess.get_files_at(folder):
		if f.ends_with(".json"): names.append(f)
	names.sort() # ordinal
	var texts := []
	for f in names:
		texts.append([f, FileAccess.get_file_as_string(folder.path_join(f))])
	return texts

## Two content files of the same type as one: the candidate's entries over base's (texts that do not parse stay
## apart so add() reports them).
static func _merge(base_text: String, candidate_text: String) -> String:
	var a = JSON.parse_string(base_text)
	var b = JSON.parse_string(candidate_text)
	if not (a is Dictionary) or not (b is Dictionary) or not (a.get("assets") is Dictionary) or not (b.get("assets") is Dictionary):
		return base_text if not (b is Dictionary) else candidate_text
	for key in b["assets"]: a["assets"][key] = b["assets"][key]
	return JSON.stringify(a)

## Loads files given as text: an Array of [file name, JSON text].
func add(texts: Array) -> void:
	var work := [] # [asset, json, where]
	for pair in texts:
		var file: String = pair[0]
		var json := JSON.new()
		if json.parse(pair[1]) != OK:
			problems.append("%s: line %d: %s" % [file, json.get_error_line(), json.get_error_message()])
			continue
		var root = json.data
		if not (root is Dictionary):
			problems.append("%s: not a JSON object" % file)
			continue
		var type_name: String = root.get("type") if root.get("type") is String else ""
		if not ContentSerializer.ASSET_TYPES.has(type_name):
			skipped.append("%s: type '%s' is not loaded here" % [file, type_name])
			skipped_json[file] = root
			continue
		var entries = root.get("assets")
		if not (entries is Dictionary): continue
		for key in entries:
			var entry = entries[key]
			if not (entry is Dictionary):
				problems.append("%s: %s: not an object" % [file, key])
				continue
			if _by_key.has(key):
				problems.append("%s: %s: the key is used twice" % [file, key])
				continue
			var asset = ContentSerializer.create(type_name)
			asset.name = name_of(key)
			_by_key[key] = asset
			_keys[asset] = key
			_files[asset] = file
			work.append([asset, entry, "%s: %s" % [file, key]])
	# filled after every object exists, so entries can refer to each other in any order
	var list: Array = problems
	for w in work:
		ContentSerializer.load_into(w[0], w[1], self, list, w[2])
	_link_forms()

## Not in the C#: the Workshop links each tower type to its forms (TowerAsset.forms, content order) and lists every
## token kind and form on the catalog (GameCatalogAsset.tokens / forms), since neither is serialized there.
func _link_forms() -> void:
	for t in all_of("TowerAsset"): t.forms = []
	var forms := all_of("FormAsset")
	for f in forms:
		if f.tower != null: f.tower.forms.append(f)
	var c := catalog
	if c != null:
		c.forms = forms
		c.tokens = all_of("TokenAsset")

## The object an entry key names ("Unit/Enemy/Rabbit"), or null. (C# Get: `get` is Object's.)
func get_asset(key) -> ContentAsset:
	if key == null or not _by_key.has(key): return null
	return _by_key[key]

## The first object of a class with this asset name ("Rabbit"), or null (C# Find<T>(name)).
func find(type_name: String, asset_name: String) -> ContentAsset:
	for a in all_of(type_name):
		if a.name == asset_name: return a
	return null

## The JSON file an object came from ("Units.json").
func file_of(asset) -> String:
	return _files.get(asset, "") if asset != null else ""

## The object's entry key (null for objects not in the library). Art references are their own keys.
func key_of(o):
	if o == null: return null
	if o is String: return o
	return _keys.get(o)

## The object a key names when it is of the class (IContentRefs.Resolve), else null.
func resolve(key: String, type_name: String):
	var found = get_asset(key)
	if found != null: return found if ContentSerializer.is_type(found, type_name) else null
	return null

## Keys that are not content entries (art: "Assets/Art/…") are fine to leave unresolved.
func may_be_missing(key: String) -> bool:
	return not looks_like_content(key)

## Whether a key names content (Data assets and the catalog) rather than art.
static func looks_like_content(key: String) -> bool:
	return not key.begins_with("Assets/") or key.ends_with("GameCatalog.asset")

## An asset's name from its key: "Unit/Enemy/Rabbit" → "Rabbit", "Assets/Resources/GameCatalog.asset" → "GameCatalog".
static func name_of(key: String) -> String:
	var last := key.substr(key.rfind("/") + 1)
	return last.substr(0, last.length() - ".asset".length()) if last.ends_with(".asset") else last
