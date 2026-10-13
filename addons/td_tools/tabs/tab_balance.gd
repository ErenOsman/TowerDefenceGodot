@tool
extends "res://addons/td_tools/tabs/tab_base.gd"
## Balance Sheet (BalanceSheet.cs): units (by group, tower cost, every stat), abilities (cooldown, start, range,
## min range, damage, heal as written + the numbers evaluated for the first unit that has it) and statuses
## (duration, max stacks, stacking, shield). Read-only here: the numbers belong to the Unity repo's content.
## Export CSV writes user://balance.csv. A click selects the content file.

var view: OptionButton
var search: LineEdit
var examples: CheckBox
var tree: Tree
## The last "balance" job result.
var sheet := {}

func build() -> void:
	add_child(D.note("Read-only: data/content is a copy of the Unity repo's Content/. Change numbers there (Unity: Tools > Combat > Balance Sheet, or Balance.txt), then Sync from Unity (Validate all tab)."))
	var top := HBoxContainer.new()
	add_child(top)
	view = OptionButton.new()
	for v in ["Units", "Abilities", "Statuses"]: view.add_item(v)
	view.item_selected.connect(func(_i): show_sheet())
	top.add_child(view)
	search = LineEdit.new()
	search.placeholder_text = "Search names"
	search.custom_minimum_size = Vector2(200, 0)
	search.text_changed.connect(func(_t): show_sheet())
	top.add_child(search)
	examples = CheckBox.new()
	examples.text = "Examples"
	examples.tooltip_text = "Also list the demo assets under Examples/."
	examples.toggled.connect(func(_on): fill())
	top.add_child(examples)
	top.add_child(D.label("", true))
	top.add_child(D.button("Export CSV", export_csv, "Writes every section to " + BalanceSheet.CSV_PATH))
	tree = Tree.new()
	tree.hide_root = true
	tree.column_titles_visible = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(func():
		var it := tree.get_selected()
		if it != null and it.get_metadata(0) is String and it.get_metadata(0) != "": dock.call_host("select_file", [it.get_metadata(0)]))
	add_child(tree)

func _matches(r: Dictionary) -> bool:
	return search.text == "" or r.name.containsn(search.text) or r.label.containsn(search.text)

func _columns(titles: Array) -> void:
	tree.clear()
	tree.columns = titles.size()
	for i in titles.size():
		tree.set_column_title(i, titles[i])
		tree.set_column_expand(i, i == 0 or titles[i] in ["numbers", "summary", "damage", "heal", "shield"])
		tree.set_column_custom_minimum_width(i, 180 if i == 0 else 64)
	tree.create_item()

func _row(cells: Array, file: String) -> TreeItem:
	var it := tree.create_item(tree.get_root())
	for i in cells.size():
		var s := str(cells[i])
		it.set_text(i, s if s != "" else "—")
		if s == "": it.set_custom_color(i, Color(1, 1, 1, 0.3))
		it.set_tooltip_text(i, s)
	it.set_metadata(0, dock.content_folder.path_join(file) if file != "" else "")
	return it

## Fetches the sheet (a tools job), then shows it.
func fill() -> void:
	say("Loading the balance sheet…")
	dock.job("balance", {"examples": examples.button_pressed}, func(r: Dictionary):
		sheet = r
		show_sheet())

## Shows the fetched sheet for the current view and search.
func show_sheet() -> void:
	if sheet.has("problem"):
		say("Balance sheet failed: " + str(sheet.problem))
		return
	var n := 0
	match view.selected:
		0:
			var cols: Array = sheet.get("unit_columns", [])
			_columns(["unit", "group", "cost"] + cols)
			for r in sheet.get("units", []):
				if not _matches(r): continue
				var cells := [r.label, r.group, r.cost]
				for c in cols: cells.append(r.stats.get(c, ""))
				_row(cells, r.file)
				n += 1
		1:
			_columns(["ability"] + BalanceSheet.ABILITY_FIELDS + ["owner", "numbers", "summary"])
			for r in sheet.get("abilities", []):
				if not _matches(r): continue
				var cells := [r.label]
				for f in BalanceSheet.ABILITY_FIELDS: cells.append(r.fields[f])
				cells.append_array([r.owner, r.numbers, r.summary])
				_row(cells, r.file)
				n += 1
		2:
			_columns(["status"] + BalanceSheet.STATUS_FIELDS + ["unit", "tags"])
			for r in sheet.get("statuses", []):
				if not _matches(r): continue
				var cells := [r.label]
				for f in BalanceSheet.STATUS_FIELDS: cells.append(r.fields[f])
				cells.append_array([r.unit, r.tags])
				_row(cells, r.file)
				n += 1
	say("%d %s" % [n, view.get_item_text(view.selected).to_lower()])

func export_csv() -> void:
	dock.job("balance_csv", {"path": BalanceSheet.CSV_PATH, "examples": examples.button_pressed}, func(r: Dictionary):
		say(str(r.problem) if str(r.get("problem", "")) != "" else "Wrote " + str(r.get("path", ""))))
