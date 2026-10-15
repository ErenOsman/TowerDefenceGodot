extends TestCase
## Port of AssetTests.cs — the example abilities exist as assets and behave exactly like the code versions in
## CombatTests. The C# builds them with ExampleAssets.Create(); here they are the "Examples" in the content JSON
## (a fresh ContentLibrary per test, since tests change assets). One difference: the JSON's GameRules lost its
## Collision Damage reaction (a null entry), so setup() puts it back, as ExampleAssets.Rules has it.

var lib: ContentLibrary
var x := {}
var convert: AssetConverter
var state: GameState
var resolver: Resolver

## ExampleAssets field → content key.
const EXAMPLES := {
	"CollisionDamage": "Reaction/Example/Collision Damage", "Thorns": "Reaction/Example/Thorns",
	"Enrage": "Reaction/Example/Enrage", "Overwatch": "Reaction/Example/Overwatch",
	"Rooted": "Status/Example/Rooted", "Enraged": "Status/Example/Enraged", "Poison": "Status/Example/Poison",
	"PoisonTick": "Reaction/Example/Poison Tick", "Fireball": "Ability/Example/Fireball",
	"ShieldBash": "Ability/Example/Shield Bash", "Walk": "Ability/Example/Walk",
	"ChainLightning": "Ability/Example/Chain Lightning", "PinningShot": "Ability/Example/Pinning Shot",
	"Skeleton": "Unit/Other/Example/Skeleton", "FireTile": "Unit/Other/Example/Fire Tile",
	"RaiseSkeleton": "Ability/Example/Raise Skeleton", "FireWall": "Ability/Example/Fire Wall",
	"Ignite": "Reaction/Example/Ignite", "Burn": "Reaction/Example/Burn", "BurnOut": "Reaction/Example/Burn Out",
	"Burning": "Status/Example/Burning", "FireTileRules": "Passive/Example/Fire Tile Rules",
	"CounterStrike": "Reaction/Counter Strike", "CounterAttack": "Passive/Counter-attack",
	"PathWalk": "Ability/Path Walk", "Ram": "Ability/Ram", "Shoot": "Ability/Shoot", "TowerWalk": "Ability/Tower Walk",
	"Slime": "Unit/Enemy/Slime", "Archer": "Unit/Tower/Archer", "Base": "Unit/Base/Base",
	"ArcherTower": "Tower/Archer Tower", "ExampleLevel": "Level/Other/Example Level",
	"Ground": "Terrain/Ground", "Wall": "Terrain/Wall", "Chasm": "Terrain/Chasm",
	"Taunted": "Status/Taunted", "Provoke": "Ability/Example/Provoke", "Volley": "Ability/Example/Volley",
	"BruteWalk": "Ability/Brute Walk", "Smash": "Ability/Smash", "Brute": "Unit/Enemy/Brute",
	"Execute": "Ability/Example/Execute", "ExecuteReset": "Reaction/Example/Execute Reset",
	"Bloodthirst": "Passive/Example/Bloodthirst",
}

func setup() -> void:
	lib = ContentLibrary.load("res://data/content")
	x = {}
	for k in EXAMPLES: x[k] = lib.get_asset(EXAMPLES[k])
	x["Rules"] = lib.rules
	x["Rules"].reactions = [x["CollisionDamage"]]
	convert = AssetConverter.new()
	state = GameState.new(convert.rules(x["Rules"]), BattleGrid.new(10, 10), 12345)
	resolver = Resolver.new(state)

## The example assets (C# x.All).
func all_examples() -> Array:
	var list := x.values()
	return list

func _add(p_name: String, team: int, px: int, py: int, hp: int, stats: Array = []) -> Entity:
	return state.add_unit(p_name, team, Vector2i(px, py), hp, stats)

func _events(type: int) -> Array:
	return resolver.log.of_type(type)

func _any_contains(list: Array, text: String) -> bool:
	return list.any(func(s): return s.contains(text))

func _same(a, b) -> bool:
	if a is Object or b is Object: return is_same(a, b)
	return super._same(a, b)

# ------------------------------------------------------------------ validation

