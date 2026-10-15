extends TestCase
## Missions & Guild — Design: the content (Missions.json, the catalog's guildUnlock and missions, the rules'
## towerEnergyPerDay), Validate All, MissionDef, MissionProgress (records, plays, tired
## towers, saves), the MissionBoard rules (Guild / mission unlock, plays per day and the midnight reset, tower energy,
## rested hands, start_play, drops, found_in, the co-op checks and auto-leave), the co-op list built from missions
## (and data/coop.json kept in sync for the relay), the dev save actions.

static var _lib: ContentLibrary

const DAY := "2026-10-14T19:00:00"  # 5 h before midnight
const NEXT := "2026-10-15T00:00:01"

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func setup() -> void:
	MissionBoard.energy_per_day = 1

func teardown() -> void:
	MissionBoard.energy_per_day = 1

func missions() -> Array:
	return lib().catalog.to_missions()

func m(id: String) -> MissionDef:
	return MissionBoard.find(missions(), id)

func _result(won := true, quit := false, level := "chapter2-1") -> LevelResult:
	var r := LevelResult.new()
	r.level_id = level
	r.won = won
	r.quit = quit
	r.base_hp_pct = 80
	r.rounds = 9
	return r

func _mission(id := "x", plays := 1, mode := MissionMode.Solo) -> MissionDef:
	var d := MissionDef.new()
	d.id = id
	d.name = id.capitalize()
	d.level_id = "chapter1-1"
	d.plays_per_day = plays
	d.mode = mode
	d.min_players = 1
	d.max_players = 4
	return d

# ------------------------------------------------------------------ content

func test_missions_content_loads() -> void:
	assert_eq(lib().problems.size(), 0, "\n".join(lib().problems))
	assert_eq(lib().all_of("MissionAsset").size(), 5)
	assert_eq(lib().file_of(lib().get_asset("Missions/Patrol")), "Missions.json")
	var c := lib().catalog
	assert_seq(c.missions.map(func(a): return a.get_id()), ["patrol", "night-watch", "hold-the-gate", "drum-line", "glutton-returns"])
	assert_eq(c.guild_unlock.get_id(), "chapter2-4", "Chapter 2's last level")
	assert_eq(lib().rules.tower_energy_per_day, 1)

func test_missions_starter_table() -> void:
	var p := m("patrol")
	assert_eq(p.name, "Patrol")
	assert_eq(p.level_id, "chapter1-3")
	assert_eq(p.mode, MissionMode.Any)
	assert_eq([p.min_players, p.max_players], [1, 4])
	assert_eq(p.plays_per_day, 1)
	assert_eq(p.win_tokens, {"yew-bow": 1})
	assert_eq(p.first_win_tokens, {"fire-arrow": 1})
	var n := m("night-watch")
	assert_eq(n.level_id, "chapter2-1")
	assert_eq(n.win_tokens, {"fire-arrow": 1, "poison-gland": 1})
	assert_eq(n.first_win_tokens, {"arcane-shard": 1})
	var g := m("hold-the-gate")
	assert_eq(g.mode, MissionMode.Coop)
	assert_eq([g.min_players, g.max_players], [2, 6])
	assert_eq(g.win_tokens, {"steel-plate": 1})
	assert_eq(g.first_win_tokens, {"steel-plate": 1})
	var d := m("drum-line")
	assert_eq(d.plays_per_day, 2)
	assert_eq(d.win_tokens, {"arcane-shard": 1, "poison-gland": 1})
	var e := m("glutton-returns")
	assert_eq(e.level_id, "chapter2-4")
	assert_eq(e.mode, MissionMode.Coop)
	assert_eq(e.win_tokens, {"ember-core": 1})
	for x in missions():
		assert_true(x.requires.is_empty(), "open with the Guild")
		assert_eq(x.coop_hand_cap, 3)
		assert_not_null(lib().catalog.find_level(x.level_id), x.id + ": a catalog level")
	assert_eq(MissionBoard.mode_text(g), "Co-op 2–6")
	assert_eq(MissionBoard.mode_text(p), "Any")
	assert_eq(g.clamp_players(9), 6)
	assert_eq(g.clamp_players(1), 2)
	assert_true(p.is_solo and p.is_coop)
	assert_false(g.is_solo)

