extends SceneTree
## QA tour of the menu screens (boot, welcome, main menu, credits, settings, codex, level select, hand editor, camp,
## chapter select, camp level select, loading) through the real flow with real pointer and key events:
##   GODOT_TIMEOUT=3000 ~/godot/run.sh /home/ubuntu/godot/projects/td [--resolution 1280x720] -s tools/qa/menus_tour.gd -- <out dir> [sections]
## sections (comma list, default all): boot,welcome,main_menu,credits,settings,codex,level_select,hand_editor,
##   credits_secret,camp_locked,chapter_select,camp_open,loading
## For every visible clickable (TdButton, BaseButton, LineEdit, Slider, any STOP control with input / a tooltip) in the
## top layer: the pointer moves onto it (InputEventMouseMotion), waits (tooltips: their delay), then a left press +
## release, then the pointer leaves; Esc (up to 3 times) brings back the state before the click, or the section's
## re-navigation does when the click left the screen. Destructive buttons are skipped (listed in the output).
## Checks after every hover and click: (a) engine/script errors and warnings (a Logger), (b) a drawn control (with
## its 9-slice outset) cut by a clipping ancestor or the screen edge, (c) text wider than its box / truncated / wrapped
## text cut / rich text overflow / text under 18 px, windows grown past their set size, (d) text overlapping text and
## clickables overlapping clickables, (e) tooltips and popups partly off the screen, (f) hover / tooltip / scale stuck
## after the pointer leaves, (g) a click whose layer Esc cannot close.
## Out: <out dir>/NNN_<screen>_<what>.jpg and <out dir>/findings.json (+ a summary on stdout).
## The renderer runs only for screenshots (RenderingServer.render_loop_enabled), so the rest of the tour is fast.

const SAVE := "user://qa_menus_tour.json"
const NEUTRAL := Vector2(6, 6)
const ALL := ["boot", "welcome", "main_menu", "credits", "settings", "codex", "level_select", "hand_editor",
	"credits_secret", "camp_locked", "chapter_select", "camp_open", "loading"]

var out_dir := "user://qa_menus"
var only: PackedStringArray = []
var flow: Node
var app: Node
var save: Node
var kb: Node
var qlog: QaLog
var findings := {}
var order: Array = []
var skipped: Array = []
var cur := ""
var _n := 0
var _mouse := Vector2.ZERO
var _t0 := 0
var _popup_closed := false
var _render_keep := false

class QaLog extends Logger:
	var lines: Array = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var where := "%s:%d" % [file, line]
		if not script_backtraces.is_empty() and script_backtraces[0].get_frame_count() > 0:
			where = "%s:%d (%s)" % [script_backtraces[0].get_frame_file(0), script_backtraces[0].get_frame_line(0), script_backtraces[0].get_frame_function(0)]
		var kind := "WARNING" if error_type == 1 else ("SCRIPT ERROR" if error_type == 2 else "ERROR")
		mutex.lock()
		lines.append([kind, (code + " " + rationale).strip_edges(), where])
		mutex.unlock()
	func _log_message(message: String, error: bool) -> void:
		if not error: return
		mutex.lock()
		lines.append(["STDERR", message.strip_edges(), ""])
		mutex.unlock()
	func take() -> Array:
		mutex.lock()
		var out := lines.duplicate()
		lines.clear()
		mutex.unlock()
		return out

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1 and args[1] != "": only = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	qlog = QaLog.new()
	OS.add_logger(qlog)
	_run.call_deferred()

func _want(s: String) -> bool:
	return only.is_empty() or only.has(s)

# ================================================================== run

func _run() -> void:
	_t0 = Time.get_ticks_msec()
	save = root.get_node("SaveData")
	flow = root.get_node("SceneFlow")
	app = root.get_node("GameApp")
	kb = root.get_node("KeyBinds")
	save.path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	save.load_data()
	app.ensure_loaded()
	Engine.max_fps = 60
	RenderingServer.render_loop_enabled = false
	print("QA viewport ", root.get_visible_rect().size, " window ", root.size)
	await _sec_boot_welcome()
	await _to_main_menu()
	if _want("main_menu"): await _sec_main_menu()
	if _want("credits"): await _sec_credits()
	if _want("settings"): await _sec_settings()
	if _want("codex"): await _sec_codex()
	if _want("level_select") or _want("hand_editor"):
		app.win_first_levels(2)
		await _to_level_select()
		if _want("level_select"): await _sec_level_select()
		if _want("hand_editor"): await _sec_hand_editor()
	if _want("credits_secret"): await _sec_credits_secret()
	if _want("camp_locked") or _want("chapter_select") or _want("camp_open") or _want("loading"):
		app.complete_chapter1()
		save.profile.camp_seen = false
		save.save()
		if _want("camp_locked"): await _sec_camp_locked()
		if _want("chapter_select"): await _sec_chapter_select()
		if _want("camp_open") or _want("loading"):
			app.complete_chapter2()
			if _want("camp_open"): await _sec_camp_open()
			if _want("loading"): await _sec_loading()
	_write()
	print("QA TOUR DONE in %d s" % ((Time.get_ticks_msec() - _t0) / 1000))
	quit()

# ================================================================== sections

func _sec_boot_welcome() -> void:
	cur = "boot"
	if _want("boot"):
		# the boot screen pre-warms shaders on rendered frames: the renderer stays on for it
		RenderingServer.render_loop_enabled = true
		change_scene_to_file("res://game/boot.tscn")
		await _frames(8)
		await _shot("boot")
		RenderingServer.render_loop_enabled = true
		_inspect("boot")
		await _until(func(): return flow.current == flow.Welcome and not flow.is_loading, 240.0)
		RenderingServer.render_loop_enabled = false
	else:
		flow.go(flow.Welcome)
	await _until(func(): return flow.current == flow.Welcome and not flow.is_loading, 60.0)
	await _wait(0.8)
	cur = "welcome"
	var w = current_scene
	if _want("welcome"):
		await _shot("open")
		_inspect("open")
		# a name typed with the keyboard (Turkish letters, longer than the limit)
		await _press(w.name_edit)
		await _type("Çağrı Şükrü Öztürkoğlu")
		await _frames(4)
		if w.name_edit.text.length() > PlayerProfile.MaxNameLength:
			_find("logic", w.name_edit, "the name field takes %d characters (max %d)" % [w.name_edit.text.length(), PlayerProfile.MaxNameLength])
		var n := _inspect("typed a long name")
		_attach(n, await _shot("typed_name"))
		await _sweep({"root": func(): return current_scene,
			"skip": func(c):
				if not is_instance_valid(w): return ""
				if c == w.start_button: return "Start plays the tutorial level (the level load is covered by the loading section)"
				if c == w.skip_button: return "used afterwards to reach the main menu"
				return ""})
		await _hover(w.start_button)
		await _shot("hover_start")
		await _hover(w.skip_button)
		await _shot("hover_skip")
		await _press(w.skip_button)
	else:
		w.name_edit.text = "Çağrı Şükrü"
		w.begin(false)
	await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading, 30.0)
	await _wait(1.0)

