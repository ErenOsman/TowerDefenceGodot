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
	# coin.png (Assets/Art/UI) has no copy yet; everything else must resolve
	var real := missing.filter(func(m): return not m.ends_with("res://art/ui/coin.png"))
	assert_eq(real, [], "missing art")

func test_volume_db_mapping() -> void:
	var sm = load("res://game/app/settings_mgr.gd")
	assert_num(sm.volume_to_db(1.0), 0.0)
	assert_num(sm.volume_to_db(0.0), -80.0)
	assert_num(sm.volume_to_db(0.005), -80.0)
	assert_true(absf(sm.volume_to_db(0.1) - (-20.0)) < 1e-4)
	assert_true(absf(sm.volume_to_db(0.5) - (-6.0206)) < 1e-3)
