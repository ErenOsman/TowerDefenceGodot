extends SceneTree
## Dev script: screenshots every menu screen under Xvfb (the menus agent's proof).
##   ~/godot/run.sh projects/td -s tools/menus_shot.gd [-- <out dir> [only,steps]]
##   ~/godot/run.sh projects/td --resolution 1280x720 -s tools/menus_shot.gd -- user://menus720
## Uses its own save (user://menus_shot.json, deleted first). Steps: welcome, main_menu, credits, settings_audio,
## settings_display, settings_gameplay, settings_controls (+ a capture and a conflict), codex_towers (a page),
## codex_statuses, level_select (an unplayed level: no enemy chips), level_select_played (a won one: chips),
## level_select_locked, hand_editor, camp (after GameApp.complete_chapter1()), camp_tour, chapter_select,
## camp_level_select, camp_open (after Chapter 2: camp_open_tour, camp_open, camp_layout_editor), blacksmith
## (blacksmith_welcome, blacksmith_tour, blacksmith; then Esc back to the Camp), loading, settings_reset (the Reset to defaults confirm). PNGs: <out dir>/menu_<n>_<step>.png.

var out_dir := "user://menus"
var only: PackedStringArray = []
var _n := 0
var flow: Node
var app: Node
var save: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: only = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _want(step: String) -> bool:
	return only.is_empty() or only.has(step)

