extends TestCase
## The menus' pure rules (game/ui/screens/parts/menu_logic.gd): minimap colours from a level's layers, which levels
## level select lists (all chapters / one chapter in the Camp), where the cursor starts, requirement words, facts and
## enemies text, the Controls page rows, game speed stages, chapter cards and Codex texts.

func _terrain(stand: int) -> TerrainAsset:
	var t := TerrainAsset.new()
	t.stand = stand
	return t

## A 5×3 map: a wall at the top-left, a chasm at the top-right, build tiles in the middle row, a road along the
## bottom row (path from (0,0) to (4,0)) and a base at (4,0).
func _level() -> LevelAsset:
	var l := LevelAsset.new()
	var terrain: Array[String] = ["#...~", ".....", "....."]
	var build: Array[String] = [".....", ".+++.", "....."]
	var road: Array[String] = [".....", ".....", "─────"]
	l.terrain = terrain
	l.build = build
	l.road = road
	l.terrain_keys = [TerrainKey.of(".", _terrain(Standing.Everyone)), TerrainKey.of("#", _terrain(Standing.Nobody)),
		TerrainKey.of("~", _terrain(Standing.Flyers))]
	var p := PathData.new()
	var tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	p.tiles = tiles
	l.paths = [p]
	var b := BaseData.new()
	b.tile = Vector2i(4, 0)
	l.bases = [b]
	return l

func test_minimap_colours_follow_the_layers() -> void:
	var c := MenuLogic.minimap_colors(_level())
	assert_eq(c.size(), 3, "one row per terrain row")
	assert_eq(c[0].size(), 5)
	assert_eq(c[0][0], MenuLogic.MAP_WALL, "top-left wall (row 0 = the first layer line = the top)")
	assert_eq(c[0][4], MenuLogic.MAP_CHASM)
	assert_eq(c[0][2], MenuLogic.MAP_GROUND)
	assert_eq(c[1][0], MenuLogic.MAP_GROUND)
	assert_eq(c[1][2], MenuLogic.MAP_BUILD, "build tiles grey")
	assert_eq(c[2][0], MenuLogic.MAP_ENTRY, "the path's first tile, where enemies enter, red")
	assert_eq(c[2][2], MenuLogic.MAP_ROAD)
	assert_eq(c[2][4], MenuLogic.MAP_BASE, "the base blue, over the road")

func test_minimap_image_is_blocks_per_tile() -> void:
	var img := MenuLogic.minimap_image(_level(), 8)
	assert_eq(img.get_width(), 40)
	assert_eq(img.get_height(), 24)
	assert_true(_near(img.get_pixel(4, 4), MenuLogic.MAP_WALL), "inside the top-left block")
	assert_true(_near(img.get_pixel(4, 20), MenuLogic.MAP_ENTRY), "bottom-left block (y flipped: the image's top is the map's top)")
	assert_true(_near(img.get_pixel(0, 0), MenuLogic.MAP_WALL.darkened(0.15)), "a darker line between tiles")
	assert_null(MenuLogic.minimap_image(null))

static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

func _catalog() -> LevelCatalog:
	var es := []
	for x in [["a1", 0], ["a2", 0], ["a3", 0], ["b1", 1], ["b2", 1]]:
		var e := CatalogEntry.new()
		e.level_id = x[0]
		e.chapter = x[1]
		es.append(e)
	return LevelCatalog.new(es, [ChapterInfo.new(), ChapterInfo.new()])

func _won(p: LevelProgress, id: String) -> void:
	var r := LevelResult.new()
	r.level_id = id
	r.won = true
	p.record(r)

func _ids(rows: Array) -> Array:
	var out := []
	for r in rows: out.append("%s%s" % [r.entry.level_id, "" if r.unlocked else "*"])
	return out

