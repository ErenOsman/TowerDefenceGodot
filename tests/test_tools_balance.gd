extends TestCase
## Balance Sheet rows (game/dev/balance_sheet.gd) on the real content, and the CSV.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib

func _find(rows: Array, n: String) -> Dictionary:
	for r in rows:
		if r.name == n: return r
	return {}

func test_unit_rows() -> void:
	var cols := BalanceSheet.unit_columns(lib())
	assert_seq(cols.slice(0, BalanceSheet.STATS.size()), BalanceSheet.STATS)
	var rows := BalanceSheet.unit_rows(lib())
	var archer := _find(rows, "Archer")
	assert_eq(archer.group, "Towers")
	assert_eq(archer.cost, "100")
	assert_eq(archer.stats["MaxHp"], "20")
	assert_eq(archer.stats["Radius"], "")
	assert_eq(archer.file, "Units.json")
	var rabbit := _find(rows, "Rabbit")
	assert_eq(rabbit.group, "Enemies")
	assert_eq(rabbit.cost, "")
	# grouped in order: Towers, Enemies, Bases, Other
	var last := -1
	for r in rows:
		var g := BalanceSheet.GROUPS.find(r.group)
		assert_true(g >= last, "%s out of group order" % r.name)
		last = g
	var towers := rows.filter(func(r): return r.group == "Towers")
	assert_eq(towers.size(), lib().all_of("TowerAsset").size())

func test_examples_hidden_by_default() -> void:
	for r in BalanceSheet.unit_rows(lib()) + BalanceSheet.ability_rows(lib()) + BalanceSheet.status_rows(lib()):
		assert_false(r.key.contains("/Example/"), r.key)
	assert_true(BalanceSheet.status_rows(lib(), true).size() > BalanceSheet.status_rows(lib()).size())

func test_ability_rows() -> void:
	var shoot := _find(BalanceSheet.ability_rows(lib()), "Shoot")
	assert_eq(shoot.fields["cooldown"], "1")
	assert_eq(shoot.fields["range"], "Self.Range")
	assert_eq(shoot.owner, "Archer")
	assert_text(shoot.numbers, "10 Damage")
	assert_text(shoot.numbers, "2 Range")
	assert_eq(shoot.summary, "Range 2 · Damage 10 · Cooldown 1")

func test_status_rows() -> void:
	var acid := _find(BalanceSheet.status_rows(lib()), "Acid")
	assert_eq(acid.fields["duration"], "3")
	assert_eq(acid.fields["maxStacks"], "99")
	assert_eq(acid.fields["stacking"], "Stack")
	assert_eq(acid.unit, "Turns")
	assert_eq(acid.tags, "Debuff, Poison")

func test_csv() -> void:
	assert_eq(BalanceSheet.csv_cell("a,b"), "\"a,b\"")
	assert_eq(BalanceSheet.csv_cell("say \"hi\""), "\"say \"\"hi\"\"\"")
	var csv := BalanceSheet.to_csv(lib())
	var lines := csv.split("\n")
	var n := BalanceSheet.unit_rows(lib()).size() + BalanceSheet.ability_rows(lib()).size() + BalanceSheet.status_rows(lib()).size()
	assert_eq(lines.size(), n + 3 + 2 + 1, "rows + 3 headers + 2 blank lines + the final newline")
	assert_true(lines[0].begins_with("section,group,name,key,cost,MaxHp,Speed"))
	assert_text(csv, "\nUnits,Towers,Archer,Unit/Tower/Archer,100,20,2,")
	var path := "user://test_tools_balance.csv"
	assert_eq(BalanceSheet.export_csv(lib(), path), "")
	assert_eq(FileAccess.get_file_as_string(path), csv)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func assert_text(text: String, part: String, msg := "") -> void:
	assert_true(text.contains(part), "%s missing: %s" % [msg, part.c_escape()])

func assert_no_text(text: String, part: String, msg := "") -> void:
	assert_false(text.contains(part), "%s unexpected: %s" % [msg, part.c_escape()])
