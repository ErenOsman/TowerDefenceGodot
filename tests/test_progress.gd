extends TestCase
## Port of ProgressTests.cs: Level Select — Design: progress records, unlock rules, which levels show, catalog checks.

func _e(id: String, chapter: int = 0) -> CatalogEntry:
	var e := CatalogEntry.new(); e.level_id = id; e.chapter = chapter
	return e

func _needs(id: String, all: bool, requires: Array) -> CatalogEntry:
	var e := CatalogEntry.new()
	e.level_id = id; e.requirement = RequirementKind.Levels; e.requires = requires.duplicate(); e.require_all = all
	return e

func _open(id: String) -> CatalogEntry:
	var e := CatalogEntry.new(); e.level_id = id; e.requirement = RequirementKind.Open
	return e

func _result(id: String, won: bool, quit := false, rounds := 0) -> LevelResult:
	var r := LevelResult.new(); r.level_id = id; r.won = won; r.quit = quit; r.rounds = rounds
	return r

func _win(id: String, hp := 50, rounds := 10, lost := 1) -> LevelResult:
	var r := LevelResult.new()
	r.level_id = id; r.won = true; r.base_hp_pct = hp; r.rounds = rounds; r.towers_lost = lost; r.when = "2026-10-03"
	return r

func _side(requires: Array) -> ChapterInfo:
	var c := ChapterInfo.new(); c.kind = ChapterKind.Side; c.requires = requires.duplicate()
	return c

func _some_contains(list: Array, part: String) -> void:
	for s in list:
		if s.contains(part): return
	fail("no item contains '%s' in %s" % [part, str(list)])

func test_records_count_attempts_and_keep_the_best_win() -> void:
	var p := LevelProgress.new()
	p.record(_result("a", false, false, 4))
	p.record(_win("a", 40, 12, 2))
	p.record(_win("a", 90, 15, 3))
	p.record(_result("a", false, true))

	var r := p.find("a")
	assert_eq(r.attempts, 4)
	assert_eq(r.wins, 2)
	assert_true(r.won)
	assert_eq(r.best_base_hp_pct, 90)
	assert_eq(r.fewest_rounds, 12)
	assert_eq(r.fewest_towers_lost, 2)
	assert_eq(r.last_played, "2026-10-03")

func test_a_loss_or_a_quit_never_counts_as_won() -> void:
	var p := LevelProgress.new()
	p.record(_result("a", false))
	p.record(_result("a", true, true))
	assert_false(p.is_won("a"))
	assert_eq(p.find("a").best_base_hp_pct, -1)
	assert_eq(p.find("a").attempts, 2)

func test_by_default_each_level_needs_the_one_before() -> void:
	var c := LevelCatalog.new([_e("1"), _e("2"), _e("3", 1)])
	var p := LevelProgress.new()
	assert_true(c.is_unlocked(c.find("1"), p))
	assert_false(c.is_unlocked(c.find("2"), p))

	p.record(_win("1"))
	assert_true(c.is_unlocked(c.find("2"), p))
	assert_false(c.is_unlocked(c.find("3"), p), "the next chapter's first level needs the previous chapter's last")

func test_all_and_any_requirements() -> void:
	var c := LevelCatalog.new([_e("a"), _open("b"), _needs("both", true, ["a", "b"]), _needs("either", false, ["a", "b"])])
	var p := LevelProgress.new()
	p.record(_win("b"))
	assert_false(c.is_unlocked(c.find("both"), p))
	assert_true(c.is_unlocked(c.find("either"), p))
	p.record(_win("a"))
	assert_true(c.is_unlocked(c.find("both"), p))

func test_unlocked_levels_show_plus_only_the_first_locked_one() -> void:
	var c := LevelCatalog.new([_e("1"), _e("2"), _e("3"), _e("4")])
	var p := LevelProgress.new()

	var shown := c.visible(p)
	assert_seq(shown.map(func(s): return s.entry.level_id), ["1", "2"])
	assert_seq(shown.map(func(s): return s.unlocked), [true, false])

	p.record(_win("1"))
	p.record(_win("2"))
	shown = c.visible(p)
	assert_seq(shown.map(func(s): return s.entry.level_id), ["1", "2", "3", "4"])
	assert_false(shown.back().unlocked, "4 is the one locked level shown")

