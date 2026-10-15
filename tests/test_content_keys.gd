extends TestCase
## The key convention of data/content (docs/CONTENT.md "Keys"): every key starts with its type's singular key folder
## (ContentFiles.KEY_FOLDERS: Status/Burn in Statuses.json), no plural folder is left anywhere in a key
## (Unit/Enemy/…, not Units/Enemies/…), and every reference to a content key resolves. The frozen oracle snapshot
## (~/godot/oracle/content, Unity's plural keys) still loads, since the loader assumes no prefix.

const ORACLE := "/home/ubuntu/godot/oracle/content"

## Unity's plural key folders (the old convention).
const PLURAL_TOP := ["Statuses", "Reactions", "Abilities", "Passives", "Units", "Towers", "Levels", "Terrains", "Tiles",
	"Forms", "Tokens", "Missions", "Sequences", "Items"]

func _files() -> Array:
	var out := []
	for f in DirAccess.get_files_at(ContentFiles.Folder):
		if not f.ends_with(".json"): continue
		var root = JSON.parse_string(FileAccess.get_file_as_string(ContentFiles.Folder.path_join(f)))
		if root is Dictionary and root.get("assets") is Dictionary: out.append([f, root])
	return out

func test_every_key_uses_its_singular_folder() -> void:
	var n := 0
	for pair in _files():
		var f: String = pair[0]
		var type_name: String = str(pair[1].get("type", ""))
		if not ContentSerializer.ASSET_TYPES.has(type_name): continue
		assert_true(ContentFiles.KEY_FOLDERS.has(type_name), "%s: %s has a key folder" % [f, type_name])
		var folder: String = ContentFiles.KEY_FOLDERS.get(type_name, "")
		for key in pair[1]["assets"]:
			n += 1
			assert_true(str(key).begins_with(folder + "/"), "%s: %s starts with %s/" % [f, key, folder])
			var parts: PackedStringArray = str(key).split("/")
			assert_false(PLURAL_TOP.has(parts[0]), "%s: %s uses a plural folder" % [f, key])
			for i in range(1, parts.size() - 1):
				assert_false(ContentFiles.PLURAL_SUBFOLDERS.has(parts[i]), "%s: %s: sub-folder '%s' is plural" % [f, key, parts[i]])
	assert_true(n > 200, "checked %d keys" % n)

func test_every_reference_resolves() -> void:
	var lib := ContentLibrary.load()
	assert_eq(lib.problems, [], "the content loads without problems")
	var folders := {}
	for t in ContentFiles.KEY_FOLDERS: folders[ContentFiles.KEY_FOLDERS[t]] = true
	for p in PLURAL_TOP: folders[p] = true
	var refs := 0
	var bad := []
	for pair in _files():
		var f: String = pair[0]
		var stack: Array = []
		for key in pair[1]["assets"]: stack.append([pair[1]["assets"][key], key])
		while not stack.is_empty():
			var item: Array = stack.pop_back()
			var v = item[0]
			if v is Dictionary:
				for k in v: stack.append([v[k], "%s.%s" % [item[1], k]])
			elif v is Array:
				for i in v.size(): stack.append([v[i], "%s[%d]" % [item[1], i]])
			elif v is String and v.contains("/") and folders.has(v.get_slice("/", 0)):
				refs += 1
				if lib.get_asset(v) == null: bad.append("%s: %s → %s" % [f, item[1], v])
	assert_true(refs > 300, "checked %d references" % refs)
	assert_eq(bad, [], "references that name no entry")

func test_tutorial_and_coop_data_name_no_old_keys() -> void:
	for path in ["res://data/tutorial.json", "res://data/coop.json"]:
		var text := FileAccess.get_file_as_string(path)
		for p in PLURAL_TOP: assert_false(text.contains("\"%s/" % p), "%s has an old %s/ key" % [path, p])

func test_the_oracle_snapshot_still_loads_with_plural_keys() -> void:
	if not DirAccess.dir_exists_absolute(ORACLE): return # only on the server
	var lib := ContentLibrary.load(ORACLE)
	assert_eq(lib.problems, [], "the frozen snapshot loads as it is")
	assert_not_null(lib.get_asset("Statuses/Burn"))
	assert_not_null(lib.get_asset("Units/Enemies/Rabbit"))
	assert_eq(lib.all_of("LevelAsset").size(), 11)