func test_chapter_levels_drop_nothing() -> void:
	for e in lib().catalog.to_catalog().entries:
		assert_eq(e.first_win_tokens, {}, e.level_id)
		assert_eq(e.win_tokens, {}, e.level_id)
	var p := LevelProgress.new()
	var r := _result(true, false, "chapter2-4")
	var w := TokenWallet.new()
	assert_eq(lib().catalog.grant_drops(r, p.record(r), w), {}, "no mission: a chapter level gives no tokens")
	assert_eq(w.total(), 0)

func test_missions_validate_all() -> void:
	var findings := ContentCheck.run(lib().all, ContentCheck.vocabulary_of(lib().rules))
	var errors := findings.filter(func(f): return f.error).map(func(f): return f.message)
	assert_eq(errors.size(), 0, "\n".join(errors))
	assert_eq(findings.filter(func(f): return f.message.contains("no mission drops it")).size(), 0, "every token drops from a mission")
	assert_eq(findings.filter(func(f): return f.message.contains("not on the mission board")).size(), 0)
	# a token no mission drops warns; a mission off the board warns
	var t := TokenAsset.new()
	t.name = "Lonely"; t.id = "lonely"
	var extra := MissionAsset.new()
	extra.name = "Off Board"; extra.id = "off"; extra.level = lib().catalog.find_level("chapter1-1")
	var more := ContentCheck.run([lib().catalog, t, extra], ContentCheck.vocabulary_of(lib().rules))
	assert_true(more.any(func(f): return not f.error and f.message.contains("Lonely: no mission drops it")))
	assert_true(more.any(func(f): return not f.error and f.message.contains("Off Board: not on the mission board")))

func test_mission_validation_rules() -> void:
	var a := MissionAsset.new()
	a.name = "Broken"
	a.mode = MissionMode.Coop
	a.players = PlayerRange.new()
	a.players.min = 0
	a.players.max = 7
	a.plays_per_day = 0
	a.coop_hand_cap = 0
	a.requires = [null]
	var amt := TokenAmount.new()
	amt.amount = 1
	a.win_tokens = [amt]
	var errors := AssetValidator.validate_mission(a)
	for part in ["no mission ID", "no level", "playsPerDay", "players 0–7", "coopHandCap", "requires[0] is empty", "winTokens[0] has no token"]:
		assert_true(errors.any(func(e): return e.contains(part)), part + "\n" + "\n".join(errors))
	# a cycle of requirements, and a requirement on itself
	var x := MissionAsset.new()
	var y := MissionAsset.new()
	x.name = "X"; x.id = "x"; x.level = lib().catalog.find_level("chapter1-1")
	y.name = "Y"; y.id = "y"; y.level = x.level
	x.requires = [y]
	y.requires = [x]
	assert_true(AssetValidator.validate_mission(x).any(func(e): return e.contains("cycle")))
	y.requires = [y]
	assert_true(AssetValidator.validate_mission(y).any(func(e): return e.contains("requires itself")))
	# a Solo mission ignores the player range
	var solo := MissionAsset.new()
	solo.name = "Solo"; solo.id = "solo"; solo.level = x.level
	assert_eq(AssetValidator.validate_mission(solo).size(), 0)
	# the catalog: the board lists a mission once; guildUnlock is a chapter level
	var c := GameCatalogAsset.new()
	c.name = "C"
	c.chapters = lib().catalog.chapters
	c.missions = [solo, solo, null]
	c.guild_unlock = lib().get_asset("Levels/Other/Test Level")
	var ce := AssetValidator.validate_catalog(c)
	assert_true(ce.any(func(e): return e.contains("listed twice")))
	assert_true(ce.any(func(e): return e.contains("missions[2] is empty")))
	assert_true(ce.any(func(e): return e.contains("guildUnlock")))

func test_bad_mission_fields_are_reported() -> void:
	var l := ContentLibrary.new()
	l.add([["Rules.json", JSON.stringify({"type": "GameRulesAsset", "assets": {"Settings/GameRules": {"towerEnergyPerDay": "x", "odd": 1}}})]])
	assert_true(l.problems.size() >= 2, "\n".join(l.problems))
	assert_eq(l.rules.tower_energy_per_day, 1, "a bad value keeps the default")

