extends TestCase
## Export Game Reference (game/dev/game_reference.gd) on the real content: the Unity GameReference page layout,
## numbers through the converter, deterministic output; and byte-identical to the Unity repo's
## Docs/Reference/*.md when ~/game has the same content JSON as data/content.

static var _lib: ContentLibrary
static var _pages: Dictionary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib

func pages() -> Dictionary:
	if _pages.is_empty(): _pages = GameReference.pages(lib())
	return _pages

func test_six_pages_with_the_header() -> void:
	assert_seq(pages().keys(), ["README.md", "Towers.md", "Enemies.md", "Statuses.md", "Levels.md", "Codex.md"])
	for p in pages():
		var text: String = pages()[p]
		assert_true(text.begins_with(GameReference.Header + "\n\n# "), p)
		assert_true(text.ends_with("\n") and not text.ends_with("\n\n"), p + " ends with one newline")
		assert_false(text.contains("\r"), p)

func test_towers_page() -> void:
	var t: String = pages()["Towers.md"]
	assert_text(t, "| Tower | Cost | HP | Speed |")
	assert_text(t, "| [Archer](#archer) | 100 | 20 | 2 |")
	assert_text(t, "starting tower |")
	assert_text(t, "Cost **100** energy · type ID `archer`")
	assert_text(t, "<sub>Source: `Assets/Data/Towers/Archer Tower.asset` (`Content/Towers.json` → `Towers/Archer Tower`)")
	assert_text(t, "Stats: HP 20 · Speed 2 · Range 2 · Power 10")
	assert_text(t, "1. **Shoot** _(Attack, Projectile)_: Shoots an arrow for 10 at an enemy up to 2 tiles away.\n   Range 2 · Damage 10 · Cooldown 1")
	var sections := 0
	for line in t.split("\n"):
		if line.begins_with("## "): sections += 1
	assert_eq(sections, lib().catalog.tower_types.size(), "one section per tower type")

func test_enemies_statuses_codex() -> void:
	var e: String = pages()["Enemies.md"]
	assert_text(e, "| Enemy | HP | Speed |")
	assert_text(e, "Abilities, in the order it tries them:")
	assert_text(e, "Appears in: ")
	var s: String = pages()["Statuses.md"]
	assert_text(s, "## Acid\n\nTakes *stacks* damage at the start of each of its turns.\n\nlasts 3 turns · stacking: Stack (up to 99) · tags: Debuff, Poison\n\nID `acid`")
	assert_no_text(s, "## Rooted", "example statuses no tower or enemy uses are left out")
	var c: String = pages()["Codex.md"]
	assert_text(c, "## Towers (%d)" % lib().catalog.codex.towers.size())
	assert_text(c, "1. Archer (100 energy)")
	assert_text(c, "## Tips (")

func test_levels_page_maps_and_waves() -> void:
	var l: String = pages()["Levels.md"]
	assert_text(l, "## Tutorial\n\n### First Defence")
	assert_text(l, "- Hand: its own: Archer · map 7×5 · 1 road · 2 waves")
	assert_text(l, "### 1. First Steps")
	assert_text(l, " 2 S 1 1 1 1 1 B\n")
	assert_text(l, "| Wave round | What comes | Road |")
	var maps := l.count("```text")
	assert_eq(maps, lib().catalog.entries().size() + 1, "a map per catalog level + the tutorial")
	assert_eq(l.count("```") , maps * 2)

func test_deterministic() -> void:
	var again := GameReference.pages(lib())
	for p in again: assert_eq(again[p], pages()[p], p)

func test_helpers() -> void:
	assert_eq(GameReference.anchor("The Slime King"), "the-slime-king")
	assert_eq(GameReference.anchor("Çağrı's Tower-2"), "çağrıs-tower-2")
	assert_eq(GameReference.words("EndRound"), "End round")
	assert_eq(GameReference.tip_text("Press {key:EndRound}, {click:Select}."), "Press *End round key*, *Select click*.")
	assert_eq(GameReference.status_text("{stacks} / {STACKS * 5} / { turns }"), "*stacks* / *5 × stacks* / *turns left*")
	assert_eq(GameReference.cell("a|b\nc"), "a\\|b c")
	assert_eq(GameReference.stat_label("MaxHp"), "HP")
	assert_eq(GameReference.preset_text(InstinctPreset.MostHurt), "most hurt")
	assert_eq(GameReference.preset_text(InstinctPreset.Nearest), "nearest")

func test_export_writes_files() -> void:
	var dir := "user://test_tools_reference"
	assert_eq(GameReference.export(dir, lib()), "")
	for p in pages():
		assert_eq(FileAccess.get_file_as_string(dir.path_join(p)), pages()[p], p)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(p)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

func test_same_as_unity_when_content_matches() -> void:
	var unity := OS.get_environment("HOME").path_join("game")
	if not DirAccess.dir_exists_absolute(unity.path_join("Docs/Reference")): return # no Unity repo here
	for f in DirAccess.get_files_at("res://data/content"):
		if not f.ends_with(".json"): continue
		var theirs := unity.path_join("Content").path_join(f)
		if not FileAccess.file_exists(theirs) or FileAccess.get_file_as_string(theirs) != FileAccess.get_file_as_string("res://data/content/" + f):
			return # content differs (not synced): the pages may differ too
	for p in pages():
		var theirs := unity.path_join("Docs/Reference").path_join(p)
		assert_eq(pages()[p], FileAccess.get_file_as_string(theirs), "%s differs from the Unity export" % p)

func assert_text(text: String, part: String, msg := "") -> void:
	assert_true(text.contains(part), "%s missing: %s" % [msg, part.c_escape()])

func assert_no_text(text: String, part: String, msg := "") -> void:
	assert_false(text.contains(part), "%s unexpected: %s" % [msg, part.c_escape()])
