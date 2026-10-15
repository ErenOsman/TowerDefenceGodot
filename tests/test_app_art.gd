extends TestCase
## Art path mapping (ArtPaths, used by GameApp's icon/model/kit/portrait lookups) and the SettingsMgr dB rule.

func test_icon_paths() -> void:
	assert_eq(ArtPaths.icon("Assets/Art/Icons/Abilities/Shoot.png#Shoot"), "res://art/icons/Abilities/Shoot.png")
	assert_eq(ArtPaths.icon("Assets/Art/Icons/Units/Miniatures/Base.png#Base"), "res://art/icons/Units/Miniatures/Base.png")
	assert_eq(ArtPaths.icon(""), "")
	assert_eq(ArtPaths.icon("Assets/Art/UI/coin.png#coin"), "")
	assert_eq(ArtPaths.sprite("Assets/Art/UI/coin.png#coin"), "res://art/ui/coin.png")

func test_kit_paths() -> void:
	assert_eq(ArtPaths.kit("Assets/Art/UI/KitB/abilities_face/Bash.png#Bash"), "res://art/ui/KitB/abilities_face/Bash.png")

func test_model_paths() -> void:
	assert_eq(ArtPaths.model("Assets/Art/Models/Archer/Archer Blender.prefab"), "res://art/models/Archer.fbx")
	assert_eq(ArtPaths.model("Assets/Art/Models/Slime King/Slime King Blender.prefab"), "res://art/models/Slime King.fbx")
	assert_eq(ArtPaths.model("Assets/Art/Models/Map Kit/Ground A.fbx"), "res://art/tiles/Ground A.fbx")
	assert_eq(ArtPaths.model(""), "")

func test_other_paths() -> void:
	assert_eq(ArtPaths.portrait("Archer"), "res://art/portraits/Archer.png")
	assert_eq(ArtPaths.font("Assets/Art/Fonts/Nunito-Bold SDF.asset"), "res://art/fonts/Nunito-Bold.ttf")
	assert_eq(ArtPaths.music("battle"), "res://art/music/battle.mp3")
	assert_eq(ArtPaths.music("Assets/Audio/Music/map2.mp3"), "res://art/music/map2.mp3")
	assert_eq(ArtPaths.music(""), "")

func test_canonical_paths_pass_through() -> void:
	assert_eq(ArtPaths.icon("art/icons/Abilities/Shoot.png"), "res://art/icons/Abilities/Shoot.png")
	assert_eq(ArtPaths.icon("art/ui/coin.png"), "")
	assert_eq(ArtPaths.sprite("art/ui/coin.png"), "res://art/ui/coin.png")
	assert_eq(ArtPaths.kit("art/ui/KitB/forms/archer-fire.png"), "res://art/ui/KitB/forms/archer-fire.png")
	assert_eq(ArtPaths.model("art/models/Archer.fbx"), "res://art/models/Archer.fbx")
	assert_eq(ArtPaths.model("art/tiles/Ground A.fbx"), "res://art/tiles/Ground A.fbx")
	assert_eq(ArtPaths.model("art/icons/Units/Archer.png"), "")
	assert_eq(ArtPaths.font("art/fonts/Nunito-Bold.ttf"), "res://art/fonts/Nunito-Bold.ttf")
	assert_eq(ArtPaths.music("art/music/map2.mp3"), "res://art/music/map2.mp3")
	assert_eq(ArtPaths.resolve("art/models/Arrow.fbx"), "res://art/models/Arrow.fbx")
	assert_eq(ArtPaths.resolve("vfx/Hit Spark"), "")
	assert_eq(VfxKit.effect_name("vfx/Hit Spark"), "Hit Spark")