func test_content_hash_includes_missions() -> void:
	var names := ContentHash._files_of(ContentFiles.Folder, "").map(func(f): return f[0])
	assert_contains(names, "Missions.json")
	assert_not_contains(names, "Extras.json")
	assert_false(DirAccess.dir_exists_absolute("res://data/content-godot"), "no overlay folder any more")

func test_mission_asset_round_trips() -> void:
	var a: MissionAsset = lib().get_asset("Missions/Hold the Gate")
	var json := ContentSerializer.to_json(a, lib())
	assert_eq(json["mode"], "Coop")
	assert_eq(json["players"], {"min": 2, "max": 6})
	assert_eq(json["level"], "Levels/Chapter 2/2 Three at the Gate")
	var b := MissionAsset.new()
	var problems := []
	ContentSerializer.load_into(b, json, lib(), problems, "x")
	assert_eq(problems.size(), 0, "\n".join(problems))
	assert_eq(JSON.stringify(ContentSerializer.to_json(b, lib())), JSON.stringify(json))

# ------------------------------------------------------------------ time

func test_now_forms_and_reset_texts() -> void:
	assert_eq(MissionBoard.day_of("2026-10-14"), "2026-10-14")
	assert_eq(MissionBoard.day_of(DAY), "2026-10-14")
	assert_eq(MissionBoard.day_of({"year": 2026, "month": 3, "day": 5, "hour": 1}), "2026-03-05")
	assert_eq(MissionBoard.day_of("2026-10-14 23:59:59"), "2026-10-14")
	assert_eq(MissionBoard.day_of(null).length(), 10, "the system clock")
	assert_eq(MissionBoard.resets_in(DAY), 5 * 3600)
	assert_eq(MissionBoard.resets_in("2026-10-14"), 86400, "a bare date is its midnight")
	assert_eq(MissionBoard.resets_in("2026-10-14T23:59:59"), 1)
	assert_eq(MissionBoard.resets_in_text(DAY), "resets in 5 h")
	assert_eq(MissionBoard.resets_in_text("2026-10-14T23:40:00"), "resets in 20 min")
	assert_eq(MissionBoard.resets_in_text("2026-10-14T19:30:00"), "resets in 5 h", "hours round up")
	assert_eq(MissionBoard.duration_text(3600), "1 h")
	assert_eq(MissionBoard.duration_text(59), "1 min")
	assert_eq(MissionBoard.done_text(DAY), "Done today · resets in 5 h")
	assert_eq(MissionBoard.tired_text(DAY), "Tired · rests in 5 h")

# ------------------------------------------------------------------ plays

func test_plays_per_day_and_midnight_reset() -> void:
	var mp := MissionProgress.new()
	var d := m("drum-line")
	var hand := ["a", "b", "c", "d", "e", "f"]
	assert_eq(MissionBoard.plays_left(d, mp, DAY), 2)
	assert_eq(MissionBoard.plays_text(d, mp, DAY), "2 plays left today")
	assert_eq(MissionBoard.start_play(d, mp, hand, 2, DAY), ["a", "b"])
	assert_eq(MissionBoard.plays_left(d, mp, DAY), 1)
	assert_eq(MissionBoard.plays_text(d, mp, DAY), "1 play left today")
	assert_eq(MissionBoard.plays_of_text(d, mp, DAY), "1 of 2 plays left today")
	assert_eq(MissionBoard.start_play(d, mp, hand, 2, DAY), ["c", "d"], "the tired ones are skipped")
	assert_eq(MissionBoard.plays_left(d, mp, DAY), 0)
	assert_eq(MissionBoard.start_play(d, mp, hand, 2, DAY), [])
	assert_eq(MissionBoard.last_reason, "Done today · resets in 5 h")
	assert_false(MissionBoard.can_play(d, mp, DAY))
	assert_eq(MissionBoard.plays_text(d, mp, DAY), "Done today · resets in 5 h")
	assert_eq(mp.plays, [{"id": "drum-line", "day": "2026-10-14", "count": 2}])
	# other missions keep their own count
	assert_eq(MissionBoard.plays_left(m("patrol"), mp, DAY), 1)
	# midnight: a new day, a new count
	assert_eq(MissionBoard.plays_left(d, mp, NEXT), 2)
	assert_eq(MissionBoard.start_play(d, mp, hand, 2, NEXT), ["a", "b"], "rested again after midnight")
	assert_eq(mp.plays, [{"id": "drum-line", "day": "2026-10-15", "count": 1}], "one entry per mission")

