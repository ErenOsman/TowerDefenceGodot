extends TestCase
## The TD Tools editor plugin without the editor: the plugin script compiles and instantiates; the dock its
## _enter_tree builds runs every tab in-process (jobs not external) with a stub host recording the editor calls;
## the playtester's Play writes the DevLaunch request and asks the host to play the Level scene; one job also runs
## through the headless CLI the editor uses. And the runtime F1 panel builds its three tabs.

const SAVE := "user://test_tools_dock_save.json"

class StubHost:
	var calls: Array = []
	func play_scene(path: String) -> void: calls.append(["play_scene", path])
	func select_file(path: String) -> void: calls.append(["select_file", path])
	func open_external(path: String) -> void: calls.append(["open_external", path])
	func rescan() -> void: calls.append(["rescan"])

func teardown() -> void:
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DevLaunch.clear()

func test_plugin_script_compiles() -> void:
	# an EditorPlugin can only be instantiated by the editor (the headless editor run in the report proves
	# _enter_tree); here: it compiles, is an EditorPlugin and has the host API the dock calls
	var script: GDScript = load("res://addons/td_tools/td_tools_plugin.gd")
	assert_not_null(script)
	assert_eq(script.reload(), OK)
	assert_eq(script.get_instance_base_type(), &"EditorPlugin")
	var methods := script.get_script_method_list().map(func(m): return m.name)
	for m in ["_enter_tree", "_exit_tree", "play_scene", "select_file", "open_external", "rescan"]: assert_true(methods.has(m), m)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://addons/td_tools/plugin.cfg"), OK)
	assert_eq(cfg.get_value("plugin", "script"), "td_tools_plugin.gd")
	assert_true(ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()).has("res://addons/td_tools/plugin.cfg"), "enabled in project.godot")

func test_dock_builds_and_runs_every_tab() -> void:
	var host := StubHost.new()
	var dock = load("res://addons/td_tools/td_tools_dock.gd").new()
	dock.external = false
	dock.host = host
	dock.pages[0].path = SAVE
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(dock)
	dock.show_tab(0)
	assert_eq(dock.pages.size(), 5)
	assert_seq(dock.pages.map(func(p): return str(p.name)), ["Persistent data", "Validate all", "Balance sheet", "Level playtester", "Export game reference"])
	# Persistent data: defaults shown, quick actions write the file
	var save = dock.pages[0]
	assert_true(save.text.text.contains("\"settings\""), "text: " + save.text.text.left(80))
	save.name_edit.text = "Tester"
	save.quick("set_name", "Tester")
	save.quick("grant_towers")
	assert_eq(SaveTools.load_data(SAVE).profile.player_name, "Tester")
	assert_true(SaveTools.load_data(SAVE).towers.towers.size() > 0, "towers granted")
	assert_true(save.status.text.contains("tower"), "save: " + save.status.text)
	save.text.text = "{ broken"
	save.save_text()
	assert_true(save.status.text.begins_with("Not saved"), save.status.text)
	save.reset()
	assert_false(SaveTools.load_data(SAVE).profile.created)
	# Validate all
	dock.show_tab(1)
	assert_true(dock.pages[1].status.text.contains("no problems"), dock.pages[1].status.text)
	# Balance sheet: three views
	dock.show_tab(2)
	var bal = dock.pages[2]
	assert_true(bal.tree.get_root() != null, "balance: " + bal.status.text)
	assert_eq(bal.tree.get_root().get_child_count(), BalanceSheet.unit_rows(ContentLibrary.load()).size())
	bal.view.select(1); bal.show_sheet()
	assert_true(bal.status.text.ends_with("abilities"), bal.status.text)
	bal.search.text = "Shoot"; bal.show_sheet()
	assert_eq(bal.tree.get_root().get_child_count(), 1)
	bal.tree.get_root().get_child(0).select(0)
	assert_eq(host.calls.back(), ["select_file", "res://data/content/Abilities.json"])
	# Level playtester: Play writes the request and asks the host to play the Level scene
	dock.show_tab(3)
	var pt = dock.pages[3]
	assert_true(pt.levels.size() >= 11, str(pt.levels.size()))
	var at: int = pt.levels.map(func(l): return l.id).find("chapter1-2")
	pt.level_pick.select(at)
	pt.hand_list.select(0, false)
	pt.hand_list.select(2, false)
	pt.seed_spin.value = 42
	pt.instant.button_pressed = true
	pt.play_level()
	assert_eq(host.calls.back(), ["play_scene", "res://game/level/level.tscn"])
	var req = DevLaunch.take()
	assert_eq(req.level_id, "chapter1-2")
	assert_seq(req.hand, [pt.towers[0].id, pt.towers[2].id])
	assert_eq(int(req.seed), 42)
	assert_eq(req.instant, true)
	# Export game reference: preview filled
	dock.show_tab(4)
	assert_eq(dock.pages[4].pages.size(), 6)
	assert_true(dock.pages[4].preview.text.contains("# Towers"), "preview: " + dock.pages[4].preview.text.left(200))
	dock.free()

func test_job_through_the_headless_cli() -> void:
	var r: Dictionary = load("res://addons/td_tools/jobs.gd").run_external("levels", {})
	assert_false(r.has("problem"), str(r.get("problem", "")))
	assert_true(r.get("levels", []).size() >= 11)
	assert_eq(int(r.get("assets", 0)), ContentLibrary.load().all.size())

func test_dev_panel_builds() -> void:
	var panel := TdDevPanel.new()
	assert_eq(panel.tabs.get_tab_count(), 3)
	assert_seq([panel.tabs.get_tab_title(0), panel.tabs.get_tab_title(1), panel.tabs.get_tab_title(2)], ["Save", "Shortcuts", "Log"])
	assert_eq(panel.layer, 120)
	var log := DevLog.new()
	for i in DevLog.LIMIT + 5: log.add("line %d" % i)
	assert_eq(log.lines().size(), DevLog.LIMIT)
	assert_eq(log.lines()[0], "line 5")
	log._log_error("f", "res://x.gd", 3, "code", "why", false, 0, [])
	assert_eq(log.lines()[-1], "ERROR: why  (x.gd:3 f)")
	panel.free()