func _sec_main_menu() -> void:
	cur = "main_menu"
	var m = current_scene
	await _shot("open")
	_inspect("open")
	# Up / Down move the focus through the list
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _wait(0.3)
	var f = root.gui_get_focus_owner()
	print("main menu focus after Down x2: ", _desc(f) if f != null else "none")
	await _shot("keyboard_focus")
	await _sweep({"root": func(): return _scene_root_if_no_popup(),
		"renav": _to_main_menu,
		"skip": func(c):
			var cs = current_scene
			if cs == null or not ("buttons" in cs): return ""
			if c == cs.buttons.get("Quit"): return "Quit closes the game"
			if c == cs.buttons.get("Continue"): return "Continue loads a level (covered by the loading section)"
			return ""})
	# with progress: Continue shows ("Continue: <level>")
	app.win_first_levels(1)
	await _to_main_menu()
	m = current_scene
	m.refresh()
	await _wait(0.3)
	await _hover(m.buttons["Continue"])
	var n := _inspect("Continue visible")
	_attach(n, await _shot("continue_hover"))
	await _move(NEUTRAL)

func _sec_credits() -> void:
	cur = "credits"
	await _to_main_menu()
	await _press(current_scene.buttons["Credits"])
	await _wait(0.6)
	await _shot("open")
	_inspect("open")
	await _sweep({"root": func(): return _top_popup(),
		"renav": func(): await _reopen_menu_popup("Credits")})
	await _close_popups()

func _sec_settings() -> void:
	cur = "settings"
	await _to_main_menu()
	await _press(current_scene.buttons["Settings"])
	await _wait(0.6)
	var s = _top_popup()
	for i in 4:
		s = _top_popup()
		if s == null or not ("tab_buttons" in s): break
		cur = "settings_" + ["audio", "display", "gameplay", "controls"][i]
		await _press(s.tab_buttons[i])
		await _wait(0.3)
		var n := _inspect("tab")
		_attach(n, await _shot("tab"))
		var tab := i
		await _sweep({"root": func(): return _top_popup(),
			"cap": 160,
			"renav": func():
				await _reopen_menu_popup("Settings")
				var p = _top_popup()
				if p != null and "tab_buttons" in p:
					await _press(p.tab_buttons[tab])
					await _wait(0.3),
			"filter": func(c): return not (c in _top_popup().tab_buttons),
			"extra": func():
				var p = _top_popup()
				return str(p.listening) if p != null and "listening" in p else "",
			"skip": func(c):
				if c is Button and (c.text == "Reset to defaults" or c.text == "Click again to reset"): return "Reset to defaults resets every key"
				var sp = _top_popup()
				if c is CheckButton and sp != null and "_fullscreen" in sp and c == sp._fullscreen: return "Fullscreen changes the window mode (would resize the test window)"
				return ""})
	# keyboard on the sliders (the footer: "click it and use the arrow keys"): a click focuses, Right steps, Tab moves on
	s = _top_popup()
	if s != null and "_sliders" in s:
		cur = "settings_audio"
		await _press(s.tab_buttons[0])
		await _wait(0.3)
		var sl: HSlider = s._sliders["music_volume"][0]
		await _press(sl)
		var v0 := sl.value
		await _key(KEY_RIGHT)
		await _key(KEY_RIGHT)
		await _wait(0.2)
		var fo = root.gui_get_focus_owner()
		print("slider keys: focus=", _desc(fo), " value ", v0, " -> ", sl.value)
		if fo != sl or sl.value <= v0: _find("logic", sl, "a clicked slider does not take the arrow keys (focus %s, value %d -> %d)" % [_desc(fo), v0, sl.value])
		_attach(_inspect("slider focused"), await _shot("slider_focused"))
		await _key(KEY_TAB)
		await _wait(0.2)
		fo = root.gui_get_focus_owner()
		print("after Tab: focus=", _desc(fo), " in settings: ", fo != null and s.is_ancestor_of(fo))
		if fo != null and not s.is_ancestor_of(fo): _find("logic", sl, "Tab from a slider moves the focus out of the Settings window (%s)" % _desc(fo))
		await _move(NEUTRAL)
		await _shot("slider_tab")
	# a capture with a combination, and a conflict with its note
	s = _top_popup()
	if s != null and "key_slots" in s:
		cur = "settings_controls"
		await _press(s.tab_buttons[3])
		await _wait(0.3)
		var slot: Button = null
		for k in s.key_slots:
			if k[0] == "Pause" and k[1] == 1: slot = k[2]
		if slot != null:
			await _press(slot)
			await _wait(0.2)
			_attach(_inspect("listening"), await _shot("listening"))
			await _key(KEY_K, true)
			await _wait(0.2)
			print("captured Pause slot 2: ", kb.describe("Pause"), " button: ", slot.text)
		kb.set_bind("Skip", 0, KeyCombo.new(KEY_ENTER))
		s.refresh_controls()
		await _wait(0.2)
		_attach(_inspect("conflict"), await _shot("conflict"))
		kb.reset_all()
		s.refresh_controls()
	await _close_popups()

func _sec_codex() -> void:
	cur = "codex"
	for id in ["slime", "runner", "big-slime"]: save.codex.discover(CodexSection.Enemies, id)
	for id in ["burn", "shield", "taunted"]: save.codex.discover(CodexSection.Statuses, id)
	for id in ["guardian", "priest"]: save.codex.discover(CodexSection.Towers, id)
	save.save()
	await _to_main_menu()
	await _press(current_scene.buttons["Codex"])
	await _wait(0.8)
	var cx = _top_popup()
	await _shot("open")
	_inspect("open")
	var names := ["towers", "enemies", "statuses", "tips"]
	for i in 4:
		cx = _top_popup()
		if cx == null or not ("tab_buttons" in cx): break
		cur = "codex_" + names[i]
		await _press(cx.tab_buttons[i])
		await _wait(0.5)
		_attach(_inspect("tab"), await _shot("tab"))
		var tab := i
		await _sweep({"root": func(): return _top_popup(),
			"cap": 80,
			"renav": func():
				await _reopen_menu_popup("Codex")
				var p = _top_popup()
				if p != null and "tab_buttons" in p:
					await _press(p.tab_buttons[tab])
					await _wait(0.4),
			"filter": func(c): return not (c in _top_popup().tab_buttons)})
		# every known entry's pages (Overview / Abilities / Forms) checked, a shot when something is found
		cx = _top_popup()
		if cx == null: break
		for r in range(cx.rows.size()):
			cx = _top_popup()
			if r >= cx.rows.size(): break
			var e: Dictionary = cx.entries[r]
			if not save.codex.is_discovered(e.section, e.id): continue
			await _press(cx.rows[r])
			await _wait(0.25)
			var label: String = e.id
			_attach(_inspect("page " + label), "")
			var tabs: Array = []
			for t in cx._strip.get_children(): if t.visible and t.enabled: tabs.append(t.text)
			for tname in tabs:
				var t2 = null
				for t in cx._strip.get_children(): if t.text == tname: t2 = t
				if t2 == null: continue
				await _press(t2)
				await _wait(0.2)
				var nn := _inspect("page %s / %s" % [label, tname])
				if nn > 0: _attach(nn, await _shot("%s_%s" % [label, tname]))
				# the page scrolled to its end
				cx._page_scroll.scroll_vertical = 100000
				await _frames(3)
				nn = _inspect("page %s / %s scrolled" % [label, tname])
				if nn > 0: _attach(nn, await _shot("%s_%s_end" % [label, tname]))
				cx._page_scroll.scroll_vertical = 0
	await _close_popups()