func test_a_refused_start_changes_nothing() -> void:
	var mp := MissionProgress.new()
	var p := m("patrol")
	assert_eq(MissionBoard.start_play(p, mp, [], 4, DAY), [])
	assert_eq(MissionBoard.last_reason, MissionBoard.EmptyHand)
	assert_eq(mp.plays.size(), 0)
	mp.tire("a", "2026-10-14")
	mp.tire("b", "2026-10-14")
	assert_eq(MissionBoard.start_play(p, mp, ["a", "b"], 4, DAY), [])
	assert_eq(MissionBoard.last_reason, "All your towers are tired: change your hand or come back tomorrow")
	assert_eq(mp.plays.size(), 0, "no play spent")
	assert_false(MissionBoard.can_start(p, mp, ["a", "b"], 4, DAY))
	assert_true(MissionBoard.can_start(p, mp, ["a", "b", "c"], 4, DAY))
	assert_eq(MissionBoard.last_reason, "")

# ------------------------------------------------------------------ tower energy

func test_tired_towers_and_the_rested_hand() -> void:
	var mp := MissionProgress.new()
	var hand := ["t1", "t2", "t3", "t4", "t5"]
	var taken := MissionBoard.start_play(m("night-watch"), mp, hand, 3, DAY)
	assert_eq(taken, ["t1", "t2", "t3"], "the first ones up to the cap")
	for id in taken: assert_true(MissionBoard.is_tired(id, mp, DAY), id)
	assert_false(MissionBoard.is_tired("t4", mp, DAY), "the bench keeps its energy")
	assert_false(MissionBoard.is_tired("t1", mp, NEXT), "rested after midnight")
	assert_eq(MissionBoard.rested_hand(hand, mp, DAY), ["t4", "t5"])
	assert_eq(MissionBoard.taken(hand, mp, 3, DAY), ["t4", "t5"], "the level takes the first RESTED towers")
	assert_eq(MissionBoard.start_play(m("patrol"), mp, hand, 4, DAY), ["t4", "t5"])
	assert_eq(MissionBoard.start_play(m("drum-line"), mp, hand, 4, DAY), [])
	assert_eq(MissionBoard.last_reason, MissionBoard.AllTired)
	# hands of TowerDefs keep their element type
	var a := TowerDef.new()
	a.id = "t1"
	var b := TowerDef.new()
	b.id = "t9"
	assert_eq(MissionBoard.rested_hand([a, b], mp, DAY), [b])
	# chapter levels never tire towers: only start_play / record_play write the tired list
	assert_eq(mp.tired.size(), 5)

func test_tower_energy_per_day_comes_from_the_rules() -> void:
	MissionBoard.energy_per_day = 2
	var mp := MissionProgress.new()
	MissionBoard.start_play(m("drum-line"), mp, ["a"], 1, DAY)
	assert_false(MissionBoard.is_tired("a", mp, DAY), "1 of 2 energy spent")
	MissionBoard.start_play(m("drum-line"), mp, ["a"], 1, DAY)
	assert_true(MissionBoard.is_tired("a", mp, DAY))
	assert_eq(mp.uses_on("a", "2026-10-14"), 2)

func test_mission_hand_builds_the_rested_towers() -> void:
	var c := AssetConverter.new()
	var towers := TowerCollection.new()
	for t in ["archer", "cannon", "mage", "guardian"]:
		var o := towers.add(t)
		towers.add_to_hand(o.id)
	var mp := MissionProgress.new()
	mp.tire(towers.hand[0], "2026-10-14")
	var taken := MissionBoard.start_play(m("night-watch"), mp, towers.hand, 2, DAY)
	assert_eq(taken, [towers.hand[1], towers.hand[2]])
	var hand := lib().catalog.build_hand(towers, c, [], taken)
	assert_eq(hand.map(func(d): return d.id), taken)
	assert_eq(lib().catalog.build_hand(towers, c).size(), 4, "without ids: the whole hand")

