extends TestCase
## The shell's save (game/app): GameData JSON round trip with the Unity field names, adoption of saves
## from before profiles, and the new-game / dev-shortcut rules on the real catalog.

static var _lib: ContentLibrary

func _catalog() -> GameCatalogAsset:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib.catalog

func _sample() -> GameData:
	var g := GameData.new()
	g.settings.master_volume = 0.55
	g.settings.is_fullscreen = false
	g.settings.game_speed = 2.0
	g.settings.follow_action = true
	g.settings.resolution_width = 1600
	g.settings.key_binds.append({"action": "EndRound", "primary": KeyCombo.new(KEY_ENTER), "secondary": KeyCombo.new(KEY_SPACE, Modifiers.Ctrl)})
	g.settings.modifier_binds.append({"action": "QuickCast", "modifiers": Modifiers.Alt})
	var a := g.towers.add("archer", "Robin")
	var b := g.towers.add("guardian")
	g.towers.add_to_hand(b.id)
	g.towers.add_to_hand(a.id)
	g.profile.create("  Eren  ")
	g.profile.tutorial = TutorialState.Skipped
	g.profile.camp_seen = true
	g.profile.mark_intro_seen("level_01")
	var r := LevelResult.new()
	r.level_id = "level_01"; r.won = true; r.base_hp_pct = 80; r.rounds = 7; r.towers_lost = 1; r.when = "2026-10-13T10:00:00Z"
	g.progress.record(r)
	g.progress.last_selected = "level_02"
	g.codex.discover(CodexSection.Enemies, "slime")
	g.codex.mark_viewed(CodexSection.Enemies, "slime")
	g.codex.discover(CodexSection.Towers, "archer")
	return g

func test_round_trip_keeps_everything() -> void:
	var g := _sample()
	var back := GameData.from_json(g.to_json())
	assert_not_null(back)
	assert_num(back.settings.master_volume, 0.55)
	assert_false(back.settings.is_fullscreen)
	assert_num(back.settings.game_speed, 2.0)
	assert_true(back.settings.follow_action)
	assert_eq(back.settings.resolution_width, 1600)
	assert_eq(back.settings.key_binds.size(), 1)
	assert_true(back.settings.key_binds[0].secondary.equals(KeyCombo.new(KEY_SPACE, Modifiers.Ctrl)))
	assert_eq(back.settings.modifier_binds[0].modifiers, Modifiers.Alt)
	assert_eq(back.towers.towers.size(), 2)
	assert_eq(back.towers.towers[0].custom_name, "Robin")
	assert_eq(back.towers.towers[0].type, "archer")
	assert_eq(back.towers.towers[0].id, g.towers.towers[0].id)
	assert_seq(back.towers.hand, g.towers.hand)
	assert_true(back.profile.created)
	assert_eq(back.profile.player_name, "Eren")
	assert_eq(back.profile.tutorial, TutorialState.Skipped)
	assert_true(back.profile.camp_seen)
	assert_seq(back.profile.seen_intros, ["level_01"])
	var rec := back.progress.find("level_01")
	assert_not_null(rec)
	assert_eq(rec.attempts, 1)
	assert_eq(rec.wins, 1)
	assert_true(rec.won)
	assert_eq(rec.best_base_hp_pct, 80)
	assert_eq(rec.fewest_rounds, 7)
	assert_eq(rec.fewest_towers_lost, 1)
	assert_eq(rec.last_played, "2026-10-13T10:00:00Z")
	assert_eq(back.progress.last_selected, "level_02")
	assert_seq(back.codex.discovered, ["Enemies:slime", "Towers:archer"])
	assert_seq(back.codex.viewed, ["Enemies:slime"])
	assert_true(back.had_profile)
	assert_eq(back.to_json(), g.to_json(), "a second round trip is identical")

