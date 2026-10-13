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