# ------------------------------------------------------------------ rewards and records

func test_drops_win_every_time_first_win_once() -> void:
	var mp := MissionProgress.new()
	var n := m("night-watch")
	var w := TokenWallet.new()
	assert_eq(MissionBoard.finish(_result(false), n, mp, w), {}, "a loss gives nothing")
	assert_eq(MissionBoard.finish(_result(true, true), n, mp, w), {}, "a quit gives nothing")
	assert_eq(MissionBoard.finish(_result(), n, mp, w), {"arcane-shard": 1, "fire-arrow": 1, "poison-gland": 1}, "first win: both lists")
	assert_eq(MissionBoard.finish(_result(), n, mp, w), {"fire-arrow": 1, "poison-gland": 1}, "later wins: the win drop")
	assert_eq(w.count("fire-arrow"), 2)
	assert_eq(w.count("arcane-shard"), 1)
	var r := mp.find("night-watch")
	assert_eq([r.attempts, r.wins, r.won, r.best_base_hp_pct, r.fewest_rounds], [4, 2, true, 80, 9])
	assert_true(mp.is_won("night-watch"))
	assert_false(mp.is_won("patrol"))
	# the drops alone, and through the catalog with a mission
	var mp2 := MissionProgress.new()
	var res := _result()
	assert_eq(MissionBoard.drops(res, mp2.record(res, "patrol"), m("patrol")), {"fire-arrow": 1, "yew-bow": 1})
	var w2 := TokenWallet.new()
	var res2 := _result()
	assert_eq(lib().catalog.grant_drops(res2, mp2.record(res2, "patrol"), w2, m("patrol")), {"yew-bow": 1})
	assert_eq(HudText.rewards_text({"ember-core": 1}, lib().catalog), "Rewards: Ember Core ×1")

func test_mission_records_never_touch_chapter_progress() -> void:
	var g := GameData.new()
	MissionBoard.finish(_result(true, false, "chapter2-4"), m("glutton-returns"), g.missions, g.tokens)
	assert_false(g.progress.is_won("chapter2-4"))
	assert_eq(g.progress.levels.size(), 0)
	assert_true(g.missions.is_won("glutton-returns"))
	assert_null(g.missions.record(null))
	assert_ne(g.missions.last_error, "")

# ------------------------------------------------------------------ unlock

func test_guild_and_mission_unlock() -> void:
	var c := lib().catalog
	var p := LevelProgress.new()
	var mp := MissionProgress.new()
	assert_false(MissionBoard.is_guild_unlocked(p, c))
	assert_eq(MissionBoard.last_reason, "Win The Glutton to open the Guild")
	assert_false(MissionBoard.is_unlocked(m("patrol"), p, mp, c), "missions wait for the Guild")
	DevShortcuts.complete_main_chapters(_data_with(p), c, 2)
	assert_true(MissionBoard.is_guild_unlocked(p, c))
	assert_true(MissionBoard.is_unlocked(m("patrol"), p, mp, c))
	assert_false(MissionBoard.is_guild_unlocked(p, null))
	# requirements: all / any, levels or missions
	var x := _mission("x")
	x.requires = ["chapter2-1", "night-watch"]
	assert_false(MissionBoard.is_unlocked(x, p, mp, c))
	assert_eq(MissionBoard.last_reason, "Win Night Watch first")
	x.requires = ["night-watch", "drum-line"]
	assert_false(MissionBoard.is_unlocked(x, p, mp, c))
	assert_eq(MissionBoard.last_reason, "Win Night Watch and Drum Line first")
	x.require_all = false
	assert_false(MissionBoard.is_unlocked(x, p, mp, c))
	assert_eq(MissionBoard.last_reason, "Win Night Watch or Drum Line first")
	mp.record(_result(), "drum-line")
	assert_true(MissionBoard.is_unlocked(x, p, mp, c), "any one")
	x.require_all = true
	assert_false(MissionBoard.is_unlocked(x, p, mp, c))
	assert_true(MissionBoard.is_unlocked(_mission("free"), LevelProgress.new(), null), "no catalog: only the requirement")

