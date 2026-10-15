@tool
extends "res://addons/td_tools/tabs/tab_base.gd"
## Export Game Reference (GameReference.cs, Tools > Docs > Export Game Reference): writes README, Towers, Enemies,
## Statuses, Levels and Codex .md from the loaded content to docs/reference/ (same layout as the Unity repo's
## Docs/Reference/), with a preview, and compares the pages with the Unity repo's when it is there.

var folder_edit: LineEdit
var page_pick: OptionButton
var preview: TextEdit
var pages := {}

func build() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	top.add_child(D.label("Folder"))
	folder_edit = LineEdit.new()
	folder_edit.text = GameReference.Folder
	folder_edit.custom_minimum_size = Vector2(260, 0)
	top.add_child(folder_edit)
	top.add_child(D.button("Export", export_pages, "Writes the pages (deterministic: an unchanged game gives no diff)."))
	top.add_child(D.button("Compare with Unity", compare, "Diffs the pages against <Unity repo>/Docs/Reference/*.md."))
	top.add_child(D.label("", true))
	top.add_child(D.label("Preview"))
	page_pick = OptionButton.new()
	page_pick.item_selected.connect(func(_i): _show_page())
	top.add_child(page_pick)
	preview = TextEdit.new()
	preview.editable = false
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(preview)

## Builds the pages (a tools job) for the preview.
func fill() -> void:
	say("Building the pages…")
	dock.job("reference", {}, func(r: Dictionary):
		pages = r.get("pages", {})
		var keep := page_pick.get_item_text(page_pick.selected) if page_pick.selected >= 0 else "Towers.md"
		page_pick.clear()
		for p in pages: page_pick.add_item(p)
		page_pick.select(maxi(0, pages.keys().find(keep)))
		_show_page()
		say(str(r.problem) if r.has("problem") else ("%d pages ready." % pages.size() if not pages.is_empty() else "No game catalog in the content.")))

func _show_page() -> void:
	var i := page_pick.selected
	preview.text = pages[pages.keys()[i]] if i >= 0 and i < pages.size() else ""

func export_pages() -> void:
	var out := folder_edit.text
	dock.job("reference_export", {"out": out}, func(r: Dictionary):
		if str(r.get("problem", "")) != "":
			say("Export failed: " + str(r.problem))
			return
		if out.begins_with("res://"): dock.call_host("rescan")
		say("Wrote the pages to " + str(r.get("path", out))))

func compare() -> void:
	var home := OS.get_environment("HOME")
	if home == "": home = OS.get_environment("USERPROFILE")
	var unity := home.path_join("game/Docs/Reference") # the frozen Unity repo (read-only), when it is there
	if not DirAccess.dir_exists_absolute(unity):
		say("No Unity reference at " + unity)
		return
	var same := PackedStringArray()
	var differ := PackedStringArray()
	for p in pages:
		var theirs := unity.path_join(p)
		if FileAccess.file_exists(theirs) and FileAccess.get_file_as_string(theirs) == pages[p]: same.append(p)
		else: differ.append(p)
	say("Same as Unity: %s%s" % [", ".join(same) if not same.is_empty() else "none", (" · differ: " + ", ".join(differ)) if not differ.is_empty() else ""])

