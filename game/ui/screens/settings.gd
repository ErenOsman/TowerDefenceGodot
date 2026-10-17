extends TdPopup
## The Settings window (UI_Settings.cs; the Unity build's layout; mockups settings-*.html), reusable from the main
## menu and the level's pause menu:
##   var s = load("res://game/ui/screens/settings.tscn").instantiate(); add_child(s); s.open(); s.closed.connect(…)
## Tabs on top — Audio (master / music / SFX / other volume sliders), Display (resolution + fullscreen; the tab is
## hidden on the web, where the page sets the size), Gameplay (game speed stages, follow action, camera follows
## selection, drag to pan, instant playback, always show health), Controls (KeyBinds rows: a header per group,
## modifier dropdowns, two key slots per action; click a slot, then press a key with its combination; red = the
## key is bound twice; Reset all) — rows label left / control right, Back at the bottom. Every change applies and
## saves at once (SettingsMgr setters, KeyBinds). Esc / right click: cancels a key capture first, else closes.

const TABS := ["Audio", "Display", "Gameplay", "Controls"]
const TAB_ICONS := ["icon_sound", "icon_monitor", "icon_sliders", "icon_keyboard"]
const WIDTH := 900.0
const CONTROL_W := 520.0
## The window's top edge (reference px): the tallest tab (Controls) is then centred on the screen.
const TOP := 130.0
## Every page's height (the Controls page: its header row and the 520 px list).
const PAGE_H := 560.0

var tab_buttons: Array = []
var pages: Array = []
var current_tab := 0
var reset_button: Button
## [id, slot, Button] for every key slot on the Controls page.
var key_slots: Array = []
## [id, OptionButton] for every modifier row.
var modifier_rows: Array = []
## The slot waiting for a key ([id, slot]) or empty.
var listening: Array = []

var _sliders := {}   # name → [HSlider, value Label]
var _toggles := {}   # name → CheckButton
var _resolution: OptionButton
var _fullscreen: CheckButton
var _speed: HSlider
var _speed_value: Label
var _key_notes: Array = []   # [action id, note Label under its row], in list order

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	# the window's top edge is pinned (it grows downward with the tab's rows), so the tab row never jumps
	center.queue_free()
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 24)
	p.custom_minimum_size = Vector2(WIDTH, 0)
	p.set_anchors_preset(PRESET_CENTER_TOP)
	p.offset_left = -WIDTH / 2.0
	p.offset_right = WIDTH / 2.0
	p.offset_top = TOP
	p.grow_horizontal = GROW_DIRECTION_BOTH
	add_child(p)
	window = p
	var col := TdMenu.vbox(16)
	p.add_child(col)
	var head := TdMenu.hbox(16)
	col.add_child(head)
	var title := TdMenu.label("Settings", "h2", TdTheme.color("cream.100"), 40)
	head.add_child(title)
	var spacer := Control.new() # no subtitle (Eren 2026-10-17: no explanations, "yapay zeka olduğunu belli eden şeyler")
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(spacer)
	var x := TdMenu.close_button()
	x.size_flags_vertical = SIZE_SHRINK_CENTER # its 52 px face, not stretched to the title row
	x.clicked.connect(close)
	head.add_child(x)
	var tabs_row := TdMenu.hbox(10)
	col.add_child(tabs_row)
	var icons := []
	for n in TAB_ICONS: icons.append(TdTheme.texture(n))
	tab_buttons = TdMenu.tabs(tabs_row, TABS, icons, Vector2((WIDTH - 48 - 30) / 4.0 - 22.0, 56), show_tab)
	if OS.has_feature("web"): tab_buttons[1].visible = false
	var well := TdMenu.panel(TdPanel.Kind.WELL, 18)
	col.add_child(well)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(0, PAGE_H) # one height for every tab (the tallest, Controls): nothing jumps
	well.add_child(stack)
	for page in [_audio_page(), _display_page(), _gameplay_page(), _controls_page()]:
		stack.add_child(page)
		pages.append(page)
	_chain_sliders.call_deferred() # once the pages are in the tree (paths between the sliders)
	# a footer row on every tab (same height everywhere, so nothing jumps): a hint line, and Reset on Controls
	var bottom := TdMenu.hbox(16)
	bottom.custom_minimum_size = Vector2(0, 56)
	col.add_child(bottom)
	_footer_hint = TdMenu.label("", "small", TdTheme.color("cream.300"), 20)
	_footer_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_footer_hint.size_flags_vertical = SIZE_SHRINK_CENTER
	bottom.add_child(_footer_hint)
	reset_button = Button.new()
	reset_button.theme_type_variation = "DangerButton"
	reset_button.text = "Reset to defaults"
	reset_button.custom_minimum_size = Vector2(300, 56)
	reset_button.focus_mode = FOCUS_NONE
	reset_button.pressed.connect(_on_reset)
	bottom.add_child(reset_button)
	show_tab(0)