func _sec_level_select() -> void:
	cur = "level_select"
	await _to_level_select()
	var ls = current_scene
	await _shot("open")
	_inspect("open")
	await _sweep({"root": func(): return _top_popup(),
		"cap": 80,
		"renav": _to_level_select,
		"skip": func(c):
			if current_scene != null and "_play" in current_scene and c == current_scene._play: return "Play loads the level (covered by the loading section)"
			return ""})
	# the played, unplayed and locked rows, each through a click on its row
	ls = current_scene
	var states := {}
	for i in ls._rows.size():
		ls = current_scene
		if i >= ls._rows.size(): break
		var id: String = ls.visible_rows[i].entry.level_id if i < ls.visible_rows.size() else ""
		var st := MenuLogic.row_state(save.progress, id, ls.visible_rows[i].unlocked) if id != "" else ""
		if states.has(st): continue
		states[st] = true
		await _press(ls._rows[i])
		await _wait(0.4)
		_attach(_inspect("row " + st), await _shot("row_" + st))

func _sec_hand_editor() -> void:
	cur = "hand_editor"
	# a big collection (every tower type 3 times) so the grid scrolls
	for t in app.catalog.tower_types:
		for i in 3: save.towers.add(t.get_id())
	save.save()
	await _to_level_select()
	await _open_hand_editor()
	var he = _top_popup()
	await _shot("open")
	_inspect("open")
	await _sweep({"root": func(): return _top_popup(),
		"cap": 140,
		"renav": _open_hand_editor,
		"extra": func():
			var p = _top_popup()
			return str(p._renaming) if p != null and "_renaming" in p else ""})
	# the four layouts, each through a click on its tab
	he = _top_popup()
	if he == null: await _open_hand_editor()
	he = _top_popup()
	for i in 4:
		he = _top_popup()
		var tabs: Array = he._layouts.get_children()
		if i >= tabs.size(): break
		await _press(tabs[i])
		await _wait(0.4)
		_attach(_inspect("layout %d" % (i + 1)), await _shot("layout_%d" % (i + 1)))
	# rename: pencil, type a long name, Enter
	he = _top_popup()
	var pen: Button = _find_child_of(he._layouts.get_child(1), "Button")
	if pen != null:
		await _press(pen)
		await _wait(0.2)
		await _key(KEY_A, false, 0, true) # Ctrl+A
		await _type("Late game tanks and healers")
		await _frames(3)
		_attach(_inspect("renaming"), await _shot("renaming"))
		await _key(KEY_ENTER)
		await _wait(0.3)
		print("layout 2 renamed: ", save.data.hand_layouts[1].name)
		_attach(_inspect("renamed long"), await _shot("renamed_long"))
		# rename again, then Esc: the name stays
		he = _top_popup()
		pen = _find_child_of(he._layouts.get_child(1), "Button")
		await _press(pen)
		await _wait(0.2)
		await _type("XYZ")
		await _key(KEY_ESCAPE)
		await _wait(0.3)
		he = _top_popup()
		print("after Esc: layout 2 = ", save.data.hand_layouts[1].name, " editor open=", he != null and he.is_open)
		if he == null or not he.is_open: _find("esc", null, "Esc while renaming closed the hand editor instead of cancelling the rename")
		_attach(_inspect("rename cancelled"), await _shot("rename_cancelled"))
	# sort: every option
	he = _top_popup()
	if he == null: await _open_hand_editor()
	he = _top_popup()
	var sp: OptionButton = he.collection.sort_pick
	for i in sp.item_count:
		sp.select(i)
		sp.item_selected.emit(i)
		await _wait(0.3)
		_attach(_inspect("sort " + sp.get_item_text(i)), await _shot("sort_" + sp.get_item_text(i)))
	# the Filters popup (Eren 2026-10-17: the filters live in a popup behind the bar's Filters button)
	if he.collection.filters_button != null and he.collection.filters_button.is_visible_in_tree():
		await _press(he.collection.filters_button)
		await _wait(0.5)
		_attach(_inspect("filters popup"), await _shot("filters_popup"))
		var fp = he.collection.filters_pop
		if fp != null: fp.close()
		await _wait(0.4)
	# search with no result: the empty state
	await _press(he.collection.search)
	await _type("zzzz")
	await _wait(0.4)
	_attach(_inspect("search no result"), await _shot("search_empty"))
	he.clear_filters()
	await _wait(0.3)
	# the close button
	var x = _find_close(he)
	if x != null:
		await _press(x)
		await _wait(0.5)
		print("hand editor closed by x: ", _top_popup() == current_scene)