func _data_with(p: LevelProgress) -> GameData:
	var g := GameData.new()
	g.progress = p
	return g

# ------------------------------------------------------------------ found in

func test_found_in_reads_missions() -> void:
	var ms := missions()
	assert_seq(MissionBoard.found_in("poison-gland", ms), ["night-watch", "drum-line"])
	assert_seq(MissionBoard.found_in("ember-core", ms), ["glutton-returns"])
	assert_seq(MissionBoard.found_in("nothing", ms), [])
	assert_eq(MissionBoard.found_in_text("poison-gland", ms), "Night Watch and Drum Line")
	assert_eq(MissionBoard.found_in_text("fire-arrow", ms), "Patrol, Night Watch and Drum Line")
	assert_eq(MissionBoard.found_in_text("nothing", ms), "")
	assert_seq(Workshop.found_in("steel-plate", ms), ["hold-the-gate"])
	# the older screen code passes a LevelCatalog: the levels the missions play
	var lc := lib().catalog.to_catalog()
	assert_eq(lc.missions.size(), 5)
	assert_seq(Workshop.found_in("poison-gland", lc), ["chapter2-1", "chapter2-3"])
	assert_seq(Workshop.found_in("yew-bow", lc), ["chapter1-3"])

# ------------------------------------------------------------------ co-op

func test_coop_create_join_and_auto_leave() -> void:
	var mp := MissionProgress.new()
	var g := m("hold-the-gate")
	assert_true(MissionBoard.can_create(g, mp, DAY))
	assert_true(MissionBoard.can_join(g, mp, DAY))
	assert_eq(MissionBoard.auto_leave_reason(g, mp, DAY), "")
	MissionBoard.record_play(g, mp, ["t1", "t2"], DAY) # the match start: no checks
	assert_false(MissionBoard.can_create(g, mp, DAY))
	assert_eq(MissionBoard.last_reason, "Done today · resets in 5 h")
	assert_false(MissionBoard.can_join(g, mp, DAY))
	assert_eq(MissionBoard.auto_leave_reason(g, mp, DAY), "Done today: the room switched to Hold the Gate")
	assert_true(MissionBoard.is_tired("t1", mp, DAY), "the match tires the local player's towers")
	assert_true(MissionBoard.can_join(g, mp, NEXT))
	assert_eq(MissionBoard.auto_leave_reason(g, mp, NEXT), "")
	assert_false(MissionBoard.can_create(_mission("solo-only"), mp, DAY))
	assert_eq(MissionBoard.last_reason, "Not a co-op mission")
	# Ready needs a rested tower to bring
	assert_false(MissionBoard.can_bring(["t1", "t2"], mp, 3, DAY))
	assert_eq(MissionBoard.last_reason, MissionBoard.AllTired)
	assert_true(MissionBoard.can_bring(["t1", "t3"], mp, 3, DAY))

func test_coop_list_comes_from_missions() -> void:
	var list := CoopList.from_missions(missions())
	assert_seq(list.level_ids(), ["chapter1-3", "chapter2-1", "chapter2-2", "chapter2-3", "chapter2-4"])
	assert_false(list.shared_pool("chapter1-3"))
	assert_false(list.shared_pool("chapter2-2"))
	assert_eq(list.hand_cap("chapter2-4"), 3)
	assert_eq(list.find("chapter2-2").mission_id, "hold-the-gate")
	assert_null(list.find("chapter1-1"), "not a mission: not in the lobby")
	assert_eq(MissionBoard.coop_missions(missions()).size(), 5, "Any and Coop missions")
	assert_eq(MissionBoard.for_level(missions(), "chapter2-3").id, "drum-line")
	assert_null(MissionBoard.for_level(missions(), "chapter1-1"))
	# data/coop.json (read by the relay for shared_pool) mirrors the missions: regenerate with tools/coop_json.gd
	var file := CoopList.load()
	assert_eq(file.last_error, "")
	assert_seq(file.level_ids(), list.level_ids(), "data/coop.json is out of date: run tools/coop_json.gd")
	for id in list.level_ids():
		assert_eq(file.shared_pool(id), list.shared_pool(id), id)
		assert_eq(file.hand_cap(id), list.hand_cap(id), id)
		assert_eq(file.find(id).mission_id, list.find(id).mission_id, id)
	assert_eq(CoopList.parse(list.to_json_text()).level_ids(), list.level_ids())