## Both forms name the same thing: every art field the oracle's content copy (Unity paths, ~/godot/oracle/content)
## shares with data/content (canonical paths since 2026-10-15) resolves to the same res:// file / VFX effect.
func test_old_and_canonical_forms_resolve_alike() -> void:
	var oracle := ProjectSettings.globalize_path("res://").path_join("../../oracle/content").simplify_path()
	if not DirAccess.dir_exists_absolute(oracle): return # no oracle checkout: nothing to compare
	var pairs := 0
	var bad := []
	for f in DirAccess.get_files_at(oracle):
		if not f.ends_with(".json") or not FileAccess.file_exists("res://data/content/" + f): continue
		var old = JSON.parse_string(FileAccess.get_file_as_string(oracle.path_join(f)))
		var cur = JSON.parse_string(FileAccess.get_file_as_string("res://data/content/" + f))
		if not (old is Dictionary and cur is Dictionary): continue
		var olda: Dictionary = old.get("assets", {})
		var cura: Dictionary = cur.get("assets", {})
		for key in olda:
			if cura.has(key): pairs += _compare(olda[key], cura[key], "%s %s" % [f, key], bad)
	assert_true(pairs > 200, "compared %d art paths" % pairs)
	assert_eq(bad, [], "old and canonical forms differ")

func _compare(o, c, where: String, bad: Array) -> int:
	var n := 0
	if o is Dictionary and c is Dictionary:
		for k in o:
			if c.has(k): n += _compare(o[k], c[k], where + "." + str(k), bad)
	elif o is Array and c is Array and o.size() == c.size():
		for i in o.size(): n += _compare(o[i], c[i], where, bad)
	elif o is String and c is String and o.begins_with("Assets/Art/") and not c.begins_with("Assets/"):
		n = 1
		var a := VfxKit.effect_name(o) if c.begins_with("vfx/") else ArtPaths.resolve(o)
		var b := VfxKit.effect_name(c) if c.begins_with("vfx/") else ArtPaths.resolve(c)
		if a == "" or a != b: bad.append("%s: %s → %s, %s → %s" % [where, o, a, c, b])
	return n

## Icons the Workshop forms' abilities and passive name that are not drawn yet (2026-10-15).
const KNOWN_MISSING_ICONS := ["res://art/icons/Abilities/FireShot.png", "res://art/icons/Abilities/FireVolley.png",
	"res://art/icons/Abilities/VenomShot.png", "res://art/icons/Abilities/LongShot.png",
	"res://art/icons/Abilities/PyroBlast.png", "res://art/icons/Abilities/FrostBolt.png",
	"res://art/icons/Abilities/ChainSpark.png", "res://art/icons/Passives/SpikedCounter.png"]

func test_every_content_art_reference_exists() -> void:
	var lib := ContentLibrary.load("res://data/content")
	var missing := []
	var n := 0
	for a in lib.all:
		for prop in ["icon", "view", "miniature"]:
			if not (prop in a): continue
			var v = a.get(prop)
			if not (v is String) or v == "": continue
			var p := ArtPaths.model(v) if prop == "view" else ArtPaths.sprite(v)
			if p == "": continue
			n += 1
			if not ResourceLoader.exists(p): missing.append("%s.%s → %s" % [a.name, prop, p])
	assert_true(n > 50, "checked %d references" % n)
	# coin.png (Assets/Art/UI) has no copy yet, nor do the Workshop forms' ability / passive icons (the game shows the
	# fallback face; KNOWN_MISSING_ICONS); everything else must resolve
	var real := missing.filter(func(m): return not m.ends_with("res://art/ui/coin.png") and not KNOWN_MISSING_ICONS.has(m.get_slice(" → ", 1)))
	assert_eq(real, [], "missing art")

func test_volume_db_mapping() -> void:
	var sm = load("res://game/app/settings_mgr.gd")
	assert_num(sm.volume_to_db(1.0), 0.0)
	assert_num(sm.volume_to_db(0.0), -80.0)
	assert_num(sm.volume_to_db(0.005), -80.0)
	assert_true(absf(sm.volume_to_db(0.1) - (-20.0)) < 1e-4)
	assert_true(absf(sm.volume_to_db(0.5) - (-6.0206)) < 1e-3)
