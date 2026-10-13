@tool
extends "res://addons/td_tools/tabs/tab_base.gd"
## Validate All (ContentCheck, Tools > Combat > Validate All) on data/content: one row per finding. A click selects
## the JSON file in the FileSystem dock and copies the entry key (shown with its line); a double click opens the
## file outside. "Sync from Unity" runs tools/sync_from_unity.sh with the Unity repo path when that folder exists,
## then reloads the content and validates again.

const SYNC_SCRIPT := "res://tools/sync_from_unity.sh"

var tree: Tree
var errors_only: CheckBox
var unity_edit: LineEdit
var sync_button: Button
var output: TextEdit
var rows: Array = []

func build() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	top.add_child(D.button("Validate all", run, "ContentCheck on every asset in data/content."))
	errors_only = CheckBox.new()
	errors_only.text = "Errors only"
	errors_only.toggled.connect(func(_on): show_rows())
	top.add_child(errors_only)
	top.add_child(D.label("", true))
	top.add_child(D.label("Unity repo:"))
	unity_edit = LineEdit.new()
	unity_edit.text = default_unity_path()
	unity_edit.custom_minimum_size = Vector2(260, 0)
	unity_edit.text_changed.connect(func(_t): _update_sync())
	top.add_child(unity_edit)
	sync_button = D.button("Sync from Unity", sync, "tools/sync_from_unity.sh: copies Content/*.json and the design docs.")
	top.add_child(sync_button)

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
	output = TextEdit.new()
	output.editable = false
	output.custom_minimum_size = Vector2(0, 60)
	output.visible = false
	split.add_child(output)

static func default_unity_path() -> String:
	var home := OS.get_environment("HOME")
	if home == "": home = OS.get_environment("USERPROFILE")
	return home.path_join("game")

func fill() -> void:
	_update_sync()
	run()

func _update_sync() -> void:
	var ok := DirAccess.dir_exists_absolute(unity_edit.text.path_join("Content"))
	sync_button.disabled = not ok
	sync_button.tooltip_text = "Runs tools/sync_from_unity.sh %s" % unity_edit.text if ok else "No Unity repo (Content/) at that path."

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

## Runs the sync script, shows its output, reloads the content and validates again.
func sync() -> void:
	var script := ProjectSettings.globalize_path(SYNC_SCRIPT)
	var out := []
	var code := OS.execute("bash", [script, unity_edit.text], out, true)
	output.visible = true
	output.text = "".join(out)
	dock.call_host("rescan")
	say("Sync from Unity finished (exit %d); validating again…" % code)
	dock.reload_content()
