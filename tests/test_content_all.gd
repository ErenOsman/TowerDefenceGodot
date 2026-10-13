extends TestCase
## The real content (res://data/content/*.json): it loads without problems, every level, tower, entity, ability,
## status and the rules convert, Validate All finds no errors, the JSON round-trips, and spot checks of numbers.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib

func test_loads_without_problems() -> void:
	assert_eq(lib().problems.size(), 0, "\n".join(lib().problems))
	assert_set(lib().skipped.map(func(s): return s.get_slice(":", 0)), ["PresentationTimings.json", "UITheme.json"])
	assert_eq(lib().all_of("AbilityAsset").size(), 35)
	assert_eq(lib().all_of("EntityAsset").size(), 28)
	assert_eq(lib().all_of("LevelAsset").size(), 11)
	assert_eq(lib().all_of("TowerAsset").size(), 9)
	assert_eq(lib().all_of("TileAsset").size(), 29)
	assert_not_null(lib().catalog)
	assert_not_null(lib().rules)
	assert_eq(lib().catalog.name, "GameCatalog")
	assert_eq(lib().file_of(lib().get_asset("Units/Enemies/Rabbit")), "Units.json")
	assert_eq(lib().key_of(lib().find("EntityAsset", "Rabbit")), "Units/Enemies/Rabbit")

func test_everything_converts() -> void:
	var c := AssetConverter.new()
	var rules := c.rules(lib().rules)
	assert_not_null(rules)
	assert_not_null(rules.vocabulary)
	for a in lib().all_of("LevelAsset"): assert_not_null(c.level(a), a.name)
	for a in lib().all_of("TowerAsset"): assert_not_null(c.tower_type(a), a.name)
	for a in lib().all_of("EntityAsset"): assert_not_null(c.entity(a), a.name)
	for a in lib().all_of("AbilityAsset"):
		var d := c.ability(a)
		assert_not_null(d, a.name)
		assert_eq(d.steps.size(), a.steps.items.size(), a.name)
		for s in d.steps: assert_true(s is Step, "%s: %s" % [a.name, s])
	for a in lib().all_of("StatusAsset"): assert_not_null(c.status(a), a.name)
	for a in lib().all_of("PassiveAsset"): assert_not_null(c.passive(a), a.name)
	for a in lib().all_of("ReactionAsset"): assert_not_null(c.reaction(a), a.name)
	assert_true(c.built("AbilityDef").size() >= 35)

func test_validate_all_has_no_errors() -> void:
	var findings := ContentCheck.run(lib().all, ContentCheck.vocabulary_of(lib().rules))
	var errors := findings.filter(func(f): return f.error).map(func(f): return f.message)
	assert_eq(errors.size(), 0, "\n".join(errors))

func test_archer_numbers() -> void:
	var c := AssetConverter.new()
	var tower := c.tower_type(lib().get_asset("Towers/Archer Tower"))
	assert_eq(tower.id, "archer")
	assert_eq(tower.name, "Archer")
	var archer := tower.entity
	assert_num(archer.base_stats["MaxHp"], 20)
	assert_num(archer.base_stats["Range"], 2)
	assert_eq(archer.footing, Footing.OffPath)
	var shoot: AbilityDef = null
	for ab in archer.abilities:
		if ab.name == "Shoot": shoot = ab
	assert_not_null(shoot, "the Archer shoots")
	assert_eq(shoot.cooldown, 1)
	assert_eq(shoot.targeting.shape, Shape.Diamond)
	assert_eq(shoot.targeting.max_radius.expression, "Self.Range")
	assert_eq(shoot.target_filter.expression, "Target.IsEnemy")
	assert_seq(shoot.tags, ["Attack", "Projectile"])
	var attack: AttackStep = shoot.steps[0]
	assert_eq(attack.power.expression, "Self.Power")
	assert_false(attack.can_miss)
	assert_true(attack.on_hit[0] is DamageStep)
	assert_eq(attack.bounce_area.max_radius.expression, "2")
	assert_same_obj(c.asset_of(shoot), lib().get_asset("Abilities/Shoot"))

func assert_same_obj(a, b, msg := "") -> void:
	if not is_same(a, b): fail("expected the same object: %s vs %s. %s" % [a, b, msg])