func _sec_credits_secret() -> void:
	cur = "credits_secret"
	await _to_main_menu()
	await _press(current_scene.buttons["Credits"])
	await _wait(0.6)
	var c = _top_popup()
	if c == null or not ("name_labels" in c): return
	var l: Label = c.name_labels[0]
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var w := f.get_string_size("EREN OSMAN", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e_w := f.get_string_size("E", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var local := Vector2((l.size.x - w) / 2.0 + e_w / 2.0, l.size.y / 2.0)
	var p := l.get_global_transform() * local
	await _move(p)
	await _click(p)
	await _wait(0.4)
	print("secret title: ", c.title_label.text)
	_attach(_inspect("secret used"), await _shot("secret_title"))
	await _close_popups()

func _sec_camp_locked() -> void:
	cur = "camp_locked"
	await _to_camp()
	var camp = current_scene
	await _wait(0.8)
	await _shot("welcome_card")
	_inspect("welcome card")
	var ok = _find_text(camp.welcome_card, "Look around")
	if ok != null:
		await _hover(ok)
		await _shot("welcome_hover")
		await _press(ok)
	else:
		camp.close_welcome()
	await _wait(0.8)
	cur = "camp_tour"
	var steps := 0
	while camp.tour_step >= 0 and steps < 10:
		steps += 1
		camp.bubble.reveal_all()
		await _wait(0.3)
		var n := _inspect("tour step %d" % (camp.tour_step + 1))
		_attach(n, await _shot("step_%d" % (camp.tour_step + 1)))
		var box: Control = camp.bubble._box
		var vp := root.get_visible_rect()
		if not vp.encloses(box.get_global_rect()):
			_find("tooltip", box, "the tour bubble pokes off the screen at step %d (%s)" % [camp.tour_step + 1, box.get_global_rect()])
		await _move(box.get_global_rect().get_center())
		await _click(box.get_global_rect().get_center())
		await _wait(0.4)
	print("tour ended after ", steps, " steps; tour_step=", camp.tour_step)
	cur = "camp_locked"
	await _move(NEUTRAL)
	await _wait(0.3)
	await _shot("open")
	_inspect("open")
	await _sweep({"root": func(): return _camp_root_if_no_popup(),
		"renav": _to_camp,
		"skip": func(c): return ""})

func _sec_chapter_select() -> void:
	cur = "chapter_select"
	await _to_camp()
	await _press(current_scene.buttons["Chapters"])
	await _wait(0.8)
	await _shot("open")
	_inspect("open")
	await _sweep({"root": func(): return _top_popup(),
		"renav": _open_chapters})
	# a chapter's levels (the Camp's level select panel)
	cur = "camp_level_select"
	await _open_camp_levels()
	await _shot("open")
	_inspect("open")
	await _sweep({"root": func(): return _top_popup(),
		"cap": 60,
		"renav": _open_camp_levels,
		"skip": func(c):
			var p = _top_popup()
			if p != null and "_play" in p and c == p._play: return "Play loads the level (covered by the loading section)"
			return ""})
	await _close_popups()

func _sec_camp_open() -> void:
	cur = "camp_open"
	save.profile.guild_seen = false
	save.save()
	await _to_camp(true)
	await _wait(0.6)
	await _shot("open")
	_inspect("open")
	var camp = current_scene
	var gb = camp.buttons.get("Guild") # the Guild station button (Eren 2026-10-15; replaces the Signpost hotspot)
	if gb != null and gb.visible:
		await _hover(gb)
		await _wait(0.8)
		await _shot("guild_button_hover")
		await _move(NEUTRAL)
	# the Guild button's "New" stays under a popup (Towers): it is the button's child, in the stations' layer
	camp = current_scene
	if camp.guild_tag != null:
		await _press(camp.buttons["Towers"])
		await _wait(0.8)
		var tag_layer: int = camp.guild_tag.get_parent().get_index()
		print("guild tag layer ", tag_layer, " popups index ", camp.popups.get_index())
		if tag_layer > camp.popups.get_index(): _find("layer", camp.guild_tag, "the Guild button's New tag draws over the popups")
		await _shot("towers_over_guild_tag")
		await _close_popups()
	await _sweep({"root": func(): return _camp_root_if_no_popup(),
		"renav": func(): await _to_camp(true)})

func _sec_loading() -> void:
	cur = "loading"
	await _to_camp(true)
	await _open_camp_levels()
	var ls = _top_popup()
	if ls == null or not ("_play" in ls): return
	_render_keep = true # the level holds the loading screen until it has drawn
	RenderingServer.render_loop_enabled = true
	await _press(ls._play)
	# the Loading layer (a CanvasLayer under root; once the level opens under it, the level is the current scene)
	await _until(func(): return _loading_node() != null, 15.0)
	var ld = _loading_node()
	if ld != null:
		await _frames(2)
		await _shot("loading")
		_inspect("loading", ld.root)
		await _until(func(): return not is_instance_valid(ld) or ld.status.text == "Complete!", 60.0)
		if is_instance_valid(ld):
			_inspect("loading complete", ld.root)
			await _shot("loading_complete")
	await _until(func(): return _loading_node() == null, 60.0)
	await _wait(0.5)
	await _shot("level_shown")

# ================================================================== navigation

func _loading_node() -> Node:
	for c in root.get_children():
		if c is CanvasLayer and c.get_script() != null and c.get_script().resource_path.ends_with("screens/loading.gd"): return c
	return null

func _to_main_menu() -> void:
	await _until(func(): return not flow.is_loading, 20.0)
	await _close_popups()
	if flow.current != flow.MainMenu or not ("buttons" in current_scene):
		flow.go(flow.MainMenu)
		await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading, 30.0)
		await _wait(1.0)

func _reopen_menu_popup(which: String) -> void:
	await _to_main_menu()
	await _press(current_scene.buttons[which])
	await _wait(0.7)

func _to_level_select() -> void:
	await _until(func(): return not flow.is_loading, 20.0)
	if flow.current == flow.LevelSelect:
		while TdPopup.open_popups.size() > 1:
			await _key(KEY_ESCAPE)
			await _wait(0.4)
		return
	await _to_main_menu()
	# through the main menu's Play (home is the level select before the Camp)
	await _press(current_scene.buttons["Play"])
	await _until(func(): return flow.current != flow.MainMenu and not flow.is_loading, 30.0)
	if flow.current != flow.LevelSelect:
		flow.go(flow.LevelSelect)
		await _until(func(): return flow.current == flow.LevelSelect and not flow.is_loading, 30.0)
	await _wait(0.8)

func _open_hand_editor() -> void:
	await _to_level_select()
	var ls = current_scene
	var change = _find_text(ls, "Change hand")
	if change != null: await _press(change)
	else: ls.open_hand_editor()
	await _wait(0.8)

func _to_camp(fresh := false) -> void:
	await _until(func(): return not flow.is_loading, 20.0)
	if fresh and flow.current == flow.Camp:
		flow.go(flow.MainMenu)
		await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading, 30.0)
		await _wait(0.5)
	if flow.current == flow.Camp:
		await _close_popups()
		if current_scene.tour_step >= 0: current_scene.end_tour()
		return
	await _to_main_menu()
	await _press(current_scene.buttons["Play"])
	await _until(func(): return flow.current != flow.MainMenu and not flow.is_loading, 30.0)
	if flow.current != flow.Camp:
		flow.go(flow.Camp)
		await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 30.0)
	await _wait(1.0)
	var camp = current_scene
	if camp.welcome_card.visible and cur != "camp_locked":
		camp.close_welcome()
	if camp.tour_step >= 0 and cur != "camp_locked": camp.end_tour()

func _open_chapters() -> void:
	await _to_camp()
	await _press(current_scene.buttons["Chapters"])
	await _wait(0.8)

func _open_camp_levels() -> void:
	await _open_chapters()
	var ch = _top_popup()
	if ch == null or not ("cards" in ch) or ch.cards.is_empty(): return
	await _press(ch.cards[0])
	await _wait(0.9)

func _close_popups() -> void:
	var guard := 0
	while guard < 6:
		var n := TdPopup.open_popups.size()
		var base := 1 if flow.current == flow.LevelSelect else 0
		if n <= base and _native_popups() == 0: break
		await _key(KEY_ESCAPE)
		await _wait(0.45)
		guard += 1

# ================================================================== the sweep

## Hover + click every clickable of opts.root() once (keys: class, text and position in its scroll content).
func _sweep(opts: Dictionary) -> void:
	var visited := {}
	var done := 0
	var cap: int = opts.get("cap", 60)
	var shots := {}
	while done < cap:
		var top = opts.root.call()
		if top == null or not is_instance_valid(top):
			if opts.has("renav"):
				await opts.renav.call()
				top = opts.root.call()
			if top == null or not is_instance_valid(top): break
		var list := _clickables(top)
		if opts.has("filter"): list = list.filter(opts.filter)
		var c: Control = null
		for x in list:
			var k := _ckey(x, top)
			if not visited.has(k):
				visited[k] = true
				c = x
				break
		if c == null: break
		done += 1
		var why: String = opts.skip.call(c) if opts.has("skip") else ""
		if why != "":
			skipped.append([cur, _desc(c), why])
			continue
		await _probe(c, opts, shots)
	print("  sweep %s: %d controls (%d s)" % [cur, done, (Time.get_ticks_msec() - _t0) / 1000])