func test_level_list_shows_unlocked_and_first_locked() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	assert_eq(_ids(MenuLogic.visible_levels(cat, p)), ["a1", "a2*"], "a fresh save: the first level and the next locked one")
	_won(p, "a1")
	_won(p, "a2")
	assert_eq(_ids(MenuLogic.visible_levels(cat, p)), ["a1", "a2", "a3", "b1*"])
	_won(p, "a3")
	assert_eq(_ids(MenuLogic.visible_levels(cat, p)), ["a1", "a2", "a3", "b1", "b2*"], "chapter 2 opens with chapter 1 won")

func test_level_list_of_one_chapter() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	assert_eq(_ids(MenuLogic.visible_levels(cat, p, 1)), ["b1*"], "a locked chapter: its first level, locked")
	for id in ["a1", "a2", "a3"]: _won(p, id)
	assert_eq(_ids(MenuLogic.visible_levels(cat, p, 1)), ["b1", "b2*"])
	assert_eq(_ids(MenuLogic.visible_levels(cat, p, 0)), ["a1", "a2", "a3"])

func test_list_items_put_headings_where_the_chapter_changes() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	for id in ["a1", "a2", "a3"]: _won(p, id)
	var items := MenuLogic.list_items(null, MenuLogic.visible_levels(cat, p))
	var kinds := []
	for it in items: kinds.append(it.heading if it.has("heading") else it.level_id)
	assert_eq(kinds, ["Chapter 1", "a1", "a2", "a3", "Chapter 2", "b1", "b2"])

func test_pick_start() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	_won(p, "a1")
	assert_eq(MenuLogic.pick_start(MenuLogic.visible_levels(cat, p), p), "a2", "the first unlocked level not won yet")
	p.last_selected = "a1"
	assert_eq(MenuLogic.pick_start(MenuLogic.visible_levels(cat, p), p), "a1", "the last selected one while it can be played")
	p.last_selected = "b2"
	assert_eq(MenuLogic.pick_start(MenuLogic.visible_levels(cat, p), p), "a2", "a locked last selection is ignored")
	for id in ["a2", "a3", "b1", "b2"]: _won(p, id)
	p.last_selected = ""
	assert_eq(MenuLogic.pick_start(MenuLogic.visible_levels(cat, p), p), "b2", "all won: the last one")

func test_requirement_text() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	assert_eq(MenuLogic.requirement_text(cat, null, "a2", p), "Win a1 to open it.")
	assert_eq(MenuLogic.requirement_text(cat, null, "a1", p), "")

func test_facts_and_hand_note() -> void:
	var l := _level()
	l.hand_cap = 5
	l.start_energy = 550
	l.energy_per_round = 45
	l.waves = [WaveData.new(), WaveData.new()]
	assert_eq(MenuLogic.facts_text(l), "5 × 3   ·   2 waves   ·   Hand 5   ·   Start energy 550 (+45 a round)")
	assert_eq(MenuLogic.hand_note(7, 5), "This level takes the first 5 of your 7 towers.")
	assert_eq(MenuLogic.hand_note(3, 5), "This level takes up to 5 towers.")
	assert_eq(MenuLogic.hand_note(0, 5), "Your hand is empty: add towers with Change hand.")

func test_enemies_text_counts_in_order_of_appearance() -> void:
	var l := LevelAsset.new()
	var slime := EntityAsset.new(); slime.display_name = "Slime"
	var runner := EntityAsset.new(); runner.display_name = "Runner"
	var w := WaveData.new()
	for e in [slime, runner, slime]:
		var s := SpawnData.new(); s.enemy = e
		w.spawns.append(s)
	var ev := LevelEventData.new(); ev.kind = LevelEventKind.SpawnEnemies; ev.enemy = runner; ev.count = 3
	w.events.append(ev)
	l.waves = [w]
	assert_eq(MenuLogic.enemies_text(l), "Enemies: Slime ×2, Runner ×4")
	assert_eq(MenuLogic.enemies_text(LevelAsset.new()), "Enemies: none")