func test_ability_instinct_is_converted_and_validated() -> void:
	var ability := AbilityAsset.new()
	ability.name = "Finisher"
	ability.targeting = PatternDef.diamond("3")
	ability.target_filter = Condition.new("Target.IsEnemy")
	ability.instinct = InstinctDef.of(InstinctPreset.Weakest, "Target.Hp < Target.MaxHp")
	var def := convert.ability(ability)
	assert_eq(def.instinct.preset, InstinctPreset.Weakest)
	assert_eq(def.instinct.must.expression, "Target.Hp < Target.MaxHp")
	assert_eq(AssetValidator.validate_ability(ability, state.vocab).size(), 0, str(AssetValidator.validate_ability(ability, state.vocab)))

	ability.instinct = InstinctDef.new()
	ability.instinct.preset = InstinctPreset.Custom
	assert_true(_any_contains(AssetValidator.validate_ability(ability, state.vocab), "no preferences"))

	ability.instinct = InstinctDef.custom(Preference.highest_of("Target.NoSuchStat"))
	assert_true(_any_contains(AssetValidator.validate_ability(ability, state.vocab), "instinct.prefer[0]"))

	ability.instinct = InstinctDef.custom(Preference.highest_of("Target.PathProgress"), Preference.most_in_area("Target.IsEnemy"))
	var errors := AssetValidator.validate_ability(ability, state.vocab)
	assert_eq(errors.size(), 0, "the new queries and an area count validate: %s" % [errors])

func test_first_clear_gives_the_reward_tower_once() -> void:
	var catalog := GameCatalogAsset.new()
	catalog.tower_types.append(x.ArcherTower)
	var chapter := ChapterData.new()
	chapter.id = "c1"
	var entry := CatalogLevelData.new()
	entry.level = x.ExampleLevel
	entry.first_clear_reward = x.ArcherTower
	chapter.levels.append(entry)
	catalog.chapters.append(chapter)
	assert_eq(AssetValidator.validate_catalog(catalog).size(), 0, str(AssetValidator.validate_catalog(catalog)))

	var progress := LevelProgress.new()
	var towers := TowerCollection.new()
	var result := func(won: bool) -> LevelResult:
		var r := LevelResult.new()
		r.level_id = x.ExampleLevel.get_id()
		r.won = won
		return r

	var loss: LevelResult = result.call(false)
	assert_null(catalog.grant_first_clear_reward(loss, progress.record(loss), towers), "a loss gives nothing")
	var win: LevelResult = result.call(true)
	assert_true(is_same(catalog.grant_first_clear_reward(win, progress.record(win), towers), x.ArcherTower))
	assert_eq(towers.towers.size(), 1)
	assert_seq(towers.hand, [towers.towers[0].id], "into the hand")
	var again: LevelResult = result.call(true)
	assert_null(catalog.grant_first_clear_reward(again, progress.record(again), towers), "only the first win")
	assert_eq(towers.towers.size(), 1)

	catalog.tower_types.clear()
	assert_true(_any_contains(AssetValidator.validate_catalog(catalog), "first-clear reward"))

func test_example_assets_validate_clean() -> void:
	var errors := AssetValidator.validate(all_examples(), x.Rules.create_vocabulary())
	assert_eq(errors.size(), 0, "\n".join(errors))
	errors = AssetValidator.validate(lib.all, x.Rules.create_vocabulary())
	assert_eq(errors.size(), 0, "all the content: " + "\n".join(errors))

func test_ids_names_and_descriptions_reach_the_core_and_map_back_to_their_assets() -> void:
	x.Poison.id = "poison"
	x.Poison.display_name = "Venom"
	var poison := convert.status(x.Poison)
	assert_eq(poison.name, "poison", "rules refer to the id")
	assert_eq(poison.display_name, "Venom")
	assert_eq(poison.description, x.Poison.description)

	var shoot := convert.ability(x.Shoot)
	assert_eq(shoot.get_display_name(), "Shoot")
	assert_true(is_same(convert.asset_of(shoot, "AbilityAsset"), x.Shoot))
	assert_null(convert.asset_of(shoot, "StatusAsset"), "wrong asset type")
	assert_null(convert.asset_of(AbilityDef.new(), "AbilityAsset"), "not built by this converter")

	var archer := convert.tower_type(x.ArcherTower)
	assert_eq(archer.name, "Archer")
	assert_true(is_same(convert.asset_of(archer, "TowerAsset"), x.ArcherTower))

	# the C# checks that the icon-less example Shoot warns about its icon; the content's Shoot has one
	x.Shoot.icon = ""
	assert_true(_any_contains(AssetValidator.warnings(x.Shoot), "icon"))
	assert_false(_any_contains(AssetValidator.warnings(x.Shoot), "display name"))