func _probe(c: Control, opts: Dictionary, shots: Dictionary) -> void:
	var d := _desc(c)
	var g := _group(c)
	var ng: int = shots.get(g, 0)
	shots[g] = ng + 1
	var shoot := ng < 2
	var sc := _scroll_of(c)
	if sc != null:
		sc.ensure_control_visible(c)
		await _frames(3)
	var p = _click_point(c)
	if p == null:
		_find("unreachable", c, "no visible part to point at (clipped away)")
		return
	await _move(p)
	await _frames(6)
	var hov := root.gui_get_hovered_control()
	# right after an embedded popup (a dropdown) closed, the root reports no hovered control until the pointer
	# re-enters the window (no real pointer under Xvfb): not a finding then
	var after_popup := _popup_closed
	_popup_closed = false
	if not after_popup and hov != c and not (hov != null and c.is_ancestor_of(hov)):
		_find("unreachable", c, "the pointer on its centre lands on %s" % (_desc(hov) if hov != null else "nothing"))
	var has_tip: bool = TdTooltipTrigger.find_on(c) != null or c.tooltip_text != "" or (c is TdButton and not c.interactable)
	if has_tip: await _wait(0.8)
	_check_tooltip(c)
	var n := _inspect("hover " + d)
	if TdTooltip.is_visible(): n += _inspect("tooltip of " + d, TdTooltip.box())
	if shoot or n > 0 or (has_tip and ng < 3):
		_attach(n, await _shot("hover_" + d))
	var st := _state(opts)
	await _click(p)
	await _frames(6)
	await _wait(0.4)
	var st2 := _state(opts)
	var changed := not _same(st, st2)
	n = _inspect("after clicking " + d)
	for w in _visible_windows(): n += _inspect("popup of " + d, w)
	_check_tooltip(c)
	if shoot or n > 0 or changed:
		_attach(n, await _shot("click_" + d))
	# (f) the pointer leaves: the look comes back
	await _move(NEUTRAL)
	await _wait(0.45)
	if is_instance_valid(c) and c.is_visible_in_tree() and _hover_state(c):
		_find("stuck", c, "still shows hover / pressed / grown after the pointer left")
	if TdTooltip.is_visible() and not (c is TdButton and not c.interactable):
		_find("stuck", c, "its tooltip stays after the pointer left")
	# (g) back to the state before the click
	var tries := 0
	while tries < 3:
		var now := _state(opts)
		if _same(now, st): break
		if not (now.native > st.native or now.popups > st.popups or (now.popups == st.popups and now.extra != st.extra)): break
		if now.native > st.native: _popup_closed = true
		await _key(KEY_ESCAPE)
		await _wait(0.45)
		tries += 1
	var after := _state(opts)
	if not _same(after, st):
		if after.scene == st.scene and after.node == st.node and (after.popups > st.popups or after.native > st.native or (after.popups == st.popups and after.extra != st.extra)):
			_find("esc", c, "Esc x3 does not leave the state its click opened (popups %d→%d, menus %d→%d, %s→%s)" % [st.popups, after.popups, st.native, after.native, st.extra, after.extra])
			_attach(1, await _shot("esc_stuck_" + d))
		await _until(func(): return not flow.is_loading, 30.0)
		if opts.has("renav"):
			await opts.renav.call()
			await _wait(0.3)
	_drain_log("after " + d)

func _state(opts: Dictionary) -> Dictionary:
	return {"scene": flow.current, "node": current_scene.get_instance_id() if current_scene != null else 0,
		"popups": TdPopup.open_popups.size(), "native": _native_popups(),
		"extra": str(opts.extra.call()) if opts.has("extra") else ""}

func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.scene == b.scene and a.node == b.node and a.popups == b.popups and a.native == b.native and a.extra == b.extra

func _visible_windows() -> Array:
	var out := []
	for w in root.get_embedded_subwindows():
		if w.visible: out.append(w)
	var top := _top_root()
	if top != null: _option_popups(top, out)
	return out