func test_controls_rows_group_headers_modifiers_then_keys() -> void:
	var kb = load("res://game/app/key_binds.gd").new()
	kb.settings_override = SettingsData.new()
	var rows := MenuLogic.controls_rows(kb.actions, kb.modifier_actions)
	kb.free()
	var shape := []
	for r in rows: shape.append(r.kind[0] + ":" + (r.label if r.kind == "header" else r.id))
	assert_eq(shape.slice(0, 4), ["h:Round", "k:EndRound", "k:Skip", "k:Pause"])
	assert_eq(shape.slice(4, 8), ["h:Towers", "m:Aim", "m:QuickCast", "m:Hand"], "a group's modifier rows come before its keys")
	assert_eq(shape[8], "k:Ability1")
	assert_eq(shape[16], "k:Ability9")
	assert_eq(shape[17], "h:Camera")
	assert_eq(shape.slice(24), ["h:Co-op", "k:Pass", "k:Chat"], "co-op keys last")
	assert_eq(shape.size(), 4 + 3 + 3 + 9 + 6 + 2, "4 headers, 3 modifiers, 20 keys")
	assert_eq(MenuLogic.modifier_option(Modifiers.None), "No modifier")
	assert_eq(MenuLogic.modifier_option(Modifiers.CtrlShift), "Ctrl+Shift")

func test_game_speed_stages() -> void:
	assert_eq(MenuLogic.speed_stage(1.0), 2)
	assert_eq(MenuLogic.speed_stage(0.25), 0)
	assert_eq(MenuLogic.speed_stage(3.5), 4, "nearest stage")

func test_chapter_cards() -> void:
	var asset := GameCatalogAsset.new()
	var a := ChapterData.new(); a.display_name = "Meadow"
	var b := ChapterData.new()
	for c in [[a, ["a1", "a2"]], [b, ["b1"]]]:
		for id in c[1]:
			var d := CatalogLevelData.new()
			d.level = LevelAsset.new()
			d.level.id = id
			d.level.display_name = id.to_upper()
			c[0].levels.append(d)
	asset.chapters = [a, b]
	var cat := asset.to_catalog()
	var p := LevelProgress.new()
	_won(p, "a1")
	var cards := MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Main)
	assert_eq(cards.size(), 2)
	assert_eq(cards[0].name, "Meadow")
	assert_eq(cards[0].status, "1 / 2 won")
	assert_true(cards[0].open)
	assert_eq(cards[1].name, "Chapter 2")
	assert_false(cards[1].open)
	assert_eq(cards[1].status, "Win A2", "a locked chapter says what opens it")
	assert_eq(MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Side), [])

func test_codex_texts() -> void:
	assert_eq(MenuLogic.status_description("Takes {stacks*5} damage for {turns} turns.", 2, 3), "Takes 10 damage for 3 turns.")
	assert_eq(MenuLogic.status_description("{turns} left", 1, -1), "– left")
	assert_eq(MenuLogic.stacking_text(Stacking.Stack, 3), "adds a stack (up to 3) and starts its time over")
	assert_eq(MenuLogic.stacking_text(Stacking.Replace, 1), "replaces it")
	assert_eq(MenuLogic.lasts_text(-1, false), "until removed")
	assert_eq(MenuLogic.lasts_text(1, true), "1 round")
	assert_eq(MenuLogic.lasts_text(3, false), "3 turns")
	assert_eq(MenuLogic.status_kind(["Debuff"]), "Status · Harmful")
	assert_eq(MenuLogic.codex_progress_text(CodexSection.Enemies, 2, 14), "2 / 14 met")
	assert_eq(MenuLogic.codex_progress_text(CodexSection.Towers, 5, 9), "5 / 9 discovered", "towers count only the discovered ones")
	assert_eq(MenuLogic.codex_progress_text(CodexSection.Statuses, 3, 10), "3 / 10 seen")
	assert_eq(MenuLogic.codex_progress_text(CodexSection.Tips, 11, 11), "11 tips")
	assert_eq(MenuLogic.portrait_name("Assets/Art/Models/Big Slime/Big Slime Blender.prefab"), "Big Slime")
	assert_eq(MenuLogic.icon_name("Assets/Art/Icons/Abilities/Shoot.png#Shoot"), "Shoot")