var _footer_hint: Label
const FOOTER_HINTS := ["Drag a slider, or click it and use the arrow keys.", "The window size applies when not fullscreen.",
	"Gameplay settings apply at once, also during a battle.", "The mouse is fixed: left click selects, right click cancels."]

## Reset to defaults asks through the shared TdConfirm (was "Click again to reset"; Eren 2026-10-15), then resets
## every key.
func _on_reset() -> TdConfirm:
	return TdConfirm.ask(self, "Reset the controls?", "Every key goes back to its default.", "Reset",
		func(yes: bool): if yes: reset_controls(), {"danger": true})

func reset_controls() -> void:
	KeyBinds.reset_all()
	_stop_listening()
	refresh_controls()

func _on_open() -> void:
	refresh_all()

## Shows a tab (0 Audio, 1 Display, 2 Gameplay, 3 Controls).
func show_tab(i: int) -> void:
	if OS.has_feature("web") and i == 1: i = 0
	_stop_listening()
	current_tab = i
	# a slider of the page being left gives its keyboard focus back
	var fo := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if fo != null and is_ancestor_of(fo): fo.release_focus()
	for k in pages.size():
		pages[k].visible = k == i
		tab_buttons[k].selected = k == i
	reset_button.visible = i == 3
	_footer_hint.text = "" # no footer hints (Eren 2026-10-17)
	if i == 3: refresh_controls()

## Reads every control back from the settings.
func refresh_all() -> void:
	var s := SaveData.settings
	for n in _sliders:
		var v: float = s.get(n)
		_sliders[n][0].set_value_no_signal(roundf(v * 100.0))
		_sliders[n][1].text = str(int(roundf(v * 100.0)))
	for n in _toggles: _toggles[n].set_pressed_no_signal(bool(s.get(n)))
	_speed.set_value_no_signal(MenuLogic.speed_stage(s.game_speed))
	_speed_value.text = MenuLogic.speed_text(s.game_speed)
	_fill_resolutions()
	_fullscreen.set_pressed_no_signal(s.is_fullscreen)
	refresh_controls()

# ------------------------------------------------------------------ rows

func _page() -> VBoxContainer:
	var v := TdMenu.vbox(8)
	return v