func test_first_steps_level() -> void:
	var asset: LevelAsset = lib().get_asset("Levels/Chapter 1/1 First Steps")
	assert_eq(asset.get_id(), "chapter1-1")
	assert_eq(asset.get_display_name(), "First Steps")
	var d := AssetConverter.new().level(asset)
	assert_eq(d.width, 10)
	assert_eq(d.height, 5)
	assert_eq(d.waves.size(), 3)
	assert_eq(d.hand_cap, 4)
	assert_eq(d.start_energy, 200)
	assert_eq(d.energy_per_round, 20)
	assert_eq(d.paths.size(), 1)
	assert_eq(d.paths[0].size(), 9)
	assert_eq(d.paths[0][0], Vector2i(0, 2))
	assert_eq(d.bases[0].tile, Vector2i(9, 2))
	assert_eq(d.bases[0].entity.name, "Base")
	assert_eq(d.terrain[Vector2i(3, 3)].name, "wall")
	assert_eq(d.terrain[Vector2i(0, 0)].name, "ground")
	assert_true(d.buildable.has(Vector2i(7, 4)))
	assert_false(d.buildable.has(Vector2i(0, 4)))
	assert_eq(d.waves[1].name, "A big one")
	assert_eq(d.waves[1].start_round, 4)
	assert_eq(d.waves[1].spawns[1].enemy.name, "big-slime")
	assert_eq(d.waves[2].spawns.size(), 3)
	assert_eq(asset.road_at(8, 2), "L")
	var grid := d.build_grid()
	assert_true(grid.can_build(Vector2i(7, 4)))

func test_rules_and_catalog() -> void:
	var rules := AssetConverter.new().rules(lib().rules)
	assert_eq(rules.hit_chance.expression, "1 - Target.Evasion")
	assert_eq(rules.max_depth, 16)
	assert_true(rules.vocabulary.is_stat("Evasion"))
	assert_eq(rules.reactions.size(), 0, "the JSON's null reaction entry is skipped")
	var cat := lib().catalog
	assert_eq(cat.chapters.size(), 2)
	assert_eq(cat.chapters[0].levels[0].level.get_id(), "chapter1-1")
	assert_eq(cat.chapters[0].levels[0].first_clear_reward.name, "Guardian Tower")
	assert_eq(cat.tutorial.name, "Tutorial")
	assert_not_null(cat.codex)
	assert_true(cat.codex.towers.size() > 0)
	assert_eq(cat.find_level("chapter1-1"), lib().get_asset("Levels/Chapter 1/1 First Steps"))
	assert_eq(AssetValidator.validate_catalog(cat).size(), 0, "\n".join(AssetValidator.validate_catalog(cat)))
	var progress := LevelProgress.new()
	assert_eq(cat.next_main_level(progress).get_id(), "chapter1-1")
	var levels := cat.to_catalog()
	assert_eq(levels.entries.size(), 8)

func test_codex_enemies_of_a_level() -> void:
	var names := CodexAsset.enemies_of(lib().get_asset("Levels/Chapter 1/1 First Steps")).map(func(e): return e.name)
	assert_seq(names, ["Slime", "Big Slime"])

func test_sequences_and_presentations() -> void:
	var seq: SequenceAsset = lib().get_asset("Sequences/Tutorial Steps")
	assert_true(seq.lines.size() > 0)
	assert_true(seq.lines[0] is SequenceLine)
	var shoot: AbilityAsset = lib().get_asset("Abilities/Shoot")
	assert_eq(shoot.presentation, lib().get_asset("Presentation/Shoot Presentation"))
	assert_eq(shoot.icon, "Assets/Art/Icons/Abilities/Shoot.png#Shoot")

## The JSON written back from the loaded objects equals the file (every field is read, nothing is lost).
func test_json_round_trips() -> void:
	for f in DirAccess.get_files_at("res://data/content"):
		if not f.ends_with(".json"): continue
		var root = JSON.parse_string(FileAccess.get_file_as_string("res://data/content/" + f))
		if not ContentSerializer.ASSET_TYPES.has(root["type"]): continue
		for key in root["assets"]:
			var asset = lib().get_asset(key)
			var written := ContentSerializer.to_json(asset, lib())
			var diff := _diff(root["assets"][key], written, key)
			assert_eq(diff, "", "%s: %s" % [f, diff])

func _diff(a, b, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k): return "%s.%s missing" % [path, k]
			var d := _diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "": return d
		for k in b:
			# a field the file leaves out (written before the field existed) must hold its default
			if not a.has(k) and not (b[k] == null or b[k] is Array and b[k].is_empty() or b[k] is String and b[k] == "" or (b[k] is float or b[k] is int) and b[k] == 0):
				return "%s.%s extra" % [path, k]
		return ""
	if a is Array and b is Array:
		if a.size() != b.size(): return "%s: %d items vs %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := _diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "": return d
		return ""
	if (a is float or a is int) and (b is float or b is int):
		return "" if absf(float(a) - float(b)) < 1e-6 else "%s: %s vs %s" % [path, a, b]
	return "" if a == b else "%s: %s vs %s" % [path, a, b]