func test_codex_entries_skip_hidden_statuses() -> void:
	var codex := CodexAsset.new()
	var s1 := StatusAsset.new(); s1.id = "burn"; s1.display_name = "Burn"
	var s2 := StatusAsset.new(); s2.id = "secret"; s2.tags = ["Hidden"] as Array[String]
	codex.statuses = [s1, s2]
	var tip := CodexTip.new(); tip.id = "rounds"; tip.title = "Rounds"
	codex.tips = [tip]
	var e := MenuLogic.codex_entries(codex, CodexSection.Statuses)
	assert_eq(e.size(), 1)
	assert_eq(e[0].name, "Burn")
	assert_eq(MenuLogic.codex_entries(codex, CodexSection.Tips)[0].name, "Rounds")

func test_stat_words_become_numbers() -> void:
	var v := {"Speed": "2", "Power": "10"}
	assert_eq(MenuLogic.fill_stat_words("Moves the tower up to Speed tiles.", v), "Moves the tower up to 2 tiles.")
	assert_eq(MenuLogic.fill_stat_words("Bashes an enemy for Power.", v), "Bashes an enemy for 10.")
	assert_eq(MenuLogic.fill_stat_words("Gains Speed when hit.", v), "Gains Speed when hit.", "a stat named as a stat stays")
	assert_eq(MenuLogic.result_name("Move"), "Range")
	assert_eq(MenuLogic.stacking_shown(Stacking.Stack, 9999), "adds a stack and starts its time over")
	assert_eq(MenuLogic.stacking_shown(Stacking.Stack, 3), "adds a stack (up to 3) and starts its time over")

func test_speed_text() -> void:
	assert_eq(MenuLogic.speed_text(1.0), "1×")
	assert_eq(MenuLogic.speed_text(0.5), "0.5×")
	assert_eq(MenuLogic.speed_text(0.25), "0.25×")
	assert_eq(MenuLogic.speed_text(1.5), "1.5×")

func test_camp_buttons_never_overlap() -> void:
	var camp = load("res://game/ui/screens/camp.gd")
	var sz := Vector2(236, 60)
	# anchors crowded together (props standing close): every pair must keep apart
	var items := [[Vector2(500, 400), sz], [Vector2(560, 380), sz], [Vector2(610, 410), sz], [Vector2(1850, 400), sz], [Vector2(1900, 420), sz]]
	var rects: Array = camp.layout_buttons(items, 1920.0, 16.0, 28.0)
	assert_eq(rects.size(), 5)
	for i in rects.size():
		assert_true(rects[i].position.x >= 0.0 and rects[i].end.x <= 1920.0, "inside the screen")
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].grow(7.0).intersects(rects[j].grow(7.0)), "buttons %d and %d keep a gap" % [i, j])
	assert_true(rects[0].end.y <= 400.0 - 28.0 + 0.1, "above its anchor")

func test_camp_layout_reads_the_stations() -> void:
	var camp = load("res://game/ui/screens/camp.gd")
	var layout: Dictionary = camp.load_layout()
	var names := []
	for s in layout.slots:
		if s.get("station") != null: names.append(camp.STATION_ALIASES.get(s.station, s.station)) # the v2 layout says "Blacksmith" for the Workshop station
	for st in camp.STATIONS: assert_contains(names, st.id, "every station has a slot in layout.json")

func test_level_select_chapter_tag_new_until_played() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	assert_eq(MenuLogic.chapter_tag(cat, p, 0), "new", "nothing played in it yet")
	_won(p, "a1")
	assert_eq(MenuLogic.chapter_tag(cat, p, 0), "3 levels", "played: every level of the chapter counted")
	assert_eq(MenuLogic.chapter_tag(cat, p, 1), "new")
	var lost := LevelResult.new()
	lost.level_id = "b1"
	p.record(lost)
	assert_eq(MenuLogic.chapter_tag(cat, p, 1), "2 levels", "a lost attempt counts as played")

