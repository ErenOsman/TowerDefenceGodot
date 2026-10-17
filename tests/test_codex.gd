extends TestCase
## Port of CodexTests.cs.

func test_discovery_is_once_and_new_until_viewed_tips_always_known() -> void:
	var codex := CodexProgress.new()
	assert_false(codex.is_discovered(CodexSection.Enemies, "slime"))
	assert_true(codex.discover(CodexSection.Enemies, "slime"))
	assert_false(codex.discover(CodexSection.Enemies, "slime"), "a second discovery changes nothing (nothing to save)")
	assert_true(codex.is_discovered(CodexSection.Enemies, "slime"))
	assert_false(codex.is_discovered(CodexSection.Statuses, "slime"), "keys are per section")

	assert_true(codex.is_new(CodexSection.Enemies, "slime"))
	assert_true(codex.mark_viewed(CodexSection.Enemies, "slime"))
	assert_false(codex.is_new(CodexSection.Enemies, "slime"))
	assert_false(codex.mark_viewed(CodexSection.Enemies, "slime"))
	assert_false(codex.mark_viewed(CodexSection.Towers, "archer"), "an undiscovered entry is never marked seen")

	assert_true(codex.is_discovered(CodexSection.Tips, "rounds"))
	assert_false(codex.is_new(CodexSection.Tips, "rounds"))
	assert_false(codex.discover(CodexSection.Towers, ""), "an empty id is ignored")
	assert_eq(CodexProgress.key(CodexSection.Enemies, "slime"), "Enemies:slime")

# ------------------------------------------------------------------ towers are locked like enemies (Eren 2026-10-17)

func _tower(id: String, name: String) -> TowerAsset:
	var t := TowerAsset.new(); t.id = id; t.display_name = name
	return t

func test_undiscovered_towers_are_listed_locked_like_enemies() -> void:
	var codex := CodexAsset.new()
	codex.towers = [_tower("archer", "Archer"), _tower("guardian", "Guardian"), _tower("mage", "Mage")]
	var progress := CodexProgress.new()
	progress.discover(CodexSection.Towers, "guardian")
	var list := MenuLogic.codex_list(codex, CodexSection.Towers, progress)
	assert_eq(list.size(), 3, "every tower is listed, met or not")
	assert_seq(list.map(func(e): return e.known), [false, true, false])
	assert_seq(list.map(func(e): return e.shown_name), ["Not found yet", "Guardian", "Not found yet"], "no name before it is discovered")
	assert_eq(MenuLogic.codex_known_count(list), 1)
	assert_eq(MenuLogic.codex_progress_text(CodexSection.Towers, MenuLogic.codex_known_count(list), list.size()), "1 / 3 discovered")
	assert_eq(MenuLogic.locked_title(CodexSection.Towers), "Not found yet")
	assert_eq(MenuLogic.locked_title(CodexSection.Enemies), "Not met yet", "enemies keep their wording")
	assert_eq(MenuLogic.locked_text(CodexSection.Towers), "", "no explanation under the locked card (Eren 2026-10-17)")

func test_owned_towers_are_discovered_starting_ones_not_news() -> void:
	var catalog := GameCatalogAsset.new()
	var archer := _tower("archer", "Archer")
	catalog.starting_towers = [archer]
	var towers := TowerCollection.new()
	towers.add("archer")
	towers.add("mage")
	towers.add("mage")
	var progress := CodexProgress.new()
	assert_true(MenuLogic.discover_owned(progress, towers, catalog))
	assert_true(progress.is_discovered(CodexSection.Towers, "archer"))
	assert_true(progress.is_discovered(CodexSection.Towers, "mage"))
	assert_false(progress.is_discovered(CodexSection.Towers, "guardian"), "a tower never owned nor shown stays locked")
	assert_false(progress.is_new(CodexSection.Towers, "archer"), "a starting tower is not news")
	assert_true(progress.is_new(CodexSection.Towers, "mage"), "a tower earned later gets the New dot")
	assert_false(MenuLogic.discover_owned(progress, towers, catalog), "nothing new the second time (nothing to save)")
