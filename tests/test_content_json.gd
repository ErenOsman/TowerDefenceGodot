extends TestCase
## Port of ContentJsonTests.cs — the content JSON format: assets → JSON → ContentLibrary → JSON gives the same
## data, and the library reports bad entries instead of throwing. (MiniJson_Lays_Out_Small_Things… is not ported:
## the port reads JSON with Godot's parser and never writes content files.)

## The example assets, written into files by type with keys "Type/name" (as the C# NameRefs does), load into a
## new library linked to each other, and write back to the same JSON.
func test_assets_to_json_to_library_to_json_changes_nothing() -> void:
	var source := ContentLibrary.load("res://data/content")
	var examples := []
	for a in source.all:
		if source.key_of(a).contains("Examples/") or a is TerrainAsset: examples.append(a)
	# what the examples reference must be in the files too (Base, Slime, Archer…): take their closure
	var level: LevelAsset = source.get_asset("Levels/Other/Example Level")
	examples.append(level)
	var queue := examples.duplicate()
	while not queue.is_empty():
		var a = queue.pop_back()
		for r in _refs(ContentSerializer.to_json(a, source), source):
			if not examples.has(r):
				examples.append(r)
				queue.append(r)

	var refs := NameRefs.new()
	for a in examples: refs.keys[a] = "%s/%s" % [a.type_name(), a.name]
	var files := {}
	for a in examples:
		var file := ContentFiles.file_of(a.type_name())
		if not files.has(file): files[file] = {"type": a.type_name(), "assets": {}}
		files[file]["assets"][refs.keys[a]] = ContentSerializer.to_json(a, refs)
	var texts := []
	for f in files: texts.append([f, JSON.stringify(files[f], "  ")])

	var library := ContentLibrary.new()
	library.add(texts)
	assert_eq(library.problems.size(), 0, "\n".join(library.problems))
	assert_eq(library.all.size(), examples.size())

	for original in examples:
		var key: String = refs.keys[original]
		var loaded = library.get_asset(key)
		assert_not_null(loaded, key)
		if loaded == null: continue
		assert_eq(loaded.type_name(), original.type_name(), key)
		assert_eq(loaded.name, original.name, key)
		assert_eq(JSON.stringify(ContentSerializer.to_json(loaded, library)), JSON.stringify(ContentSerializer.to_json(original, refs)), key)

	# the loaded copies are linked to each other, not to the originals
	var copy: LevelAsset = library.get_asset(refs.keys[level])
	assert_true(is_same(copy.bases[0].entity, library.get_asset(refs.keys[level.bases[0].entity])))
	var wall = null
	for k in copy.terrain_keys:
		if k.symbol == "#": wall = k.terrain
	assert_true(is_same(wall, library.get_asset("TerrainAsset/Wall")))
	assert_false(is_same(wall, source.get_asset("Terrains/Wall")))

func test_the_library_reports_bad_entries_instead_of_throwing() -> void:
	var library := ContentLibrary.new()
	library.add([
		["Units.json", "{ \"type\": \"EntityAsset\", \"assets\": { \"Units/A\": { \"displayName\": \"A\", \"nonsense\": 1, \"abilities\": [\"Abilities/Missing\"] } } }"],
		["Broken.json", "{ \"type\": \"EntityAsset\", \"assets\": { "],
		["Odd.json", "{ \"type\": \"NoSuchType\", \"assets\": {} }"],
	])
	assert_not_null(library.get_asset("Units/A"), "a good entry still loads")
	var problems := library.problems
	assert_true(problems.any(func(p): return p.contains("nonsense") and p.contains("no such field")), "\n".join(problems))
	assert_true(problems.any(func(p): return p.contains("Abilities/Missing") and p.contains("not found")))
	assert_true(problems.any(func(p): return p.begins_with("Broken.json")), "a broken file is reported with its name")
	assert_true(library.skipped.any(func(p): return p.begins_with("Odd.json")), "an unknown type is skipped, not an error")

func test_bad_values_are_reported_and_art_stays_a_string() -> void:
	var library := ContentLibrary.new()
	library.add([["Statuses.json", "{ \"type\": \"StatusAsset\", \"assets\": { \"Statuses/S\": { \"stacking\": \"Sideways\", \"icon\": \"Assets/Art/Icons/S.png#S\", \"reactions\": [\"Assets/Data/Nope\"] } } }"]])
	var s: StatusAsset = library.get_asset("Statuses/S")
	assert_eq(s.stacking, Stacking.Stack, "a bad enum name keeps the default")
	assert_true(library.problems.any(func(p): return p.contains("'Sideways' is not one of Stack, Refresh")), "\n".join(library.problems))
	assert_eq(s.icon, "Assets/Art/Icons/S.png#S")
	assert_eq(s.reactions.size(), 1)
	assert_null(s.reactions[0], "art-like keys (Assets/…) may be missing")
	assert_eq(ContentSerializer.slot_of("StatusAsset", "shieldPool").spec, "OnHit")
	assert_true(ContentSerializer.slot_of("StatusAsset", "shieldPool").optional)
	assert_eq(ContentSerializer.slot_of("AttackStepData", "areaFilter").spec, "TargetFilter")
	assert_null(ContentSerializer.slot_of("StatusAsset", "stacking"))
	assert_eq(ContentFiles.asset_path_of("Units/Enemies/Rabbit"), "Assets/Data/Units/Enemies/Rabbit.asset")
	assert_eq(ContentFiles.asset_path_of("Assets/Art/Icons/S.png#S"), "Assets/Art/Icons/S.png")
	assert_eq(ContentLibrary.name_of("Assets/Resources/GameCatalog.asset"), "GameCatalog")

## The content assets a JSON value refers to (its strings that are library keys).
func _refs(json, lib: ContentLibrary) -> Array:
	var out := []
	if json is Dictionary:
		for k in json: out.append_array(_refs(json[k], lib))
	elif json is Array:
		for v in json: out.append_array(_refs(v, lib))
	elif json is String and lib.get_asset(json) != null:
		out.append(lib.get_asset(json))
	return out

## References keyed "Type/name", the way the C# test keys assets.
class NameRefs:
	var keys := {}
	func key_of(o):
		if o == null: return null
		if o is String: return o
		return keys.get(o)
	func resolve(key: String, _type_name: String):
		for a in keys:
			if keys[a] == key: return a
		return null
	func may_be_missing(_key: String) -> bool:
		return false
