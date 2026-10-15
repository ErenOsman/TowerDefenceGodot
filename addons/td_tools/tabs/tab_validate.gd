@tool
extends "res://addons/td_tools/tabs/tab_base.gd"
## Validate All (ContentCheck, Tools > Combat > Validate All) on data/content: one row per finding. A click selects
## the JSON file in the FileSystem dock and copies the entry key (shown with its line); a double click opens the
## file outside. data/content is the source of truth (docs/Content.md); there is nothing to sync from.

var tree: Tree
var errors_only: CheckBox
var rows: Array = []

func build() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	top.add_child(D.button("Validate all", run, "ContentCheck on every asset in data/content."))
	errors_only = CheckBox.new()
	errors_only.text = "Errors only"
	errors_only.toggled.connect(func(_on): show_rows())
	top.add_child(errors_only)

	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	tree = Tree.new()
	tree.columns = 4
	tree.column_titles_visible = true
	for i in 4: tree.set_column_title(i, ["", "Message", "File", "Key"][i])
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 70)
	tree.set_column_expand_ratio(1, 4)
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_on_selected)
	tree.item_activated.connect(_on_activated)
	split.add_child(tree)

func fill() -> void:
	run()

## Validates data/content (a tools job) and lists the findings.
func run() -> void:
	var t := Time.get_ticks_msec()
	say("Validating…")
	dock.job("validate", {}, func(r: Dictionary):
		rows = r.get("rows", [])
		show_rows()
		if r.has("problem"): say("Validate All failed: " + str(r.problem))
		elif rows.is_empty(): say("Validate All: no problems (%d assets, %d ms)." % [int(r.get("assets", 0)), Time.get_ticks_msec() - t])
		else: say("Validate All: %s (%d assets, %d ms)." % [r.counts, int(r.get("assets", 0)), Time.get_ticks_msec() - t]))

func show_rows() -> void:
	tree.clear()
	var root := tree.create_item()
	for r in rows:
		if errors_only.button_pressed and not r.error: continue
		var item := tree.create_item(root)
		item.set_text(0, "ERROR" if r.error else "warn")
		item.set_custom_color(0, Color(1, 0.45, 0.4) if r.error else Color(1, 0.8, 0.4))
		item.set_text(1, r.message)
		item.set_tooltip_text(1, r.message)
		item.set_text(2, r.file + (":%d" % int(r.line) if int(r.line) > 0 else ""))
		item.set_text(3, r.key)
		item.set_metadata(0, r)

func _on_selected() -> void:
	var item := tree.get_selected()
	if item == null: return
	var r: Dictionary = item.get_metadata(0)
	if r.path != "": dock.call_host("select_file", [r.path])
	if r.key != "": DisplayServer.clipboard_set(r.key)
	say("%s line %d · key \"%s\" copied" % [r.path, int(r.line), r.key] if r.key != "" else r.message)

func _on_activated() -> void:
	var item := tree.get_selected()
	if item == null: return
	var r: Dictionary = item.get_metadata(0)
	if r.path == "": return
	if not dock.call_host("open_external", [r.path]): OS.shell_open(ProjectSettings.globalize_path(r.path))