func test_validator_checks_chain_variable_order() -> void:
	var vocab: Vocabulary = x.Rules.create_vocabulary()
	var drain := AbilityAsset.new()
	drain.name = "Drain"
	var heal := HealStepData.new()
	heal.amount = Formula.new("HpLost * 0.5")
	heal.on = StepTarget.Self
	var attack := AttackStepData.new()
	attack.on_hit = StepList.of(heal, DamageStepData.new())
	drain.steps.items.append(attack)
	assert_true(_any_contains(AssetValidator.validate_ability(drain, vocab), "HpLost is not produced yet"))

	var heal2 := HealStepData.new()
	heal2.amount = Formula.new("HpLost * 0.5")
	heal2.on = StepTarget.Self
	var attack2 := AttackStepData.new()
	attack2.on_hit = StepList.of(DamageStepData.new(), heal2)
	drain.steps.items[0] = attack2
	assert_eq(AssetValidator.validate_ability(drain, vocab).size(), 0, str(AssetValidator.validate_ability(drain, vocab)))

	# Power exists only after an Attack step
	drain.steps.items.insert(0, DamageStepData.new())
	assert_true(_any_contains(AssetValidator.validate_ability(drain, vocab), "ActionPower is not produced yet"))

func test_validator_reports_missing_references_and_counts() -> void:
	var vocab: Vocabulary = x.Rules.create_vocabulary()
	var broken := AbilityAsset.new()
	broken.name = "Broken"
	broken.steps.items.append(ApplyStatusStepData.new())
	var attack := AttackStepData.new()
	attack.hits = Formula.new("0")
	broken.steps.items.append(attack)
	broken.steps.items.append(null)
	var errors := AssetValidator.validate_ability(broken, vocab)
	assert_true(_any_contains(errors, "has no status"), str(errors))
	assert_true(_any_contains(errors, "must be at least 1"), str(errors))
	assert_true(_any_contains(errors, "empty step"), str(errors))

func test_converter_resolves_each_asset_to_one_object() -> void:
	var pinning := convert.ability(x.PinningShot)
	var overwatch := convert.reaction(x.Overwatch)
	assert_eq(overwatch.response.size(), 1)
	var cast: CastAbilityStep = overwatch.response[0]
	assert_true(is_same(cast.ability, pinning))
	assert_eq(pinning.name, "Pinning Shot")

# ------------------------------------------------------------------ the example flows, from assets

func test_fireball_from_assets() -> void:
	var mage := _add("Mage", 0, 0, 0, 100)
	mage.resources["Mana"] = 10
	var a := _add("A", 1, 5, 5, 500)
	_add("B", 2, 6, 5, 500, [["Evasion", 1]])
	_add("C", 2, 5, 6, 500, [["Exposed", 1]])
	var ally := _add("Ally", 1, 9, 9, 500, [["Power", 5]])
	a.grant(convert.reaction(x.Thorns))
	a.grant(Modifier.new("FinalDamage", ModKind.PctAdd, "0.2", ModDirection.Incoming, Tags.Fire))
	ally.grant(convert.reaction(x.Enrage))

	resolver.cast(mage, convert.ability(x.Fireball), Aim.at(mage.pos, a.pos))

	var dmg := _events(GameEventType.DamageDealt)
	assert_true(dmg.size() >= 3, resolver.log.dump(state))
	if dmg.size() < 3: return
	assert_num(dmg[0].facts["FinalDamage"], 120, resolver.log.dump(state))
	assert_num(dmg[1].facts["FinalDamage"], 150)
	assert_num(dmg[2].facts["FinalDamage"], 24)
	assert_eq(mage.hp, 76)
	assert_eq(mage.resources["Mana"], 5)
	assert_num(ally.stat("Power"), 15)

func test_shield_bash_from_assets() -> void:
	state.grid.set_terrain(Vector2i(4, 1), TerrainDef.Wall)
	var knight := _add("Knight", 0, 1, 1, 100)
	var b := _add("B", 1, 2, 1, 100)
	var bash := convert.ability(x.ShieldBash)

	assert_true(Targeting.valid_aims(state, knight.id, bash).any(func(aim): return aim.tile == b.pos))
	resolver.cast(knight, bash, Aim.at(knight.pos, b.pos))

	assert_eq(b.pos, Vector2i(3, 1))
	assert_eq(b.hp, 10, resolver.log.dump(state))