func test_level_select_enemies_hidden_until_played() -> void:
	var p := LevelProgress.new()
	assert_false(MenuLogic.has_played(null, "a1"), "no progress: not played")
	assert_false(MenuLogic.has_played(p, "a1"), "never attempted: the chips stay hidden")
	var quit := LevelResult.new()
	quit.level_id = "a1"
	quit.quit = true
	p.record(quit)
	assert_true(MenuLogic.has_played(p, "a1"), "a quit attempt counts as played (any attempt, not only a win)")
	var lost := LevelResult.new()
	lost.level_id = "a2"
	p.record(lost)
	assert_true(MenuLogic.has_played(p, "a2"), "a loss counts too")
	assert_false(MenuLogic.has_played(p, "a3"))
	assert_eq(MenuLogic.EnemiesUnplayedText, "You'll see them when you play it.")

func test_level_select_row_state_and_number() -> void:
	var cat := _catalog()
	var p := LevelProgress.new()
	assert_eq(MenuLogic.row_state(p, "a1", true), "new", "unlocked, never played")
	assert_eq(MenuLogic.row_state(p, "a2", false), "locked")
	var lost := LevelResult.new()
	lost.level_id = "a1"
	p.record(lost)
	assert_eq(MenuLogic.row_state(p, "a1", true), "", "played, not won: no mark")
	_won(p, "a1")
	assert_eq(MenuLogic.row_state(p, "a1", true), "won")
	assert_eq(MenuLogic.level_number(cat, "a3"), 3)
	assert_eq(MenuLogic.level_number(cat, "b2"), 2, "counted inside its chapter")
	assert_eq(MenuLogic.level_number(cat, "zz"), 0)
	assert_eq(MenuLogic.kicker_text("Chapter 1", 3), "Chapter 1 · level 3")
	assert_eq(MenuLogic.requirement_line(cat, null, "a2", LevelProgress.new()), "Win a1 first")
	assert_eq(MenuLogic.requirement_line(cat, null, "a1", LevelProgress.new()), "")

func test_level_select_hand_texts_and_facts() -> void:
	assert_eq(MenuLogic.slots_used_text(5), "5 of 8 slots used")
	assert_eq(MenuLogic.hand_strip_note("Two Roads", 5, 4), "Two Roads takes the first 4 towers; the rest wait on the bench.")
	assert_eq(MenuLogic.hand_strip_note("Two Roads", 3, 4), "Two Roads takes the first 4 towers.")
	assert_eq(MenuLogic.hand_strip_note("Two Roads", 0, 4), "Your hand is empty: add towers with Change hand.")
	assert_eq(MenuLogic.reward_lines("Priest", true), ["First win reward: Priest", "Already yours: replays give no reward."])
	assert_eq(MenuLogic.reward_lines("Priest", false)[0], "Win it to earn: Priest")
	assert_eq(MenuLogic.reward_lines("", false), ["", ""])
	var l := LevelAsset.new()
	var slime := EntityAsset.new(); slime.display_name = "Slime"
	var w := WaveData.new()
	for i in 3:
		var s := SpawnData.new(); s.enemy = slime
		w.spawns.append(s)
	l.waves = [w, WaveData.new()]
	l.hand_cap = 4; l.start_energy = 200; l.energy_per_round = 25
	assert_eq(MenuLogic.level_facts(l), {"waves": 2, "enemies": 3, "hand": 4, "energy": 200, "per_round": 25})
	assert_eq(MenuLogic.plural(1, "enemy", "enemies"), "enemy")
	assert_eq(MenuLogic.plural(3, "enemy", "enemies"), "enemies")