func test_create_message_carries_the_mission_as_an_extra_field() -> void:
	var msg := NetProtocol.create("Room", "chapter2-2", 2, "", ["archer"], "hold-the-gate")
	assert_eq(msg.level, "chapter2-2", "the relay still gets the level id")
	assert_eq(msg.mission, "hold-the-gate")
	assert_false(NetProtocol.create("Room", "chapter2-2", 2, "", []).has("mission"))

# ------------------------------------------------------------------ saves and dev tools

func test_save_round_trip_and_old_saves() -> void:
	var g := GameData.new()
	g.profile.guild_seen = true
	MissionBoard.start_play(m("drum-line"), g.missions, ["a", "b"], 1, DAY)
	MissionBoard.finish(_result(), m("drum-line"), g.missions, g.tokens)
	var back := GameData.from_json(g.to_json())
	assert_true(back.profile.guild_seen)
	assert_eq(back.missions.plays, [{"id": "drum-line", "day": "2026-10-14", "count": 1}])
	assert_eq(back.missions.tired, [{"tower": "a", "day": "2026-10-14", "count": 1}])
	assert_eq(back.missions.find("drum-line").wins, 1)
	assert_eq(back.tokens.count("arcane-shard"), 1)
	assert_true(MissionBoard.is_tired("a", back.missions, DAY))
	var d := g.to_dict()
	assert_eq(d["missions"]["records"][0]["missionId"], "drum-line")
	assert_true(d["profile"]["guildSeen"])
	# a save from before missions
	var old := GameData.from_dict({"profile": {"created": true, "playerName": "Eren"}, "progress": {"levels": []}})
	assert_false(old.profile.guild_seen)
	assert_eq(old.missions.records.size(), 0)
	assert_eq(old.missions.plays.size(), 0)
	assert_eq(old.missions.tired.size(), 0)
	# the doc's {tower, day} shape counts 1; junk is skipped
	var odd := MissionProgress.from_dict({"tired": [{"tower": "x", "day": "2026-10-14"}, 5, {"day": "x"}], "plays": "no", "records": [{"missionId": ""}]})
	assert_eq(odd.uses_on("x", "2026-10-14"), 1)
	assert_eq(odd.tired.size(), 1)
	assert_eq(odd.records.size(), 0)

func test_dev_actions_clear_chapter_2_and_rest() -> void:
	var g := GameData.new()
	var line := SaveTools.run("chapter2", g, lib().catalog)
	assert_true(line.contains("the Guild is open"), line)
	assert_true(lib().catalog.guild_unlocked(g.progress))
	assert_eq(g.tokens.total(), 0, "chapter levels drop no tokens")
	MissionBoard.start_play(m("patrol"), g.missions, g.towers.hand, 4, DAY)
	assert_eq(MissionBoard.plays_left(m("patrol"), g.missions, DAY), 0)
	line = SaveTools.run("rest_missions", g, lib().catalog)
	assert_true(line.contains("rested"), line)
	assert_eq(MissionBoard.plays_left(m("patrol"), g.missions, DAY), 1)
	assert_eq(g.missions.tired.size(), 0)
	var ids := SaveTools.ACTIONS.map(func(a): return a[0])
	assert_contains(ids, "chapter2")
	assert_contains(ids, "rest_missions")
	assert_true(SaveTools.summary(g).contains("missions won 0"))

func test_level_launch_carries_the_mission() -> void:
	var level := lib().catalog.find_level("chapter2-1")
	LevelLaunch.request(level, "night-watch")
	assert_eq(LevelLaunch.mission_id, "night-watch")
	LevelLaunch.request(level)
	assert_eq(LevelLaunch.mission_id, "", "a plain request drops the mission")
	LevelLaunch.request(level, "night-watch")
	LevelLaunch.clear()
	assert_eq(LevelLaunch.mission_id, "")
	assert_false(LevelLaunch.has_request())