func test_walk_and_overwatch_from_assets() -> void:
	var rogue := _add("Rogue", 0, 2, 1, 100)
	var archer := _add("Archer", 1, 5, 2, 100)
	archer.grant(convert.reaction(x.Overwatch))

	resolver.cast(rogue, convert.ability(x.Walk), Aim.walk(Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)))

	assert_eq(rogue.pos, Vector2i(3, 1), resolver.log.dump(state))
	assert_eq(rogue.hp, 90)
	assert_true(rogue.has_status("Rooted"))
	assert_eq(_events(GameEventType.Fizzled).size(), 2)

func test_chain_lightning_from_assets() -> void:
	var mage := _add("Mage", 0, 0, 0, 100)
	var t1 := _add("T1", 1, 4, 4, 500)
	var t2 := _add("T2", 1, 5, 5, 500)
	var t3 := _add("T3", 1, 6, 6, 500)
	_add("Friend", 0, 4, 5, 500)

	resolver.cast(mage, convert.ability(x.ChainLightning), Aim.at(mage.pos, t1.pos))

	assert_seq(_events(GameEventType.DamageDealt).map(func(d): return d.target), [t1.id, t2.id, t3.id], resolver.log.dump(state))

func test_poison_from_assets() -> void:
	var shaman := _add("Shaman", 1, 0, 0, 100)
	var u := _add("U", 0, 3, 3, 100)
	var inst := StatusInstance.new()
	inst.def = convert.status(x.Poison)
	inst.stacks = 3
	inst.turns_left = 3
	inst.applied_by = shaman.id
	u.statuses.append(inst)

	resolver.start_turn(u)

	assert_eq(u.hp, 85, resolver.log.dump(state))
	var dealt := _events(GameEventType.DamageDealt)
	assert_eq(dealt.size(), 1)
	if dealt.size() == 1: assert_eq(dealt[0].source, shaman.id)

# ------------------------------------------------------------------ entities from assets

func test_summon_and_hazard_from_assets() -> void:
	var necro := _add("Necro", 0, 0, 0, 100)
	var foe := _add("Foe", 1, 3, 0, 100)

	resolver.cast(necro, convert.ability(x.RaiseSkeleton), Aim.at(necro.pos, Vector2i(1, 0)))
	var skeletons := state.entities.filter(func(e): return e.name == "Skeleton")
	assert_eq(skeletons.size(), 1, resolver.log.dump(state))
	if skeletons.size() != 1: return
	var skeleton: Entity = skeletons[0]
	assert_eq(skeleton.summoner, necro.id, resolver.log.dump(state))
	assert_eq(skeleton.hp, 20)
	assert_true(skeleton.has_tag("Undead"))

	resolver.cast(necro, convert.ability(x.FireWall), Aim.at(necro.pos, foe.pos))
	var fires := state.entities.filter(func(e): return e.name == "Fire Tile")
	assert_eq(fires.size(), 1, resolver.log.dump(state))
	if fires.size() != 1: return
	assert_true(fires[0].has_status("Burning"), resolver.log.dump(state))

	resolver.start_turn(foe)
	assert_eq(foe.hp, 90, resolver.log.dump(state))

func test_validator_checks_entity_stats() -> void:
	var vocab: Vocabulary = x.Rules.create_vocabulary()
	var broken := EntityAsset.new()
	broken.name = "Broken"
	broken.stats = [StatValue.of("Strength", "abc")]
	var errors := AssetValidator.validate([broken], vocab)
	assert_true(_any_contains(errors, "not a registered stat"), str(errors))
	assert_true(_any_contains(errors, "is not a number"), str(errors))
	assert_true(_any_contains(errors, "needs MaxHp"), str(errors))

# ------------------------------------------------------------------ the example level