func test_level_select_spawn_shield() -> void:
	var shield := StatusAsset.new(); shield.id = "shield"
	var step := ApplyStatusStepData.new(); step.status = shield; step.stacks = Formula.new("10")
	var r := ReactionAsset.new(); r.trigger = Trigger.OnSpawned; r.response = StepList.new(); r.response.items = [step]
	var refill := ReactionAsset.new(); refill.trigger = Trigger.OnTurnStart; refill.response = StepList.new(); refill.response.items = [step]
	var pas := PassiveAsset.new(); pas.reactions = [r, refill]
	var e := EntityAsset.new(); e.passives = [pas]
	assert_eq(MenuLogic.spawn_shield(e), 10, "only what it arrives with")
	assert_eq(MenuLogic.spawn_shield(EntityAsset.new()), 0)

func _card_asset() -> GameCatalogAsset:
	# Meadow (a1, a2; a2 gives "Wisp Tower"), Chapter 2 (b1), side chapter Mill (m1; opens with a1)
	var asset := GameCatalogAsset.new()
	var a := ChapterData.new(); a.display_name = "Meadow"
	var b := ChapterData.new()
	var m := ChapterData.new(); m.display_name = "Mill"; m.kind = ChapterKind.Side
	for c in [[a, ["a1", "a2"]], [b, ["b1"]], [m, ["m1"]]]:
		for id in c[1]:
			var d := CatalogLevelData.new()
			d.level = LevelAsset.new()
			d.level.id = id
			d.level.display_name = id.to_upper()
			c[0].levels.append(d)
	var wisp := TowerAsset.new(); wisp.display_name = "Wisp Tower"
	a.levels[1].first_clear_reward = wisp
	m.requires = [a.levels[0].level]
	asset.chapters = [a, b, m]
	return asset

func test_chapter_card_texts_count_won_levels() -> void:
	var asset := _card_asset()
	var cat := asset.to_catalog()
	var p := LevelProgress.new()
	_won(p, "a1")
	var cards := MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Main)
	assert_eq(cards[0].progress, "1 / 2 won")
	assert_false(cards[0].complete)
	assert_true(cards[0].active, "holds the next level to play")
	assert_eq(cards[0].reason, "", "an open chapter has no reason")
	var states := []
	for l in cards[0].levels: states.append(l.state)
	assert_eq(states, ["won", "open"], "one dot per level: won, then the next one open")
	assert_eq(cards[0].reward_name, "Wisp Tower", "the last level's first-clear reward")
	assert_eq(cards[0].first_level.id, "a1", "the thumbnail shows the first level")
	assert_eq(cards[1].reward, null)
	assert_eq(cards[1].reward_name, "")

func test_chapter_card_complete_and_locked_reason() -> void:
	var asset := _card_asset()
	var cat := asset.to_catalog()
	var p := LevelProgress.new()
	var cards := MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Main)
	assert_false(cards[1].open)
	assert_eq(cards[1].reason, "Finish Meadow first", "a locked main chapter waits for the one before it")
	assert_eq(cards[1].levels[0].state, "locked")
	assert_false(cards[1].active)
	var side := MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Side)
	assert_eq(side.size(), 1)
	assert_eq(side[0].reason, "Win A1", "a locked side chapter names its levels")
	_won(p, "a1")
	_won(p, "a2")
	cards = MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Main)
	assert_eq(cards[0].progress, "2 / 2 won ✓ Complete")
	assert_true(cards[0].complete)
	assert_false(cards[0].active, "a complete chapter is not the active one")
	assert_true(cards[1].active, "the next chapter is")
	assert_eq(cards[1].progress, "0 / 1 won")
	assert_true(MenuLogic.chapter_cards(asset, cat, p, ChapterKind.Side)[0].open)

func test_chapter_progress_text() -> void:
	assert_eq(MenuLogic.chapter_progress_text(2, 4), "2 / 4 won")
	assert_eq(MenuLogic.chapter_progress_text(4, 4), "4 / 4 won ✓ Complete")
	assert_eq(MenuLogic.chapter_progress_text(0, 0), "0 / 0 won", "no levels: never complete")
	assert_false(MenuLogic.chapter_complete(0, 0))