func _row(page: Container, text: String, control: Control, sub := "") -> HBoxContainer:
	var row := TdMenu.hbox(16)
	row.custom_minimum_size = Vector2(0, 56)
	var labels := TdMenu.vbox(0)
	labels.size_flags_horizontal = SIZE_EXPAND_FILL
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	# the labels wrap inside the window's fixed width: a long sub line must never widen the panel (Eren 2026-10-14)
	var l := TdMenu.label(text, "body", TdTheme.color("cream.100"), 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(l)
	# the sub line is a tooltip on the row, not text under the label (Eren 2026-10-17: "açıklamalar tooltip olabilir";
	# the audio rows have none: sounds need no explaining)
	if sub != "": TdTooltipTrigger.attach(row).set_tooltip({"body": sub})
	row.add_child(labels)
	var holder := HBoxContainer.new()
	# sliders (with their value) take the full control column; a toggle or a dropdown only its own width, so the
	# label and its sub line get the rest of the row and stay on one line
	holder.custom_minimum_size = Vector2(CONTROL_W if control is HBoxContainer else 0.0, 0)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(control)
	row.add_child(holder)
	# two-tone rows (Eren 2026-10-15): wood and a slightly darker wood, alternating
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var base: Color = TdTheme.color("wood.800")
	sb.bg_color = base if page.get_child_count() % 2 == 0 else base.darkened(0.08)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 2; sb.content_margin_bottom = 2
	wrap.add_theme_stylebox_override("panel", sb)
	wrap.mouse_filter = MOUSE_FILTER_IGNORE
	wrap.add_child(row)
	page.add_child(wrap)
	return row

func _slider_row(page: Container, text: String, setting: String, setter: Callable, sub := "") -> void:
	var h := TdMenu.hbox(16)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 1
	sl.custom_minimum_size = Vector2(410, 40)
	sl.size_flags_vertical = SIZE_SHRINK_CENTER
	_keyboard_slider(sl)
	_full_track(sl)
	h.add_child(sl)
	var val := TdMenu.label("0", "header", TdTheme.color("cream.100"), 24)
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	sl.value_changed.connect(func(v):
		val.text = str(int(v))
		setter.call(v / 100.0))
	_sliders[setting] = [sl, val]
	_row(page, text, h, sub)

func _toggle_row(page: Container, text: String, setting: String, setter: Callable, sub := "") -> void:
	var t := CheckButton.new()
	t.focus_mode = FOCUS_NONE
	t.toggled.connect(func(on): setter.call(on))
	_toggles[setting] = t
	_row(page, text, t, sub)

func _audio_page() -> Control:
	var p := _page()
	_slider_row(p, "Master volume", "master_volume", func(v): SettingsMgr.set_master_volume(v))
	_slider_row(p, "Music volume", "music_volume", func(v): SettingsMgr.set_music_volume(v))
	_slider_row(p, "Sound effects", "sfx_volume", func(v): SettingsMgr.set_sfx_volume(v))
	_slider_row(p, "Other volume", "other_volume", func(v): SettingsMgr.set_other_volume(v))
	return p

func _display_page() -> Control:
	var p := _page()
	_resolution = OptionButton.new()
	_resolution.custom_minimum_size = Vector2(320, 52)
	_resolution.focus_mode = FOCUS_NONE
	_resolution.item_selected.connect(func(i):
		var r: Vector2i = _resolution.get_item_metadata(i)
		SettingsMgr.set_resolution(r.x, r.y, SaveData.settings.is_fullscreen))
	_row(p, "Window size", _resolution)
	_fullscreen = CheckButton.new()
	_fullscreen.focus_mode = FOCUS_NONE
	_fullscreen.toggled.connect(func(on):
		var s := SaveData.settings
		SettingsMgr.set_resolution(s.resolution_width, s.resolution_height, on))
	_row(p, "Fullscreen", _fullscreen)
	return p

func _fill_resolutions() -> void:
	_resolution.clear()
	var s := SaveData.settings
	var list: Array = SettingsMgr.resolutions()
	list.sort_custom(func(a, b): return a.x > b.x or (a.x == b.x and a.y > b.y))
	for r in list:
		_resolution.add_item("%d x %d" % [r.x, r.y])
		_resolution.set_item_metadata(_resolution.item_count - 1, r)
		if r == Vector2i(s.resolution_width, s.resolution_height): _resolution.select(_resolution.item_count - 1)

func _gameplay_page() -> Control:
	var p := _page()
	var h := TdMenu.hbox(16)
	_speed = HSlider.new()
	_speed.min_value = 0
	_speed.max_value = MenuLogic.GAME_SPEEDS.size() - 1
	_speed.step = 1
	_speed.tick_count = MenuLogic.GAME_SPEEDS.size()
	_speed.ticks_on_borders = true
	_speed.custom_minimum_size = Vector2(410, 40)
	_speed.size_flags_vertical = SIZE_SHRINK_CENTER
	_keyboard_slider(_speed)
	_full_track(_speed)
	h.add_child(_speed)
	_speed_value = TdMenu.label("1×", "header", TdTheme.color("cream.100"), 24)
	_speed_value.custom_minimum_size = Vector2(70, 0)
	_speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(_speed_value)
	_speed.value_changed.connect(func(v):
		var speed: float = MenuLogic.GAME_SPEEDS[clampi(int(v), 0, MenuLogic.GAME_SPEEDS.size() - 1)]
		_speed_value.text = MenuLogic.speed_text(speed)
		SettingsMgr.set_game_speed(speed))
	_row(p, "Game speed", h, "How fast moves and attacks play")
	_toggle_row(p, "Follow action", "follow_action", func(v): SettingsMgr.set_follow_action(v), "The camera follows whoever acts")
	_toggle_row(p, "Camera follows selection", "follow_selection", func(v): SettingsMgr.set_follow_selection(v), "The camera glides to the unit you select")
	_toggle_row(p, "Drag with the mouse", "drag_to_pan", func(v): SettingsMgr.set_drag_to_pan(v), "Hold the left button and move to pan the map")
	_toggle_row(p, "Instant playback", "instant_playback", func(v): SettingsMgr.set_instant_playback(v), "Skip every animation: results at once")
	_toggle_row(p, "Always show health", "always_show_health", func(v): SettingsMgr.set_always_show_health(v), "Health bars over every unit, not only hurt ones")
	return p

## A slider takes the keyboard focus when clicked (FOCUS_CLICK: the footer's "click it and use the arrow keys"),
## so Left / Right step it; it is never reached by Tab from outside the page (the window has no other focusable
## control). Focused: a thin accent ring round the slider, the kit's focus ring (no engine default outline).
func _keyboard_slider(sl: HSlider) -> void:
	sl.focus_mode = FOCUS_CLICK
	sl.add_theme_stylebox_override("focus", TdTheme.stylebox("focus_ring_r14", TdTheme.color("accent")))
	_page_sliders.append(sl)

## Tab / Shift+Tab and Up / Down move between the sliders of the page shown (wrapping), never out of the window
## (to the main menu's buttons behind the scrim).
func _chain_sliders() -> void:
	var by_page := {}
	for sl in _page_sliders:
		var page: Node = sl
		while page != null and not pages.has(page): page = page.get_parent()
		if page == null: continue
		if not by_page.has(page): by_page[page] = []
		by_page[page].append(sl)
	for page in by_page:
		var list: Array = by_page[page]
		for i in list.size():
			var me: HSlider = list[i]
			var nxt: HSlider = list[(i + 1) % list.size()]
			var prv: HSlider = list[(i - 1 + list.size()) % list.size()]
			me.focus_next = me.get_path_to(nxt)
			me.focus_previous = me.get_path_to(prv)
			me.focus_neighbor_bottom = me.get_path_to(nxt)
			me.focus_neighbor_top = me.get_path_to(prv)

var _page_sliders: Array = []

## The knob's centre reaches both ends of the track: the track spans the whole slider, the knob overhangs half its
## width at 0 and 100, and the fill runs to the knob's centre (no track showing past the knob, no gap at the end).
static func _full_track(sl: HSlider) -> void:
	sl.add_theme_constant_override("center_grabber", 1)
	sl.add_theme_constant_override("grabber_offset", 0)

# ------------------------------------------------------------------ controls

func _controls_page() -> Control:
	var outer := TdMenu.vbox(8)
	var head := TdMenu.hbox(16)
	var a := TdMenu.label("Action", "small", TdTheme.color("cream.300"))
	a.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(a)
	for t in ["Key", "Second key"]:
		var l := TdMenu.label(t, "small", TdTheme.color("cream.300"))
		l.custom_minimum_size = Vector2(200, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	head.add_child(TdMenu.spacer(0, 14))
	outer.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	TdDragScroll.attach(scroll)
	var list := TdMenu.vbox(6)
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	for r in MenuLogic.controls_rows(KeyBinds.actions, KeyBinds.modifier_actions):
		match r.kind:
			"header":
				if list.get_child_count() > 0: list.add_child(TdMenu.spacer(6))
				list.add_child(TdMenu.section_heading(r.label, 26))
			"modifier":
				var ob := OptionButton.new()
				ob.focus_mode = FOCUS_NONE
				ob.custom_minimum_size = Vector2(416, 48)
				for m in Modifiers.ALL: ob.add_item(MenuLogic.modifier_option(m))
				var id: String = r.id
				ob.item_selected.connect(func(i):
					KeyBinds.set_modifier(id, Modifiers.ALL[i])
					refresh_controls())
				modifier_rows.append([id, ob])
				list.add_child(_control_row(r.label, ob))
			"key":
				var h := TdMenu.hbox(16)
				for slot in 2:
					var b := _slot_button(r.id, slot)
					h.add_child(b)
				list.add_child(_control_row(r.label, h))
				var note := TdMenu.wrap_label("", "small", TdTheme.color("bad"), 20)
				note.visible = false
				list.add_child(note)
				_key_notes.append([r.id, note])
	# room under the last row: scrolled to the end, its key slots' rims (and the listening ring) are not cut
	list.add_child(TdMenu.spacer(12))
	return outer

func _control_row(text: String, control: Control) -> Control:
	var row := TdMenu.hbox(16)
	row.custom_minimum_size = Vector2(0, 52)
	var l := TdMenu.label(text, "body", TdTheme.color("cream.100"), 22)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(control)
	row.add_child(TdMenu.spacer(0, 6))
	return row

func _slot_button(id: String, slot: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 48)
	b.focus_mode = FOCUS_NONE
	b.add_theme_font_override("font", TdTheme.font("plinth"))
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func(): listen(id, slot))
	key_slots.append([id, slot, b])
	return b

## Clicking a slot waits for a key (clicking it again cancels).
func listen(id: String, slot: int) -> void:
	var same: bool = listening.size() == 2 and listening[0] == id and listening[1] == slot
	listening = [] if same else [id, slot]
	TdPopup.settings_capturing = not listening.is_empty()
	KeyBinds.block_keys = true
	refresh_controls()

func _stop_listening() -> void:
	if listening.is_empty(): return
	listening = []
	TdPopup.settings_capturing = false
	refresh_controls()

func _input(event: InputEvent) -> void:
	if listening.is_empty() or not is_open: return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_stop_listening()
		return
	var combo := KeyBinds.combo_from_event(event)
	if combo == null: return # a modifier alone: wait for the key
	KeyBinds.set_bind(listening[0], listening[1], combo)
	_stop_listening()

func back() -> void:
	if not listening.is_empty():
		_stop_listening()
		return
	close()

func close() -> void:
	_stop_listening()
	super.close()

## Every slot's key (red when bound twice, "Press a key..." while listening) and every dropdown's combination.
func refresh_controls() -> void:
	for k in key_slots:
		var id: String = k[0]
		var slot: int = k[1]
		var b: Button = k[2]
		var is_listening: bool = listening.size() == 2 and listening[0] == id and listening[1] == slot
		var combo := KeyBinds.get_bind(id, slot)
		var conflict: bool = not is_listening and KeyBinds.conflicts(id, slot)
		var sprite := "keyslot_listening" if is_listening else ("keyslot_conflict" if conflict else ("keyslot_empty" if combo.is_none else "keyslot_normal"))
		b.text = "Press a key..." if is_listening else ("Not set" if combo.is_none else KeyBinds.combo_text(combo))
		var col := Color.WHITE if is_listening else (TdTheme.color("bad.ink") if conflict else (TdTheme.color("cream.300") if combo.is_none else TdTheme.color("ink")))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var spr := sprite if st != "hover" or is_listening or conflict else "keyslot_hover"
			b.add_theme_stylebox_override(st, TdTheme.stylebox(spr, Color.WHITE, [8, 4, 8, 4]))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, col)
		b.icon = TdMenu.warn_icon() if conflict else null
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 20)
	for m in modifier_rows:
		m[1].select(Modifiers.ALL.find(KeyBinds.get_modifier(m[0])))
	# the message under the last row holding each key that is bound twice
	var last := {}   # key name -> note index
	for i in _key_notes.size():
		var id: String = _key_notes[i][0]
		for slot in 2:
			if KeyBinds.conflicts(id, slot): last[KeyBinds.combo_text(KeyBinds.get_bind(id, slot))] = i
	for n in _key_notes: n[1].visible = false
	for k in last:
		var note: Label = _key_notes[last[k]][1]
		var line := "%s is bound twice: both actions would happen. Click a red key to change it." % k
		note.text = line if not note.visible else note.text + "\n" + line
		note.visible = true