func test_next_level_is_the_next_unlocked_one_not_yet_won() -> void:
	var c := LevelCatalog.new([_e("1"), _e("2"), _e("3")])
	var p := LevelProgress.new()
	p.record(_win("1"))
	assert_eq(c.next_after("1", p).level_id, "2")
	assert_null(c.next_after("3", p))
	p.record(_win("2"))
	assert_eq(c.next_after("1", p).level_id, "3", "won levels are skipped")

func test_side_chapters_open_by_their_levels_and_continue_follows_the_main_story() -> void:
	# chapter 0 and 2 are main, chapter 1 is a side chapter opened by winning "2"
	var c := LevelCatalog.new([_e("1"), _e("2"), _e("s1", 1), _e("s2", 1), _e("3", 2)],
		[ChapterInfo.new(), _side(["2"]), ChapterInfo.new()])
	var p := LevelProgress.new()
	assert_eq(c.next_main_level(p).level_id, "1")
	assert_false(c.is_chapter_unlocked(1, p))

	p.record(_win("1"))
	p.record(_win("2"))
	assert_true(c.is_chapter_unlocked(1, p), "the side chapter opens with its level")
	assert_true(c.is_unlocked(c.find("s1"), p))
	assert_false(c.is_unlocked(c.find("s2"), p), "inside a chapter each level needs the one before")
	assert_true(c.is_unlocked(c.find("3"), p), "the next main chapter needs the previous main chapter, not the side one")
	assert_eq(c.next_main_level(p).level_id, "3", "Continue skips side chapters")

	p.record(_win("3"))
	assert_null(c.next_main_level(p), "nothing left in the story")
	_some_contains(LevelCatalog.new([_e("1"), _e("x", 1)], [ChapterInfo.new(), _side(["nope"])]).problems(),
		"requires unknown level 'nope'")

func test_catalog_problems_are_reported() -> void:
	var empty := CatalogEntry.new(); empty.level_id = "empty"; empty.requirement = RequirementKind.Levels
	var c := LevelCatalog.new([
		_e("1"), _e("1"), _needs("self", true, ["self"]), _needs("ghost", true, ["nope"]),
		_needs("x", true, ["y"]), _needs("y", true, ["x"]), _open(""), empty])
	var problems := c.problems()
	_some_contains(problems, "in the catalog twice")
	_some_contains(problems, "requires itself")
	_some_contains(problems, "unknown level 'nope'")
	_some_contains(problems, "x: can never be unlocked")
	_some_contains(problems, "has no level id")
	_some_contains(problems, "lists none")

	assert_eq(LevelCatalog.new([_e("1"), _e("2"), _needs("3", false, ["1", "2"])]).problems().size(), 0)

func test_a_result_is_read_from_a_finished_level() -> void:
	var base_def := EntityDef.new()
	base_def.name = "Base"; base_def.kind = EntityKind.Object_; base_def.tags = [Tags.Base]
	base_def.stat("MaxHp", 10)
	var level := LevelDef.new()
	level.width = 4; level.height = 3
	level.paths = [[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]]
	var b := BaseDef.new(); b.tile = Vector2i(3, 1); b.entity = base_def
	level.bases = [b]
	var w := WaveDef.new(); w.start_round = 1  # nothing spawns: the wave finishes in round 1
	level.waves = [w]
	var session := LevelSession.new(level, GameRules.new(CombatVocabulary.create()), [], 1)
	session.start()
	session.state.get_entity(session.bases[0]).hp = 7
	session.end_round()
	assert_eq(session.outcome, Outcome.Won)

	var r := LevelResults.from(session, "meadow-1", "2026-10-03")
	assert_true(r.won)
	assert_eq(r.base_hp_pct, 70)
	assert_eq(r.rounds, 1)
	assert_eq(r.towers_lost, 0)
	assert_false(LevelResults.from(session, "meadow-1", "2026-10-03", true).won, "a quit is never a win")