func test_json_uses_unity_field_names() -> void:
	var d: Dictionary = JSON.parse_string(_sample().to_json())
	assert_seq(d.keys(), ["settings", "towers", "progress", "profile", "codex", "handLayouts", "tokens", "missions"])
	for k in ["masterVolume", "musicVolume", "sfxVolume", "otherVolume", "resolutionWidth", "resolutionHeight",
			"isFullscreen", "gameSpeed", "followAction", "followSelection", "dragToPan", "instantPlayback",
			"alwaysShowHealth", "keyBinds", "modifierBinds"]:
		assert_true(d.settings.has(k), k)
	assert_eq(d.settings.keyBinds[0].action, "EndRound")
	assert_eq(d.settings.keyBinds[0].primary.key, "Enter")
	assert_eq(d.settings.keyBinds[0].primary.modifiers, 0.0)
	assert_true(d.towers.towers[0].has("customName"))
	assert_true(d.progress.levels[0].has("bestBaseHpPct"))
	assert_true(d.progress.levels[0].has("fewestTowersLost"))
	assert_eq(d.profile.playerName, "Eren")
	assert_eq(d.profile.tutorial, float(TutorialState.Skipped))

func test_defaults_and_missing_fields() -> void:
	var g := GameData.from_json('{"settings": {"musicVolume": 0.5}}')
	assert_num(g.settings.music_volume, 0.5)
	assert_num(g.settings.master_volume, 0.3, "Unity default")
	assert_true(g.settings.is_fullscreen)
	assert_true(g.settings.follow_selection)
	assert_eq(g.towers.towers.size(), 0)
	assert_false(g.had_profile)
	assert_false(g.profile.created)
	assert_null(GameData.from_json("not json"))
	assert_null(GameData.from_json("[1,2]"))

func test_old_save_is_adopted_past_the_tutorial() -> void:
	var g := GameData.from_json('{"settings": {}, "towers": {"towers": [], "hand": []}}')
	assert_false(g.had_profile)
	assert_true(g.profile.adopt_existing_save())
	assert_false(g.profile.is_first_run)
	assert_eq(g.profile.tutorial, TutorialState.Skipped)
	var fresh := GameData.from_json(GameData.new().to_json())
	assert_true(fresh.had_profile, "a save at the Welcome screen keeps its first run")
	assert_true(fresh.profile.is_first_run)

func test_key_combo_accepts_unity_numbers_and_names() -> void:
	var c := KeyCombo.from_dict({"key": "Space", "modifiers": "Shift"})
	assert_eq(c.key, KEY_SPACE)
	assert_eq(c.modifiers, Modifiers.Shift)
	assert_true(KeyCombo.from_dict({"key": "", "modifiers": 3}).is_none)
	assert_true(KeyCombo.from_dict(null).is_none)
	assert_eq(KeyCombo.from_dict(KeyCombo.new(KEY_KP_5, Modifiers.CtrlShift).to_dict()).key, KEY_KP_5)

func test_new_game_gives_starting_towers_and_tutorial_reward_once() -> void:
	var catalog := _catalog()
	var g := GameData.new()
	NewGame.create_profile(g, catalog, "")
	assert_eq(g.profile.player_name, PlayerProfile.DefaultName)
	assert_true(g.profile.tutorial_pending)
	assert_eq(g.towers.towers.size(), catalog.starting_towers.size())
	assert_eq(g.towers.hand.size(), catalog.starting_towers.size())
	var reward := NewGame.finish(g, catalog, TutorialState.Skipped)
	assert_eq(reward, catalog.tutorial_reward)
	assert_eq(g.profile.tutorial, TutorialState.Skipped)
	var count := g.towers.towers.size()
	assert_null(NewGame.finish(g, catalog, TutorialState.Done), "only once")
	assert_eq(g.towers.towers.size(), count)
	assert_true(NewGame.is_tutorial(catalog.tutorial, catalog))

func test_dev_shortcut_completes_chapter_1_and_opens_the_camp() -> void:
	var catalog := _catalog()
	var g := GameData.new()
	var won := DevShortcuts.complete_chapter1(g, catalog)
	assert_true(won > 0)
	assert_true(g.profile.created)
	assert_eq(g.profile.tutorial, TutorialState.Done)
	if catalog.camp_unlock != null: assert_true(catalog.camp_unlocked(g.progress))
	assert_eq(DevShortcuts.complete_chapter1(g, catalog), 0, "nothing left to win")
	var back := GameData.from_json(g.to_json())
	assert_eq(back.progress.levels.size(), g.progress.levels.size())
	assert_eq(back.towers.towers.size(), g.towers.towers.size())

func test_win_first_levels_counts_in_order() -> void:
	var catalog := _catalog()
	var g := GameData.new()
	assert_eq(DevShortcuts.win_first_levels(g, catalog, 2), 2)
	assert_eq(DevShortcuts.win_first_levels(g, catalog, 3), 1)
