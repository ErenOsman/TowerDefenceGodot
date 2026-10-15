extends TestCase
## The tools' save rules (SaveTools), the dev launch request (DevLaunch) and Validate All rows (ContentProblems).

const PATH := "user://test_tools_save.json"
static var _lib: ContentLibrary

func catalog() -> GameCatalogAsset:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib.catalog

func teardown() -> void:
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DevLaunch.clear("user://test_dev_launch.json")

func test_text_round_trip_and_checks() -> void:
	assert_ne(SaveTools.check_text("{nope"), "")
	assert_ne(SaveTools.check_text("[1, 2]"), "")
	assert_ne(SaveTools.write_text(PATH, "{broken"), "")
	assert_false(FileAccess.file_exists(PATH), "nothing written when the text is not a save")
	var g := GameData.new()
	g.profile.create("Eren")
	assert_eq(SaveTools.write_text(PATH, g.to_json()), "")
	assert_eq(SaveTools.load_data(PATH).profile.player_name, "Eren")
	assert_eq(SaveTools.load_data("user://no_such_save.json").profile.created, false, "defaults when missing")

func test_quick_actions() -> void:
	var g := GameData.new()
	assert_eq(SaveTools.set_player_name(g, "  A very long player name  "), PlayerProfile.clean_name("A very long player name"))
	assert_true(g.profile.created)
	var types := catalog().tower_types.filter(func(t): return t != null).size()
	assert_eq(SaveTools.grant_all_towers(g, catalog()), types)
	assert_eq(SaveTools.grant_all_towers(g, catalog()), 0, "once")
	assert_eq(g.towers.hand.size(), mini(types, TowerCollection.MaxHand))
	var reward := SaveTools.mark_tutorial_done(g, catalog())
	assert_eq(g.profile.tutorial, TutorialState.Done)
	assert_eq(reward, catalog().tutorial_reward)
	assert_null(SaveTools.mark_tutorial_done(g, catalog()), "the reward is given once")
	g.codex.discover(CodexSection.Enemies, "slime")
	SaveTools.clear_codex(g)
	assert_eq(g.codex.discovered.size(), 0)
	var line := SaveTools.run("win_first", g, catalog(), 2)
	assert_eq(line, "Won 2 of the first 2 level(s).")
	assert_text(SaveTools.run("chapter1", g, catalog()), "Chapter 1: won")
	assert_true(catalog().camp_unlocked(g.progress), "Chapter 1 done opens the Camp")
	assert_text(SaveTools.summary(g), "levels won")
	assert_text(SaveTools.run("nope", g, catalog()), "Unknown")

func test_dev_launch_file() -> void:
	var p := "user://test_dev_launch.json"
	assert_null(DevLaunch.take(p))
	var req := DevLaunch.make("chapter1-2", ["archer", "mage"], 7, true)
	assert_eq(DevLaunch.write_file(req, p), "")
	assert_true(DevLaunch.has_request(p))
	var got = DevLaunch.take(p)
	assert_eq(got.level_id, "chapter1-2")
	assert_seq(got.hand, ["archer", "mage"])
	assert_eq(int(got.seed), 7)
	assert_eq(got.instant, true)
	assert_eq(got.record, false)
	assert_false(FileAccess.file_exists(p), "taken once")
	var old := DevLaunch.make("chapter1-1")
	old.time = Time.get_unix_time_from_system() - DevLaunch.MAX_AGE - 5
	DevLaunch.write_file(old, p)
	assert_null(DevLaunch.take(p), "a stale request is ignored")
	assert_false(FileAccess.file_exists(p))
	DevLaunch.request(DevLaunch.make("tutorial", [], 0))
	assert_eq(DevLaunch.take(p).seed, 1, "seed at least 1; in-process first")
	assert_null(DevLaunch.take(p))

func test_content_problems_rows() -> void:
	var rows := ContentProblems.run()
	assert_eq(rows.filter(func(r): return r.error).size(), 0, "\n".join(rows.map(func(r): return r.message)))
	assert_eq(ContentProblems.counts([]), "0 errors, 0 warnings")
	assert_eq(ContentProblems.counts([{"error": true}, {"error": false}, {"error": false}]), "1 error, 2 warnings")
	var line := ContentProblems.line_of("res://data/content/Abilities.json", "Ability/Shoot")
	assert_true(line > 1)
	assert_text(FileAccess.get_file_as_string("res://data/content/Abilities.json").split("\n")[line - 1], "\"Ability/Shoot\"")
	# a broken file shows up as a row with its file
	var lib := ContentLibrary.new()
	lib.add([["Broken.json", "{ nope"]])
	var broken := ContentProblems.of_library(lib)
	assert_eq(broken.size(), 1)
	assert_eq(broken[0].file, "Broken.json")
	assert_true(broken[0].error)

func assert_text(text: String, part: String, msg := "") -> void:
	assert_true(text.contains(part), "%s missing: %s" % [msg, part.c_escape()])

func assert_no_text(text: String, part: String, msg := "") -> void:
	assert_false(text.contains(part), "%s unexpected: %s" % [msg, part.c_escape()])