func _option_popups(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is OptionButton or ch is MenuButton:
			var pm: PopupMenu = ch.get_popup()
			if pm != null and pm.visible and not out.has(pm): out.append(pm)
		elif ch is CanvasItem and not ch.visible:
			continue
		_option_popups(ch, out)

func _native_popups() -> int:
	var n := 0
	for w in _visible_windows():
		if not w.get_class().contains("Tooltip"): n += 1
	return n

# ================================================================== clickables

func _clickables(top: Control) -> Array:
	var items := []
	_walk(top, 1.0, [], items)
	var out := []
	for it in items:
		var c: Control = it[0]
		if not _is_clickable(c): continue
		var vis := _visible_rect(c, it[2])
		if vis.size.x < 4 or vis.size.y < 4:
			if _scroll_of(c) == null: continue
		out.append(c)
	return out

func _is_clickable(c: Control) -> bool:
	if c is ScrollBar or c is TdScrim or c is ScrollContainer or c is TdPopup: return false
	if c is TdTextBubble: return false
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE: return false
	if c is BaseButton or c is TdButton or c is LineEdit or c is Slider or c is TextEdit: return true
	if c.mouse_filter != Control.MOUSE_FILTER_STOP: return false
	if TdTooltipTrigger.find_on(c) != null or c.tooltip_text != "": return true
	if c.gui_input.get_connections().size() > 0: return true
	var s: Script = c.get_script()
	if s != null:
		for m in s.get_script_method_list():
			if m.name == "_gui_input": return true
	return false

func _ckey(c: Control, top: Control) -> String:
	var sc := _scroll_of(c)
	var pos: Vector2
	if sc != null:
		var content: Control = null
		for ch in sc.get_children():
			if ch is Control and not (ch is ScrollBar): content = ch
		pos = c.get_global_rect().position - (content.get_global_rect().position if content != null else sc.get_global_rect().position)
	else:
		pos = c.get_global_rect().position - top.get_global_rect().position
	return "%s|%s|%d,%d" % [_cls(c), _text_of(c).left(30), int(snappedf(pos.x, 8.0)), int(snappedf(pos.y, 8.0))]

func _group(c: Control) -> String:
	var s := _cls(c)
	var p := c.get_parent()
	for i in 3:
		if p == null: break
		s = _cls(p) + "/" + s
		p = p.get_parent()
	return s

## The part of a control's face its clipping ancestors and the screen let through.
func _vis(c: Control) -> Rect2:
	var r: Rect2 = c.face_global_rect() if c is TdButton else c.get_global_rect()
	var p := c.get_parent()
	while p != null and p != root:
		if p is Control and (p.clip_contents or p is ScrollContainer):
			r = r.intersection(p.get_global_rect())
		p = p.get_parent()
	return r.intersection(root.get_visible_rect())

func _click_point(c: Control):
	var r: Rect2 = c.face_global_rect() if c is TdButton else c.get_global_rect()
	var p := c.get_parent()
	while p != null and p != root:
		if p is Control and (p.clip_contents or p is ScrollContainer):
			r = r.intersection(p.get_global_rect())
		p = p.get_parent()
	r = r.intersection(root.get_visible_rect())
	if r.size.x < 2 or r.size.y < 2: return null
	return r.get_center()

func _visible_rect(c: Control, clips: Array) -> Rect2:
	var r := c.get_global_rect()
	for k in clips: r = r.intersection(k.get_global_rect())
	return r.intersection(root.get_visible_rect())

func _scroll_of(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer: return p
		p = p.get_parent()
	return null

func _hover_state(c: Control) -> bool:
	if c is TdButton: return c.hovered or c.pressed or c.face_node().scale.x > 1.002
	if c is BaseButton: return c.is_hovered()
	for prop in ["_hover", "_hovered"]:
		if prop in c: return bool(c.get(prop))
	return false

# ================================================================== checks

## Inspects the top layer (or `top`): clipping, the screen edge, text, windows, overlaps; returns new findings.
func _inspect(ctx: String, top: Node = null) -> int:
	var before := order.size()
	if top == null: top = _top_root()
	if top == null or not is_instance_valid(top) or (top is Control and not top.is_visible_in_tree()):
		_drain_log(ctx)
		return order.size() - before
	var items := []
	_walk(top, 1.0, [], items)
	var vp := root.get_visible_rect()
	var texts := []
	for it in items:
		var c: Control = it[0]
		if c.size.x < 1.0 or c.size.y < 1.0: continue
		# what the clipping ancestors let through (scrolled content outside it is not drawn)
		var shown := vp
		for k in it[2]: shown = shown.intersection(k.get_global_rect())
		if _draws(c):
			var r := _draw_rect(c)
			for k in it[2]: _check_clip(c, r, k, ctx)
			if it[2].is_empty(): _check_screen(c, r, vp, ctx)
			elif r.intersects(shown): _check_screen(c, r.intersection(shown.grow(4.0)), vp, ctx)
		if c is Label:
			_check_label(c, ctx)
			if c.text.strip_edges() != "":
				var ink := _ink_label(c)
				if ink.intersects(shown): texts.append([c, ink.intersection(shown)])
		elif c is RichTextLabel:
			_check_rich(c, ctx)
			if c.get_parsed_text().strip_edges() != "":
				var ink2 := _ink_rich(c)
				if ink2.intersects(shown): texts.append([c, ink2.intersection(shown)])
		elif c is TdButton:
			_check_tdbutton(c, ctx)
		if c is Container and c.get_parent() is Control and not (c.get_parent() is Container):
			_check_fits_parent(c, ctx)
		if c is TdPanel: _check_window(c, ctx)
	_check_text_overlaps(texts, ctx)
	_check_sibling_rims(items, ctx)
	if top is Control: _check_click_overlaps(top, ctx)
	_drain_log(ctx)
	return order.size() - before

func _walk(n: Node, alpha: float, clips: Array, out: Array) -> void:
	for ch in n.get_children():
		if ch is Viewport or ch is Window: continue
		if ch is CanvasLayer:
			if ch.visible: _walk(ch, alpha, [], out)
			continue
		if not (ch is CanvasItem): continue
		if not ch.visible: continue
		var a: float = alpha * ch.modulate.a
		if a < 0.05: continue
		var next := clips
		if ch is Control:
			if a * ch.self_modulate.a >= 0.05: out.append([ch, a, clips])
			if ch.clip_contents or ch is ScrollContainer or ch.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
				next = clips.duplicate()
				next.append(ch)
		_walk(ch, a, next, out)

func _draws(c: Control) -> bool:
	if c is TdScrim: return false
	if c is Label: return c.text.strip_edges() != ""
	if c is RichTextLabel: return c.text != ""
	if c is TextureRect: return c.texture != null
	if c is ColorRect: return c.color.a > 0.02
	if c is Button or c is LineEdit or c is Slider: return true
	if c is Panel or c is PanelContainer:
		var sb := c.get_theme_stylebox("panel")
		if sb == null or sb is StyleBoxEmpty: return false
		if sb is StyleBoxFlat and sb.bg_color.a < 0.02 and sb.border_width_left + sb.border_width_top == 0: return false
		return true
	return false

func _draw_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var sb: StyleBox = null
	if c is Panel or c is PanelContainer: sb = c.get_theme_stylebox("panel")
	elif c is Button: sb = c.get_theme_stylebox("normal")
	var s := c.get_global_transform().get_scale()
	if sb is TdSliceBox:
		r = r.grow_individual(sb.outset_left * s.x, sb.outset_top * s.y, sb.outset_right * s.x, sb.outset_bottom * s.y)
	elif sb is StyleBoxFlat:
		r = r.grow_individual(sb.expand_margin_left * s.x, sb.expand_margin_top * s.y, sb.expand_margin_right * s.x, sb.expand_margin_bottom * s.y)
	elif sb is StyleBoxTexture:
		r = r.grow_individual(sb.expand_margin_left * s.x, sb.expand_margin_top * s.y, sb.expand_margin_right * s.x, sb.expand_margin_bottom * s.y)
	return r

func _check_clip(c: Control, r: Rect2, k: Control, ctx: String) -> void:
	var kr := k.get_global_rect()
	if not r.intersects(kr): return # scrolled out of sight: fine
	var l := kr.position.x - r.position.x
	var t := kr.position.y - r.position.y
	var rr := r.end.x - kr.end.x
	var b := r.end.y - kr.end.y
	var tol := 1.5
	var parts := []
	if k is ScrollContainer:
		var sc: ScrollContainer = k
		var vbar := sc.get_v_scroll_bar()
		# content drawn under the vertical scrollbar (missed in the first rounds: the hand editor's stat tiles)
		if vbar.visible and not (c is ScrollBar) and not vbar.is_ancestor_of(c):
			var br := vbar.get_global_rect()
			var under := r.intersection(br)
			if under.size.x > 1.5 and under.size.y > 1.5:
				_find("clip", c, "drawn under %s's scrollbar by %d px" % [_desc(k), ceili(under.size.x)], ctx)
		var at_top := sc.scroll_vertical <= 0
		var at_end := not vbar.visible or sc.scroll_vertical >= int(vbar.max_value - vbar.page) - 1
		var hbar := sc.get_h_scroll_bar()
		if not hbar.visible:
			if l > tol: parts.append("left %d px" % ceili(l))
			if rr > tol: parts.append("right %d px" % ceili(rr))
		if t > tol and at_top and t < r.size.y * 0.5: parts.append("top %d px (scroll at the top)" % ceili(t))
		if b > tol and at_end and b < r.size.y * 0.5: parts.append("bottom %d px (scroll at the end)" % ceili(b))
	else:
		if l > tol: parts.append("left %d px" % ceili(l))
		if rr > tol: parts.append("right %d px" % ceili(rr))
		if t > tol: parts.append("top %d px" % ceili(t))
		if b > tol: parts.append("bottom %d px" % ceili(b))
	if parts.is_empty(): return
	_find("clip", c, "cut by %s: %s" % [_desc(k), ", ".join(parts)], ctx)

func _check_screen(c: Control, r: Rect2, vp: Rect2, ctx: String) -> void:
	if r.size.x >= vp.size.x * 0.9 and r.size.y >= vp.size.y * 0.9: return # a background
	if not r.intersects(vp): return
	var parts := []
	if r.position.x < vp.position.x - 1.5: parts.append("left %d px" % ceili(vp.position.x - r.position.x))
	if r.position.y < vp.position.y - 1.5: parts.append("top %d px" % ceili(vp.position.y - r.position.y))
	if r.end.x > vp.end.x + 1.5: parts.append("right %d px" % ceili(r.end.x - vp.end.x))
	if r.end.y > vp.end.y + 1.5: parts.append("bottom %d px" % ceili(r.end.y - vp.end.y))
	if parts.is_empty(): return
	_find("screen", c, "pokes off the screen: %s" % ", ".join(parts), ctx)

func _label_metrics(l: Label) -> Array:
	var font: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var tw := 0.0
	var text := l.text.to_upper() if l.uppercase else l.text
	for line in text.split("\n"): tw = maxf(tw, font.get_string_size(line.strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var sb := l.get_theme_stylebox("normal")
	var mx := (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)) if sb != null else 0.0
	return [font, fs, tw, l.size.x - mx]

func _check_label(l: Label, ctx: String) -> void:
	if l.text.strip_edges() == "": return
	var m := _label_metrics(l)
	var fs: int = m[1]
	var tw: float = m[2]
	var avail: float = m[3]
	if fs < 18: _find("small", l, "text at %d px (the UI rule: nothing under 18 px)" % fs, ctx)
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		if tw > avail + 1.5:
			if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				_find("trunc", l, "truncated: needs %d px, has %d px" % [ceili(tw), floori(avail)], ctx)
			else:
				_find("overflow", l, "text runs %d px past its box (needs %d, has %d)" % [ceili(tw - avail), ceili(tw), floori(avail)], ctx)
	else:
		var vis := l.get_visible_line_count()
		var all := l.get_line_count()
		if vis < all:
			_find("trunc", l, "wrapped text cut: %d of %d lines show" % [vis, all], ctx)
		elif all >= 4 and avail < 120.0:
			_find("trunc", l, "wraps into %d lines in a %d px column" % [all, floori(avail)], ctx)

func _check_rich(r: RichTextLabel, ctx: String) -> void:
	if r.get_parsed_text().strip_edges() == "": return
	var fs: int = r.get_theme_font_size("normal_font_size")
	if fs > 0 and fs < 18: _find("small", r, "rich text at %d px (the UI rule: nothing under 18 px)" % fs, ctx)
	if not r.scroll_active:
		var ch := r.get_content_height()
		if ch > r.size.y + 2.0: _find("overflow", r, "rich text needs %d px of height, has %d" % [ch, floori(r.size.y)], ctx)
	if r.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var cw := r.get_content_width()
		if cw > r.size.x + 2.0: _find("overflow", r, "rich text needs %d px of width, has %d" % [cw, floori(r.size.x)], ctx)

func _check_tdbutton(b: TdButton, ctx: String) -> void:
	var lab: Label = b._label
	if lab == null or not lab.visible or b.text == "": return
	var face := b.face_rect().size
	var m := _label_metrics(lab)
	var tw: float = m[2]
	var x0 := lab.position.x
	var x1 := lab.position.x + tw
	if lab.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x0 = lab.position.x + (lab.size.x - tw) / 2.0; x1 = x0 + tw
	if x0 < -0.5 or x1 > face.x + 0.5:
		_find("overflow", b, "label '%s' (%d px) spills out of the %d px face" % [b.text, ceili(tw), floori(face.x)], ctx)

func _check_fits_parent(c: Control, ctx: String) -> void:
	var p: Control = c.get_parent()
	if p.size.x < 2.0 or p.size.y < 2.0: return
	var tol := 1.5
	var parts := []
	if c.position.x < -tol: parts.append("left %d" % ceili(-c.position.x))
	if c.position.y < -tol: parts.append("top %d" % ceili(-c.position.y))
	if c.position.x + c.size.x > p.size.x + tol: parts.append("right %d" % ceili(c.position.x + c.size.x - p.size.x))
	if c.position.y + c.size.y > p.size.y + tol: parts.append("bottom %d" % ceili(c.position.y + c.size.y - p.size.y))
	if parts.is_empty(): return
	_find("overflow", c, "content (%dx%d) pokes out of %s (%dx%d): %s px" % [c.size.x, c.size.y, _desc(p), p.size.x, p.size.y, ", ".join(parts)], ctx)

func _check_window(p: TdPanel, ctx: String) -> void:
	var cms := p.custom_minimum_size
	if cms.y > 0.0 and p.size.y > cms.y + 2.0:
		_find("window", p, "grew to %d px high (set %d): its content is taller" % [p.size.y, cms.y], ctx)
	if cms.x > 0.0 and p.size.x > cms.x + 2.0 and p.anchor_left == p.anchor_right:
		_find("window", p, "grew to %d px wide (set %d): its content is wider" % [p.size.x, cms.x], ctx)

func _ink_label(l: Label) -> Rect2:
	var m := _label_metrics(l)
	var font: Font = m[0]
	var fs: int = m[1]
	var tw: float = m[2]
	var lines := l.get_visible_line_count() if l.autowrap_mode != TextServer.AUTOWRAP_OFF else l.text.split("\n").size()
	var h := lines * font.get_height(fs) + maxi(0, lines - 1) * l.get_theme_constant("line_spacing")
	var w := l.size.x if l.autowrap_mode != TextServer.AUTOWRAP_OFF else (minf(tw, l.size.x) if (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) else tw)
	var ox := 0.0
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER: ox = (l.size.x - w) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT: ox = l.size.x - w
	var oy := 0.0
	match l.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER: oy = (l.size.y - h) / 2.0
		VERTICAL_ALIGNMENT_BOTTOM: oy = l.size.y - h
	var xf := l.get_global_transform()
	return Rect2(xf * Vector2(ox, oy), Vector2(w, h) * xf.get_scale())

func _ink_rich(r: RichTextLabel) -> Rect2:
	var xf := r.get_global_transform()
	var w := minf(float(r.get_content_width()), r.size.x) if r.autowrap_mode != TextServer.AUTOWRAP_OFF else float(r.get_content_width())
	return Rect2(xf.get_origin(), Vector2(w, minf(float(r.get_content_height()), r.size.y + 2.0)) * xf.get_scale())

## Children of a container whose drawn boxes (with their sprite outsets) overlap: rows / chips touching.
func _check_sibling_rims(items: Array, ctx: String) -> void:
	var by_parent := {}
	for it in items:
		var c: Control = it[0]
		var p := c.get_parent()
		if not (p is BoxContainer or p is FlowContainer or p is GridContainer): continue
		var d := _sibling_box(c)
		if d.size.x < 1.0: continue
		if not by_parent.has(p): by_parent[p] = []
		by_parent[p].append([c, d])
	for p in by_parent:
		var list: Array = by_parent[p]
		for i in list.size():
			for j in range(i + 1, list.size()):
				var x: Rect2 = list[i][1].intersection(list[j][1])
				if x.size.x > 1.5 and x.size.y > 1.5:
					_find("overlap", list[i][0], "its box touches / overlaps sibling %s by %dx%d px" % [_desc(list[j][0]), x.size.x, x.size.y], ctx)

## A container child's drawn box: its own style box (with outset), else its first drawn child's.
func _sibling_box(c: Control) -> Rect2:
	if c.size.x < 1.0 or c.size.y < 1.0: return Rect2()
	if c is Label or c is RichTextLabel: return Rect2()
	if _draws(c): return _draw_rect(c)
	return Rect2()

func _check_text_overlaps(texts: Array, ctx: String) -> void:
	for i in texts.size():
		for j in range(i + 1, texts.size()):
			var a: Rect2 = texts[i][1]
			var b: Rect2 = texts[j][1]
			if not a.intersects(b): continue
			var x := a.intersection(b)
			if x.size.x < 3.0 or x.size.y < 4.0 or x.get_area() < 40.0: continue
			var ca: Control = texts[i][0]
			var cb: Control = texts[j][0]
			if ca.is_ancestor_of(cb) or cb.is_ancestor_of(ca): continue
			_find("overlap", ca, "text overlaps %s by %dx%d px" % [_desc(cb), x.size.x, x.size.y], ctx)

func _check_click_overlaps(top: Control, ctx: String) -> void:
	var list := _clickables(top)
	var vp := root.get_visible_rect()
	for i in list.size():
		var a: Control = list[i]
		if a.has_meta("prop"): continue
		var ra: Rect2 = _vis(a)
		if ra.size.x < 2 or ra.size.x >= vp.size.x * 0.9: continue
		for j in range(i + 1, list.size()):
			var b: Control = list[j]
			if b.has_meta("prop") or a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			var rb: Rect2 = _vis(b)
			if rb.size.x < 2 or not ra.intersects(rb): continue
			var x := ra.intersection(rb)
			var small := minf(ra.get_area(), rb.get_area())
			if small > 0.0 and x.get_area() > small * 0.15 and x.size.x > 4 and x.size.y > 4:
				_find("overlap", a, "clickable overlaps clickable %s (%dx%d px)" % [_desc(b), x.size.x, x.size.y], ctx)

func _check_tooltip(c) -> void:
	if c != null and not is_instance_valid(c): c = null
	var vp := root.get_visible_rect()
	if TdTooltip.is_visible():
		var r := TdTooltip.box().get_global_rect()
		if not vp.grow(0.5).encloses(r): _find("tooltip", c, "its tooltip pokes off the screen (%s)" % r)
	var layer := TdTooltip.layer()
	if layer != null:
		for b in layer.stack_boxes:
			if is_instance_valid(b) and b.is_visible_in_tree() and not vp.grow(0.5).encloses(b.get_global_rect()):
				_find("tooltip", c, "a tooltip stack box pokes off the screen (%s)" % b.get_global_rect())
	for w in _visible_windows():
		var r := Rect2(Vector2(w.position), Vector2(w.size))
		if not vp.grow(0.5).encloses(r): _find("tooltip", c, "%s pokes off the screen (%s)" % [w.get_class(), r])

func _drain_log(ctx: String) -> void:
	for l in qlog.take():
		var msg: String = l[1]
		if msg.contains("ALSA") or msg.contains("leaked") or msg.contains("PCM") or msg == "": continue
		_find("error", null, "%s: %s @ %s" % [l[0], msg.left(300), l[2]], ctx)

# ================================================================== findings

func _find(check: String, c, what: String, ctx := "") -> void:
	var el: String = _desc(c) if c != null and is_instance_valid(c) else "-"
	var sig := what
	# numbers vary between states: one finding per element and kind
	var re := RegEx.create_from_string("[0-9]+")
	sig = re.sub(sig, "#", true)
	var key := "%s|%s|%s|%s" % [cur, check, el, sig if check == "error" else ""]
	if findings.has(key):
		findings[key].count += 1
		return
	findings[key] = {"screen": cur, "check": check, "element": el, "what": what, "context": ctx, "shot": "", "count": 1,
		"path": _path_of(c) if c != null and is_instance_valid(c) else ""}
	order.append(key)
	print("FINDING [%s] %s | %s | %s (%s)" % [cur, check, el, what, ctx])

func _attach(n: int, shot: String) -> void:
	if shot == "": return
	for i in range(order.size() - 1, maxi(-1, order.size() - 1 - n), -1):
		if findings[order[i]].shot == "": findings[order[i]].shot = shot

func _write() -> void:
	var out := []
	for k in order: out.append(findings[k])
	var f := FileAccess.open(out_dir.path_join("findings.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"viewport": str(root.size), "findings": out, "skipped": skipped}, "  "))
	f.close()
	print("QA FINDINGS: %d (skipped %d)" % [out.size(), skipped.size()])
	for s in skipped: print("SKIPPED [%s] %s: %s" % s)

# ================================================================== names

func _cls(n: Node) -> String:
	if n == null: return "null"
	var s: Script = n.get_script()
	if s != null and s.get_global_name() != "": return s.get_global_name()
	if s != null:
		var bn: String = s.resource_path.get_file().get_basename()
		if bn != "" and not str(n.name).begins_with("@"): return "%s:%s" % [bn, n.name]
	return n.get_class()

func _text_of(c: Node) -> String:
	if c == null: return ""
	if "text" in c and str(c.get("text")).strip_edges() != "":
		return str(c.get("text")).strip_edges()
	if c is LineEdit: return c.placeholder_text
	var l := _first_label(c, 4)
	if l != "": return l
	if c is Control and c.tooltip_text != "": return c.tooltip_text
	return ""

func _first_label(n: Node, depth: int) -> String:
	if depth < 0: return ""
	for ch in n.get_children():
		if (ch is Label or ch is RichTextLabel) and ch.visible:
			var t: String = ch.get_parsed_text() if ch is RichTextLabel else ch.text
			if t.strip_edges() != "": return t.strip_edges()
		var s := _first_label(ch, depth - 1)
		if s != "": return s
	return ""

func _desc(c) -> String:
	if c == null or not is_instance_valid(c): return "-"
	var t := _text_of(c).replace("\n", " ")
	return "%s '%s'" % [_cls(c), t.left(40)] if t != "" else _cls(c)

func _path_of(c: Node) -> String:
	var parts := []
	var n := c
	for i in 6:
		if n == null or n == root: break
		parts.push_front(_cls(n))
		n = n.get_parent()
	return "/".join(parts)

func _find_text(n: Node, text: String) -> Control:
	for ch in n.get_children():
		if ch is Control and ch.is_visible_in_tree() and (ch is TdButton or ch is BaseButton) and _text_of(ch) == text: return ch
		var r := _find_text(ch, text)
		if r != null: return r
	return null

func _find_child_of(n: Node, cls: String) -> Node:
	for ch in n.get_children():
		if ch.get_class() == cls: return ch
		var r := _find_child_of(ch, cls)
		if r != null: return r
	return null

func _find_close(p: Node) -> TdButton:
	for ch in p.get_children():
		if ch is TdButton and ch.style == TdButton.Style.ICON and ch.icon == TdTheme.texture("icon_close"): return ch
		var r := _find_close(ch)
		if r != null: return r
	return null

# ================================================================== layers

func _top_popup() -> Control:
	for i in range(TdPopup.open_popups.size() - 1, -1, -1):
		var p = TdPopup.open_popups[i]
		if is_instance_valid(p) and p.is_inside_tree(): return p
	return null

func _top_root() -> Control:
	var p := _top_popup()
	if p != null: return p
	var s := current_scene
	if s is Control: return s
	if s is CanvasLayer and "root" in s: return s.root
	return null

func _scene_root_if_no_popup() -> Control:
	return current_scene if TdPopup.open_popups.is_empty() and current_scene is Control else null

func _camp_root_if_no_popup() -> Control:
	if flow.current != flow.Camp or not TdPopup.open_popups.is_empty(): return null
	return current_scene

# ================================================================== input and time

func _frames(n: int) -> void:
	for i in n: await process_frame

func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000.0: await process_frame

func _until(cond: Callable, timeout: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > timeout * 1000.0:
			print("TIMEOUT waiting (", cur, ") scene=", current_scene)
			return
		await process_frame

func _to_win(p: Vector2) -> Vector2:
	return p * Vector2(root.size) / root.get_visible_rect().size

func _move(p: Vector2) -> void:
	root.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	var w := _to_win(p)
	ev.position = w
	ev.global_position = w
	ev.relative = w - _to_win(_mouse)
	_mouse = p
	Input.parse_input_event(ev)
	await _frames(2)

func _click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var w := _to_win(p)
	var ev := InputEventMouseButton.new()
	ev.position = w
	ev.global_position = w
	ev.button_index = button
	ev.pressed = true
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(ev)
	await _frames(2)
	var up := ev.duplicate()
	up.pressed = false
	up.button_mask = 0
	Input.parse_input_event(up)
	await _frames(2)

func _hover(c: Control) -> void:
	var p = _click_point(c)
	if p == null: return
	await _move(p)
	await _wait(0.3)

## Moves onto a control and clicks it (the real pointer path).
func _press(c: Control) -> void:
	if c == null or not is_instance_valid(c): return
	var sc := _scroll_of(c)
	if sc != null:
		sc.ensure_control_visible(c)
		await _frames(3)
	var p = _click_point(c)
	if p == null:
		print("cannot press ", _desc(c))
		return
	await _move(p)
	await _frames(3)
	await _click(p)
	await _frames(3)

func _key(code: int, shift := false, unicode := 0, ctrl := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(1)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)

func _type(text: String) -> void:
	for ch in text:
		var code := OS.find_keycode_from_string(ch.to_upper()) if ch.to_upper() != ch.to_lower() and ch.unicode_at(0) < 128 else KEY_NONE
		if ch == " ": code = KEY_SPACE
		await _key(code, ch != ch.to_lower(), ch.unicode_at(0))

# ================================================================== shots

func _shot(label: String) -> String:
	RenderingServer.render_loop_enabled = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var clean := label.replace("'", "").replace(" ", "_").validate_filename().left(60)
	var p := "%s/%03d_%s_%s.jpg" % [out_dir, _n, cur, clean]
	root.get_viewport().get_texture().get_image().save_jpg(p, 0.88)
	RenderingServer.render_loop_enabled = _render_keep
	return ProjectSettings.globalize_path(p)
