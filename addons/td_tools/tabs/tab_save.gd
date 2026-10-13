@tool
extends "res://addons/td_tools/tabs/tab_base.gd"
## Persistent data (PersistentDataViewer.cs): the save file as a tree and as editable JSON text; Save (checked,
## normalised through GameData), Reload, Reset (confirm), Open folder, and the quick actions (SaveTools) applied
## to the file. The running game keeps its own copy in memory: change the save while it is stopped, or use the
## in-game F1 panel.

var path := SaveTools.PATH
var path_label: Label
var tree: Tree
var text: TextEdit
var name_edit: LineEdit
var count_spin: SpinBox
var confirm: ConfirmationDialog

func build() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	path_label = D.label("", true)
	top.add_child(path_label)
	top.add_child(D.button("Save", save_text, "Check the JSON and write it (normalised through GameData)."))
	top.add_child(D.button("Reload", fill, "Read the file again."))
	top.add_child(D.button("Reset…", func(): confirm.popup_centered(), "Every field back to its defaults."))
	top.add_child(D.button("Open folder", open_folder))

	var actions := HBoxContainer.new()
	add_child(actions)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Player name"
	name_edit.custom_minimum_size = Vector2(160, 0)
	actions.add_child(name_edit)
	actions.add_child(D.button("Set name", func(): quick("set_name", name_edit.text)))
	for a in SaveTools.ACTIONS:
		var id: String = a[0]
		if id == "win_first":
			count_spin = SpinBox.new()
			count_spin.min_value = 1
			count_spin.max_value = 99
			count_spin.value = 8
			actions.add_child(D.button("Win first", func(): quick("win_first", int(count_spin.value)), "Wins the first N main-chapter levels (with rewards)."))
			actions.add_child(count_spin)
		else:
			actions.add_child(D.button(a[1], func(): quick(id)))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	tree = Tree.new()
	tree.columns = 2
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(320, 0)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.set_column_expand_ratio(0, 1)
	tree.set_column_expand_ratio(1, 2)
	split.add_child(tree)
	text = TextEdit.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_stretch_ratio = 1.4
	split.add_child(text)

	confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Reset the save to defaults? (A new player: the Welcome screen shows on the next start.)"
	confirm.confirmed.connect(reset)
	add_child(confirm)

func fill() -> void:
	path_label.text = ProjectSettings.globalize_path(path) + ("" if FileAccess.file_exists(path) else "  (no save yet: defaults)")
	var data := SaveTools.load_data(path)
	text.text = SaveTools.read_text(path) if FileAccess.file_exists(path) else data.to_json()
	if name_edit.text == "": name_edit.text = data.profile.player_name
	show_tree(data.to_dict())
	say(SaveTools.summary(data))

## The tree view of a save Dictionary.
func show_tree(d: Dictionary) -> void:
	tree.clear()
	var root := tree.create_item()
	_add(root, "save", d)
	for c in root.get_children(): c.collapsed = false

func _add(parent: TreeItem, key: String, v) -> void:
	var item := tree.create_item(parent)
	item.set_text(0, key)
	if v is Dictionary:
		item.set_text(1, "{%d}" % v.size())
		for k in v: _add(item, str(k), v[k])
		item.collapsed = parent != tree.get_root()
	elif v is Array:
		item.set_text(1, "[%d]" % v.size())
		for i in v.size(): _add(item, str(i), v[i])
		item.collapsed = true
	else:
		item.set_text(1, JSON.stringify(v))

func save_text() -> void:
	var problem := SaveTools.write_text(path, text.text)
	if problem != "":
		say("Not saved: " + problem)
		return
	fill()
	say("Saved " + path)

func reset() -> void:
	var problem := SaveTools.write_data(path, GameData.new())
	fill()
	say(problem if problem != "" else "Save reset to defaults.")

func open_folder() -> void:
	var dir := ProjectSettings.globalize_path(path).get_base_dir()
	if not dock.call_host("open_external", [dir]): OS.shell_open(dir)

## Runs a quick action on the file (a tools job: it needs the catalog), then refreshes.
func quick(action: String, arg = null) -> void:
	say("Running %s…" % action)
	dock.job("save_action", {"path": path, "action": action, "arg": arg}, func(r: Dictionary):
		fill()
		say(str(r.problem) if str(r.get("problem", "")) != "" else "%s  (%s)" % [r.get("line", ""), r.get("summary", "")]))