func _run() -> void:
	save = root.get_node("SaveData")
	flow = root.get_node("SceneFlow")
	app = root.get_node("GameApp")
	save.path = "user://menus_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	# Boot (the shell agent's screen), then Welcome (first launch)
	if _want("boot"):
		change_scene_to_file("res://game/boot.tscn")
		await _frames(15)
		await _shot("boot")
		await _until(func(): return flow.current == flow.Welcome and not flow.is_loading, 20.0)
	else:
		flow.go(flow.Welcome)
	await _until(func(): return flow.current == flow.Welcome and not flow.is_loading, 20.0)
	await _frames(20)
	var welcome = current_scene
	if _want("welcome"):
		welcome.name_edit.text = "Çağrı Şükrü"
		welcome.name_edit.text_changed.emit(welcome.name_edit.text)
		await _frames(2)
		await _shot("welcome")
	welcome.name_edit.text = "Çağrı Şükrü"
	welcome.begin(false)
	await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading, 20.0)
	await _frames(30)
	var menu = current_scene
	if _want("main_menu"): await _shot("main_menu")
	if _want("credits"):
		var c = menu.open_popup("credits")
		await _frames(25)
		await _shot("credits")
		# Esc closes the top popup (Back semantics), and only that one
		var s2 = menu.open_popup("settings")
		await _frames(10)
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE; esc.pressed = true
		Input.parse_input_event(esc)
		await _frames(20)
		print("esc: settings open=", is_instance_valid(s2) and s2.is_open, " credits open=", is_instance_valid(c) and c.is_open)
		Input.parse_input_event(esc)
		await _frames(20)
		print("esc again: credits open=", is_instance_valid(c) and c.is_open, " keys blocked=", root.get_node("KeyBinds").block_keys)
	if _want("settings"):
		var s = menu.open_popup("settings")
		await _frames(25)
		await _shot("menu_settings_open") # the menu list behind stays plain (no hover / focus ring)
		root.get_node("SettingsMgr").set_master_volume(0.0)
		root.get_node("SettingsMgr").set_music_volume(1.0)
		s.refresh_all()
		for i in 4:
			s.show_tab(i)
			await _frames(4)
			await _shot("settings_" + ["audio", "display", "gameplay", "controls"][i])
		# a conflict (Skip on Enter) and a capture in progress
		root.get_node("KeyBinds").set_bind("Skip", 0, KeyCombo.new(KEY_ENTER))
		s.refresh_controls()
		s.listen("Pause", 1)
		await _frames(4)
		await _shot("settings_controls_conflict")
		var ev := InputEventKey.new()
		ev.keycode = KEY_K; ev.pressed = true; ev.shift_pressed = true
		s._input(ev)
		print("captured Pause slot 2: ", root.get_node("KeyBinds").describe("Pause"))
		root.get_node("KeyBinds").reset_all()
		s.close()
		await _frames(15)
	if _want("settings_reset"): # Reset to defaults asks through the shared TdConfirm (2026-10-15)
		var s = menu.open_popup("settings")
		await _frames(10)
		s.show_tab(3)
		var q: TdConfirm = s._on_reset()
		await _frames(25)
		await _shot("settings_reset_confirm")
		q.cancel()
		s.close()
		await _frames(15)
	# some discoveries, so the Codex has pages and new dots
	for id in ["slime", "runner", "big-slime"]: save.codex.discover(CodexSection.Enemies, id)
	for id in ["burn", "shield", "taunted"]: save.codex.discover(CodexSection.Statuses, id)
	root.get_node("SettingsMgr").set_master_volume(0.3)
	save.save()
	if _want("codex") and ResourceLoader.exists("res://game/ui/screens/codex.tscn"):
		var cx = menu.open_popup("codex")
		await _frames(40)
		await _shot("codex_towers")
		# the Guardian's page, scrolled down
		save.codex.discover(CodexSection.Towers, "guardian")
		cx.show_section(CodexSection.Towers)
		for e in cx.entries:
			if e.id == "guardian": cx.select(e)
		await _frames(10)
		cx._page_scroll.scroll_vertical = 100000 # to the end: the passive row (Counter-attack)
		await _frames(6)
		await _shot("codex_guardian_scrolled")
		save.codex.discover(CodexSection.Towers, "priest")
		cx.show_section(CodexSection.Towers)
		for e in cx.entries:
			if e.id == "priest": cx.select(e)
		await _frames(10)
		await _shot("codex_priest")
		cx.show_section(CodexSection.Enemies)
		await _frames(10)
		await _shot("codex_enemies")
		for e in cx.entries:
			if not save.codex.is_discovered(e.section, e.id):
				cx.select(e)
				break
		await _frames(8)
		await _shot("codex_enemy_locked")
		cx.show_section(CodexSection.Statuses)
		await _frames(10)
		await _shot("codex_statuses")
		cx.show_section(CodexSection.Tips)
		await _frames(10)
		await _shot("codex_tips")
		cx.close()
		await _frames(15)
	# level select (before the Camp)
	if ResourceLoader.exists("res://game/ui/screens/level_select.tscn"):
		app.win_first_levels(2)
		menu.refresh()
		app.go_home()
		await _until(func(): return flow.current == flow.LevelSelect and not flow.is_loading, 20.0)
		await _frames(30)
		var ls = current_scene
		if _want("level_select"): await _shot("level_select")  # the cursor is on an unplayed level: no enemy chips yet
		if _want("level_select_played"):
			var played := ""
			for v in ls.visible_rows:
				if played == "" and MenuLogic.has_played(save.progress, v.entry.level_id): played = v.entry.level_id
			if played != "":
				var before: String = ls.selected
				ls.select(played)
				await _frames(8)
				await _shot("level_select_played")
				ls.select(before)
		if _want("level_select_locked"):
			var locked := ""
			for v in ls.visible_rows:
				if not v.unlocked: locked = v.entry.level_id
			if locked != "":
				ls.select(locked)
				await _frames(8)
				await _shot("level_select_locked")
			ls.select(save.progress.last_selected if save.progress.last_selected != "" else ls.selected)
		if _want("hand_editor"):
			var he = ls.open_hand_editor()
			await _frames(30)
			await _shot("hand_editor")
			he.close()
			await _frames(15)
	# the Camp
	if ResourceLoader.exists("res://game/ui/screens/camp.tscn"):
		app.complete_chapter1()
		flow.go(flow.Camp)
		await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 20.0)
		await _frames(40)
		var camp = current_scene
		if _want("camp"): await _shot("camp_welcome")
		camp.close_welcome()
		await _frames(20)
		if _want("camp"): await _shot("camp_tour")
		camp.end_tour()
		await _frames(10)
		if _want("camp"): await _shot("camp")
		if _want("chapter_select"):
			var ch = camp.open_chapters()
			await _frames(30)
			await _shot("chapter_select")
			ch.open_chapter(1)
			await _frames(40)
			await _shot("camp_level_select")
		# after Chapter 2: the Guild and Workshop buttons appear, the mini tour points at them once, the layout editor
		if _want("camp_open"):
			app.complete_chapter2()
			save.save()
			flow.go(flow.Camp)
			await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 20.0)
			await _frames(40)
			camp = current_scene
			await _shot("camp_open_tour")
			camp.end_tour()
			await _frames(10)
			await _shot("camp_open")
			var ed := TdLayoutEditor.new()
			root.add_child(ed)
			ed.start(camp)
			for e in camp.world.entries:
				if e.node == camp.props.get("Guild"): ed.select(e)
			ed.rotate_selected(15.0)
			await _frames(10)
			await _shot("camp_layout_editor")
			ed.stop()
			await _frames(4)
		# the Blacksmith (after Chapter 2): the Camp's Blacksmith station slides to it; the welcome card, the tour,
		# the place; Esc on the bare place slides back to the Camp
		if _want("blacksmith"):
			if not _want("camp_open"):
				app.complete_chapter2()
				save.profile.guild_tour_seen = true
				save.save()
				flow.go(flow.Camp)
				await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 20.0)
				await _frames(30)
				camp = current_scene
			camp.open_blacksmith()
			await _until(func(): return flow.current == flow.Blacksmith and not flow.is_loading, 20.0)
			await _frames(40)
			var bs = current_scene
			await _shot("blacksmith_welcome")
			bs.close_welcome()
			await _frames(30)
			await _shot("blacksmith_tour")
			bs.end_tour()
			await _frames(10)
			await _shot("blacksmith")
			var esc := InputEventKey.new()
			esc.keycode = KEY_ESCAPE; esc.pressed = true
			Input.parse_input_event(esc)
			await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 20.0)
			print("blacksmith esc → scene ", flow.name_of(flow.current))
	# loading
	if _want("loading") and ResourceLoader.exists("res://game/ui/screens/loading.tscn"):
		var lv = app.next_main_level()
		if lv == null: lv = app.catalog.find_level("chapter1-1")
		app.play_level(lv)
		await _until(func(): return flow.current == flow.Loading and not flow.is_loading, 20.0)
		await _frames(3)
		await _shot("loading")
		await _until(func(): return flow.current == flow.Game and not flow.is_loading, 30.0)
		await _frames(2)
		await _shot("loading_level")
	print("MENUS SHOT DONE")
	quit()

func _frames(n: int) -> void:
	for i in n: await process_frame

func _until(cond: Callable, timeout: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > timeout * 1000.0:
			print("TIMEOUT waiting; scene=", current_scene)
			return
		await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/menu_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