func test_the_map_is_terrain_build_and_road_layers() -> void:
	var bridge := TerrainAsset.new()
	bridge.name = "Bridge"
	bridge.id = "bridge"
	var level := LevelAsset.new()
	# path 1 starts in the middle, loops back through its start and leaves a gap; path 2 enters from the left edge
	level.paths.append(PathData.of(Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(3, 0)))
	level.paths.append(PathData.of(Vector2i(0, 2), Vector2i(1, 2)))
	level.set_tiles(["...+", "#...", "~..."], x.Ground, x.Wall, x.Chasm)
	level.terrain_keys.append(TerrainKey.of("=", bridge))
	level.terrain = level.with_char(level.terrain, 2, 2, "=", ".")

	assert_seq(level.terrain, ["..=.", "#...", "~..."], "the build tile is ground in the terrain layer")
	assert_seq(level.build, ["...+", "....", "...."])
	assert_seq(level.road, ["─┬┐.", ".├┘.", ".╵.•"], "the edge entry, corners, where paths meet, an end before a gap and a one-tile part")
	assert_true(is_same(level.terrain_at(0, 1), x.Wall))
	assert_eq(level.road_at(1, 1), "RUD", "the start, and the loop passing through it again")
	assert_true(level.build_at(3, 2))

	var def := convert.level(level)
	var grid := def.build_grid()
	assert_eq(grid.terrain_at(Vector2i(0, 1)).name, "wall")
	assert_eq(grid.terrain_at(Vector2i(2, 2)).name, "bridge")
	assert_true(is_same(convert.asset_of(grid.terrain_at(Vector2i(2, 2)), "TerrainAsset"), bridge))
	assert_true(grid.can_build(Vector2i(3, 2)) and not grid.can_build(Vector2i(2, 0)))
	assert_false(grid.path(0).is_step(6), "a gap cannot be walked")
	var errors := AssetValidator.validate_level(level).filter(func(e): return not e.contains("bases") and not e.contains("waves"))
	assert_eq(errors.size(), 0, str(errors))

	level.road = level.with_char(level.road, 2, 1, ".", ".")
	assert_true(_any_contains(AssetValidator.validate_level(level), "not joined by the road layer"), "a path runs along the road")
	level.paths[1].tiles.append(Vector2i(0, 2))
	assert_true(_any_contains(AssetValidator.validate_level(level), "turns straight back"))
	level.terrain = level.with_char(level.terrain, 3, 2, "?", ".")
	assert_true(_any_contains(AssetValidator.validate_level(level), "not in Terrain Keys"))

func test_example_level_is_won_by_one_archer() -> void:
	var session := LevelSession.new(convert.level(x.ExampleLevel), convert.rules(x.Rules), [convert.tower(x.ArcherTower, "archer-1")], 3)
	session.start()
	var archer := session.place("archer-1", Vector2i(1, 3)) # (3, 3) is the wall
	assert_not_null(archer, session.last_error)
	if archer == null: return
	var shoot: AbilityDef = archer.abilities[0].def if archer.abilities[0] is AbilityInstance else archer.abilities[0]

	var guard := 0
	while guard < 40 and not session.is_over:
		var aim := EnemyBrain.choose_aim(session.state, archer, shoot)
		if aim != null and session.can_cast(archer, shoot): session.cast(archer, shoot, aim)
		if not session.is_over: session.end_round() # the last kill wins at once
		guard += 1

	assert_eq(session.outcome, Outcome.Won, session.log.dump(session.state))

# ------------------------------------------------------------------ the game catalog (Level Select — Design)

func test_game_catalog_unlocks_levels_and_builds_the_saved_hand() -> void:
	var second := LevelAsset.new()
	second.name = "Second"
	second.id = "second"
	var catalog := GameCatalogAsset.new()
	catalog.name = "Catalog"
	var chapter := ChapterData.new()
	chapter.id = "c1"
	chapter.display_name = "Chapter 1"
	var e1 := CatalogLevelData.new()
	e1.level = x.ExampleLevel
	var e2 := CatalogLevelData.new()
	e2.level = second
	chapter.levels.append(e1)
	chapter.levels.append(e2)
	catalog.chapters.append(chapter)
	catalog.tower_types.append(x.ArcherTower)
	catalog.starting_towers.append(x.ArcherTower)
	catalog.starting_towers.append(x.ArcherTower)

	assert_eq(AssetValidator.validate_catalog(catalog).size(), 0, ", ".join(AssetValidator.validate_catalog(catalog)))

	var progress := LevelProgress.new()
	var levels := catalog.to_catalog()
	assert_false(levels.is_unlocked(levels.find("second"), progress))
	var won := LevelResult.new()
	won.level_id = x.ExampleLevel.get_id()
	won.won = true
	progress.record(won)
	assert_true(levels.is_unlocked(levels.find("second"), progress))

	var towers := TowerCollection.new()
	assert_true(catalog.grant_starting_towers(towers))
	assert_false(catalog.grant_starting_towers(towers), "only a collection with no towers gets them")
	var hand := catalog.build_hand(towers, convert)
	assert_eq(hand.size(), 2)
	if hand.size() == 2: assert_ne(hand[0].id, hand[1].id, "two archers, two towers")
	assert_true(is_same(catalog.find_level(x.ExampleLevel.get_id()), x.ExampleLevel))
