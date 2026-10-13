extends TdPopup
## The hand editor = "Hand select" (UI Design Rules § Hand select; mockup ~/uiux/mockups/screens-b/hand-select.html,
## hand-select-level.html): a large window "Your hand 4 / 8" over the screen that opened it.
##  - Top: the 8 hand slots in order (slot number = the in-level key); drag to reorder, drag a piece out of the strip
##    (or its × on hover) to take it out, drop a collection card on a slot to put it there (on a filled slot it
##    replaces that tower). Before a level, a divider after the level's cap: "Two Roads takes the first 4".
##  - Beside it: 4 fixed layout tabs (rename only); the active one is the hand levels use; click one to load it.
##  - Left: search, Role / Delivery chips, cost slider + quick chips, toggles. Centre: every owned tower (each its
##    own card; sort Number / Name / Cost). Right: the selected tower's detail card and Add to hand / Remove.
## Everything saves as you go (TowerCollection + GameData.hand_layouts through SaveData.save()) and emits `changed`.
## Opened from level select (with its level: set `level`, or set_level_context(cap, name)), the Camp's Towers station
## and the co-op room. Esc / right click / × close it (TdPopup).

signal changed

## The level the hand is for (null: none, e.g. the Camp). Its hand cap and name give the divider and note.
var level: LevelAsset = null
## Overrides the level's cap when ≥ 0 (set_level_context).
var hand_cap := -1
## Overrides the level's name when not "".
var level_name := ""

const WIN := Vector2(1460, 864)
const GRID_COLUMNS := 6

var _filter := HandLogic.default_filter()
var _sort := "number"
var _selected := ""
var _entries: Array = []
var _renaming := -1
var _drag_hand_id := ""
var _msg_serial := 0

var _cap_label: RichTextLabel
var _msg: PanelContainer
var _msg_label: Label
var _tray: HBoxContainer
var _tray_panel: PanelContainer
var _layouts: GridContainer
var _search: LineEdit
var _role_chips := {}
var _deliv_chips := {}
var _cost_chips: Array = []
var _cost_value: Label
var _cost_slider: HSlider
var _toggles := {}
var _clear: Button
var _count: Label
var _sort_pick: OptionButton
var _grid: GridContainer
var _grid_scroll: ScrollContainer
var _empty: VBoxContainer
var _detail: VBoxContainer
var _tiles := {}   # tower id → TdTowerTile
var _slots: Array = []
var _syncing := false

## Before a level: the hand cap and the level's name for the divider and its note ("Two Roads takes the first 4").
func set_level_context(cap: int, name: String) -> void:
	hand_cap = cap
	level_name = name
	if is_open: refresh()

## The cap of the level it is opened for (0: none).
func cap() -> int:
	if hand_cap >= 0: return hand_cap
	return level.hand_cap if level != null else 0

func context_name() -> String:
	if level_name != "": return level_name
	return level.get_display_name() if level != null else ""

# ------------------------------------------------------------------ build

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 24)
	p.custom_minimum_size = WIN
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(10)
	p.add_child(col)
	col.add_child(_build_head())
	var top := TdMenu.hbox(16)
	col.add_child(top)
	top.add_child(_build_tray())
	_layouts = GridContainer.new()
	_layouts.columns = 2
	_layouts.add_theme_constant_override("h_separation", 8)
	_layouts.add_theme_constant_override("v_separation", 8)
	_layouts.size_flags_horizontal = SIZE_EXPAND_FILL
	_layouts.size_flags_vertical = SIZE_SHRINK_BEGIN
	top.add_child(_layouts)
	var body := TdMenu.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_build_filters())
	body.add_child(_build_grid())
	body.add_child(_build_detail())

func _build_head() -> Control:
	var head := TdMenu.hbox(14)
	head.add_child(TdMenu.label("Your hand", "h1", TdTheme.color("cream.100"), 44))
	_cap_label = TdMenu.rich("", "body", TdTheme.color("cream.300"), 28)
	_cap_label.add_theme_font_override("normal_font", TdTheme.font("plinth"))
	_cap_label.add_theme_font_override("bold_font", TdTheme.font("plinth"))
	_cap_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cap_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_cap_label.size_flags_vertical = SIZE_SHRINK_CENTER
	_cap_label.custom_minimum_size = Vector2(70, 0)
	head.add_child(_cap_label)
	var sub := TdMenu.label("Changes save as you go · drag to reorder, the key follows", "small", TdTheme.color("cream.300"), 20)
	sub.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(sub)
	_msg = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.067, 0.05, 0.75)
	sb.border_color = Color(TdTheme.color("gold"), 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 4; sb.content_margin_bottom = 4
	_msg.add_theme_stylebox_override("panel", sb)
	_msg.size_flags_vertical = SIZE_SHRINK_CENTER
	_msg.mouse_filter = MOUSE_FILTER_IGNORE
	var mh := TdMenu.hbox(8)
	_msg.add_child(mh)
	var warn := TdMenu.picture(TdMenu.warn_icon(), Vector2(22, 22))
	warn.size_flags_vertical = SIZE_SHRINK_CENTER
	mh.add_child(warn)
	_msg_label = TdMenu.label("", "plate", TdTheme.color("gold"), 20)
	mh.add_child(_msg_label)
	_msg.visible = false
	head.add_child(_msg)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(fill)
	var x := TdMenu.close_button()
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	return head

func _build_tray() -> Control:
	_tray_panel = PanelContainer.new()
	_tray_panel.add_theme_stylebox_override("panel", TdTheme.stylebox("hand_tray", Color.WHITE, [14, 28, 14, 4]))
	_tray_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	var drop := TrayDrop.new()
	drop.editor = self
	drop.add_theme_constant_override("separation", 8)
	_tray_panel.add_child(drop)
	_tray = drop
	return _tray_panel

func _build_filters() -> Control:
	var well := TdMenu.panel(TdPanel.Kind.WELL, 12)
	well.custom_minimum_size = Vector2(248, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	well.add_child(scroll)
	var v := TdMenu.vbox(4)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(v)
	# search
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", TdTheme.stylebox("field_paper_normal", Color.WHITE, [12, 2, 10, 2]))
	field.custom_minimum_size = Vector2(0, 46)
	var fh := TdMenu.hbox(8)
	field.add_child(fh)
	var glyph := SearchGlyph.new()
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.size_flags_vertical = SIZE_SHRINK_CENTER
	fh.add_child(glyph)
	_search = LineEdit.new()
	_search.placeholder_text = "Search towers"
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	_search.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_search.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	TdTheme.apply_type(_search, "body", TdTheme.color("ink"), 20)
	_search.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(t: String):
		_filter.q = t
		_refresh_grid())
	fh.add_child(_search)
	v.add_child(field)
	v.add_child(_heading("Role"))
	var roles := _flow()
	for r in HandLogic.ROLES:
		var c := _chip(r, HandLogic.ROLE_COLORS[r])
		var role: String = r
		c.toggled.connect(func(_on): if not _syncing: HandLogic.toggle_in(_filter.roles, role); _refresh_filters(); _refresh_grid())
		roles.add_child(c)
		_role_chips[r] = c
	v.add_child(roles)
	v.add_child(_heading("Delivery"))
	var dl := _flow()
	for d in HandLogic.DELIVERIES:
		var c := _chip(d)
		var dv: String = d
		c.toggled.connect(func(_on): if not _syncing: HandLogic.toggle_in(_filter.delivery, dv); _refresh_filters(); _refresh_grid())
		dl.add_child(c)
		_deliv_chips[d] = c
	v.add_child(dl)
	var ch := TdMenu.hbox(8)
	ch.add_child(_heading("Cost"))
	_cost_value = TdMenu.label("any", "plate", TdTheme.color("cream.300"), 18)
	_cost_value.size_flags_vertical = SIZE_SHRINK_END
	ch.add_child(_cost_value)
	v.add_child(ch)
	_cost_slider = HSlider.new()
	_cost_slider.min_value = 0
	_cost_slider.max_value = HandLogic.COST_ANY
	_cost_slider.step = 10
	_cost_slider.value = HandLogic.COST_ANY
	_cost_slider.focus_mode = FOCUS_NONE
	_cost_slider.custom_minimum_size = Vector2(0, 32)
	_cost_slider.add_theme_constant_override("center_grabber", 1)
	_cost_slider.add_theme_constant_override("grabber_offset", 0)
	_cost_slider.value_changed.connect(func(val: float):
		if _syncing: return
		_filter.cost_min = 0
		_filter.cost_max = int(val)
		_refresh_filters()
		_refresh_grid())
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 14)
	sm.add_theme_constant_override("margin_right", 14)
	sm.add_child(_cost_slider)
	v.add_child(sm)
	var qc := _flow()
	for i in HandLogic.COST_CHIPS.size():
		var c := _chip(HandLogic.COST_CHIPS[i][0])
		var k := i
		c.toggled.connect(func(_on): if not _syncing: HandLogic.toggle_cost_chip(_filter, k); _refresh_filters(); _refresh_grid())
		qc.add_child(c)
		_cost_chips.append(c)
	v.add_child(qc)
	for pair in [["move", "Can move"], ["heal", "Heals"], ["status", "Applies statuses"], ["hide", "Hide my hand"]]:
		var t := Button.new()
		t.text = pair[1]
		t.toggle_mode = true
		t.flat = true
		t.focus_mode = FOCUS_NONE
		t.alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.custom_minimum_size = Vector2(0, 30)
		t.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		t.icon = load("res://game/ui/theme/half/toggle_off.png")
		t.add_theme_constant_override("icon_max_width", 52)
		t.add_theme_constant_override("h_separation", 10)
		t.add_theme_font_override("font", TdTheme.font("nunito_bold"))
		t.add_theme_font_size_override("font_size", 18)
		for c in ["font_color", "font_focus_color"]: t.add_theme_color_override(c, TdTheme.color("cream.200"))
		for c in ["font_pressed_color", "font_hover_color", "font_hover_pressed_color"]: t.add_theme_color_override(c, TdTheme.color("cream.100"))
		for sbn in ["normal", "hover", "pressed", "hover_pressed", "focus"]: t.add_theme_stylebox_override(sbn, StyleBoxEmpty.new())
		t.toggled.connect(func(on: bool): t.icon = load("res://game/ui/theme/half/toggle_on.png" if on else "res://game/ui/theme/half/toggle_off.png"))
		var key: String = pair[0]
		t.toggled.connect(func(on: bool): if not _syncing: _filter[key] = on; _refresh_filters(); _refresh_grid())
		v.add_child(t)
		_toggles[key] = t
	return well

func _build_grid() -> Control:
	var well := TdMenu.panel(TdPanel.Kind.WELL, 12)
	well.size_flags_horizontal = SIZE_EXPAND_FILL
	var v := TdMenu.vbox(8)
	well.add_child(v)
	var gh := TdMenu.hbox(10)
	gh.custom_minimum_size = Vector2(0, 44)
	v.add_child(gh)
	_clear = Button.new()
	_clear.text = "Clear filters"
	_clear.flat = true
	_clear.focus_mode = FOCUS_NONE
	_clear.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_clear.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
	_clear.add_theme_font_size_override("font_size", 18)
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		_clear.add_theme_color_override(s, TdTheme.color("cream.200") if s == "font_color" else TdTheme.color("cream.100"))
	_clear.pressed.connect(clear_filters)
	gh.add_child(_clear)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	gh.add_child(fill)
	_count = TdMenu.label("", "plate", TdTheme.color("cream.300"), 18)
	_count.size_flags_vertical = SIZE_SHRINK_CENTER
	gh.add_child(_count)
	var sl := TdMenu.label("Sort", "plate", TdTheme.color("cream.300"), 18)
	sl.size_flags_vertical = SIZE_SHRINK_CENTER
	gh.add_child(sl)
	_sort_pick = OptionButton.new()
	for n in HandLogic.SORT_NAMES: _sort_pick.add_item(n)
	_sort_pick.focus_mode = FOCUS_NONE
	_sort_pick.custom_minimum_size = Vector2(150, 42)
	_sort_pick.add_theme_font_size_override("font_size", 18)
	_sort_pick.item_selected.connect(func(i: int):
		_sort = HandLogic.SORTS[i]
		_refresh_grid())
	gh.add_child(_sort_pick)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid_scroll.add_child(_grid)
	_empty = TdMenu.vbox(10)
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.size_flags_vertical = SIZE_EXPAND_FILL
	var e1 := TdMenu.label("No towers match.", "h3", TdTheme.color("cream.100"), 30)
	e1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(e1)
	var e2 := TdMenu.label("Try fewer filters.", "body", TdTheme.color("cream.200"), 20)
	e2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(e2)
	var eb := TdMenu.button(TdButton.Style.SECONDARY, "Clear filters", Vector2(240, 56), TdTheme.texture("icon_close"))
	eb.size_flags_horizontal = SIZE_SHRINK_CENTER
	eb.clicked.connect(clear_filters)
	_empty.add_child(eb)
	_empty.visible = false
	v.add_child(_empty)
	return well

func _build_detail() -> Control:
	var paper := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	paper.custom_minimum_size = Vector2(372, 0)
	_detail = TdMenu.vbox(10)
	paper.add_child(_detail)
	return paper

func _heading(text: String) -> Label:
	var l := TdMenu.label(text, "header", TdTheme.color("cream.200"), 20)
	return l

func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	return f

static var _dots := {}

## A filter chip: a pill toggle (cobalt when on), with an optional colour dot.
func _chip(text: String, dot := Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	b.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
	b.add_theme_font_size_override("font_size", 18)
	for s in ["font_color", "font_hover_color", "font_focus_color"]: b.add_theme_color_override(s, TdTheme.color("cream.100"))
	for s in ["font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(s, Color.WHITE)
	var base := StyleBoxFlat.new()
	base.bg_color = Color("#3A2C22")
	base.border_color = TdTheme.color("rim")
	base.set_border_width_all(2)
	base.set_corner_radius_all(17)
	base.content_margin_left = 10 if dot.a > 0 else 12
	base.content_margin_right = 12
	var hover: StyleBoxFlat = base.duplicate()
	hover.bg_color = Color("#4C3B2E")
	hover.border_color = Color("#8A7058")
	var on: StyleBoxFlat = base.duplicate()
	on.bg_color = TdTheme.color("accent.fill")
	on.border_color = TdTheme.color("accent.light")
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if dot.a > 0:
		b.icon = _dot(dot)
		b.add_theme_constant_override("h_separation", 6)
	return b

static func _dot(c: Color) -> Texture2D:
	var k := c.to_html()
	if _dots.has(k): return _dots[k]
	var n := 12
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(n, n) / 2.0)
			if d <= n / 2.0 - 0.5: img.set_pixel(x, y, c)
			elif d <= n / 2.0: img.set_pixel(x, y, Color(c, 0.5))
	_dots[k] = ImageTexture.create_from_image(img)
	return _dots[k]

# ------------------------------------------------------------------ refresh

func _on_open() -> void:
	SaveData.data.ensure_layouts()
	_entries = HandLogic.entries(SaveData.towers, GameApp.catalog, GameApp.convert)
	var hand: Array = SaveData.towers.hand
	if _selected == "" or SaveData.towers.find(_selected) == null:
		_selected = hand[0] if not hand.is_empty() else (_entries[0].id if not _entries.is_empty() else "")
	refresh(true)

## Redraws everything (pop: the hand pieces pop in).
func refresh(pop := false) -> void:
	_refresh_head()
	_refresh_tray(pop)
	_refresh_layouts()
	_refresh_filters()
	_refresh_grid()
	_refresh_detail()

func _refresh_head() -> void:
	_cap_label.text = "[color=%s]%d[/color] / %d" % [TdTheme.rich("cream.100"), SaveData.towers.hand.size(), TowerCollection.MaxHand]

func _refresh_tray(pop := false) -> void:
	for c in _tray.get_children():
		_tray.remove_child(c)
		c.queue_free()
	_slots.clear()
	var towers := SaveData.towers
	var c := cap()
	var note := HandLogic.cap_note(context_name(), c)
	var made := []
	for i in TowerCollection.MaxHand:
		if note != "" and i == c and c < TowerCollection.MaxHand: _tray.add_child(_divider(note))
		var s: TdHandSlot
		if i < towers.hand.size():
			var owned := towers.find(towers.hand[i])
			var type: TowerAsset = GameApp.catalog.find_tower(owned.type) if owned != null else null
			s = TdHandSlot.filled(i, owned, type, _miniature(type))
			s.set_selected(owned != null and owned.id == _selected)
			s.pressed.connect(_select)
			s.removed.connect(remove)
			s.drag_began.connect(func(id: String): _drag_hand_id = id)
			made.append(s)
		else:
			s = TdHandSlot.empty(i)
		s.set_late(note != "" and i >= c)
		s.dropped.connect(_on_drop)
		_tray.add_child(s)
		_slots.append(s)
	if pop: TdMenu.pop_in(made, 0.03)

## The divider at the level's cap, its note above it.
func _divider(note: String) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(26, TdHandSlot.SIZE.y)
	d.mouse_filter = MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = Color(TdTheme.color("cream.100"), 0.35)
	bar.position = Vector2(11, 6)
	bar.size = Vector2(3, TdHandSlot.SIZE.y - 6)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	d.add_child(bar)
	var l := TdMenu.label(note, "plate", TdTheme.color("cream.200"), 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 24)
	l.position = Vector2(13 - 160, -28)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	d.add_child(l)
	return d

func _refresh_layouts() -> void:
	for c in _layouts.get_children():
		_layouts.remove_child(c)
		c.queue_free()
	var data := SaveData.data
	data.ensure_layouts()
	for i in data.hand_layouts.size():
		_layouts.add_child(_layout_tab(i, data.hand_layouts[i], i == data.active_layout))

func _layout_tab(i: int, l: Dictionary, active: bool) -> Control:
	var tab := LayoutTab.new()
	tab.active = active
	tab.custom_minimum_size = Vector2(0, 58)
	tab.size_flags_horizontal = SIZE_EXPAND_FILL
	tab.tooltip_text = "Active: levels use this hand" if active else "Click to use this layout"
	tab.clicked.connect(func(): switch_layout(i))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_bottom", 4)
	m.mouse_filter = MOUSE_FILTER_IGNORE
	tab.add_child(m)
	var v := TdMenu.vbox(0)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	m.add_child(v)
	var top := TdMenu.hbox(6)
	top.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(top)
	if _renaming == i:
		var e := LineEdit.new()
		e.text = l.name
		e.max_length = HandLogic.NAME_MAX
		e.size_flags_horizontal = SIZE_EXPAND_FILL
		e.custom_minimum_size = Vector2(0, 24)
		e.add_theme_font_size_override("font_size", 18)
		var eb := StyleBoxFlat.new()
		eb.bg_color = TdTheme.color("paper")
		eb.border_color = TdTheme.color("accent.light")
		eb.set_border_width_all(2)
		eb.set_corner_radius_all(6)
		eb.content_margin_left = 6; eb.content_margin_right = 6; eb.content_margin_top = 0; eb.content_margin_bottom = 0
		e.add_theme_stylebox_override("normal", eb)
		e.add_theme_stylebox_override("focus", eb)
		e.text_submitted.connect(func(t: String): _commit_rename(i, t))
		e.focus_exited.connect(func(): if _renaming == i: _commit_rename(i, e.text))
		e.size_flags_vertical = SIZE_SHRINK_CENTER
		v.visible = false # the name field fills the tab while renaming
		m.add_child(e)
		e.ready.connect(func(): e.grab_focus(); e.select_all(), CONNECT_ONE_SHOT)
	else:
		var n := TdMenu.label(l.name, "micro", TdTheme.color("cream.100"), 18)
		n.size_flags_horizontal = SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.mouse_filter = MOUSE_FILTER_IGNORE
		top.add_child(n)
		var pen := Button.new()
		pen.icon = TdTheme.texture("icon_edit")
		pen.expand_icon = true
		pen.custom_minimum_size = Vector2(26, 26)
		pen.focus_mode = FOCUS_NONE
		pen.tooltip_text = "Rename"
		pen.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		var pb := StyleBoxFlat.new()
		pb.bg_color = Color(0.09, 0.067, 0.05, 0.6)
		pb.set_corner_radius_all(6)
		pb.content_margin_left = 4; pb.content_margin_right = 4; pb.content_margin_top = 4; pb.content_margin_bottom = 4
		pen.add_theme_stylebox_override("normal", pb)
		var ph: StyleBoxFlat = pb.duplicate()
		ph.bg_color = Color(0.09, 0.067, 0.05, 0.9)
		pen.add_theme_stylebox_override("hover", ph)
		pen.add_theme_stylebox_override("pressed", ph)
		pen.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		pen.pressed.connect(func(): _renaming = i; _refresh_layouts())
		top.add_child(pen)
	var bottom := TdMenu.hbox(3)
	bottom.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	var hand: Array = l.hand
	if hand.is_empty():
		bottom.add_child(TdMenu.label("Empty", "plate", TdTheme.color("cream.300"), 18))
	else:
		for k in mini(4, hand.size()):
			var o := SaveData.towers.find(hand[k])
			var type: TowerAsset = GameApp.catalog.find_tower(o.type) if o != null else null
			var med := TdMenu.medallion(_portrait(type), 22)
			med.size_flags_vertical = SIZE_SHRINK_CENTER
			bottom.add_child(med)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(fill)
	bottom.add_child(TdMenu.label(HandLogic.layout_count(hand), "micro", TdTheme.color("cream.200"), 18))
	return tab

func _refresh_filters() -> void:
	_syncing = true
	for r in _role_chips: _role_chips[r].button_pressed = _filter.roles.has(r)
	for d in _deliv_chips: _deliv_chips[d].button_pressed = _filter.delivery.has(d)
	for i in _cost_chips.size():
		var c: Array = HandLogic.COST_CHIPS[i]
		_cost_chips[i].button_pressed = _filter.cost_min == c[1] and _filter.cost_max == c[2]
	_cost_slider.value = _filter.cost_max
	_cost_value.text = HandLogic.cost_text(_filter)
	for k in _toggles: _toggles[k].button_pressed = bool(_filter[k])
	if _search.text != str(_filter.q): _search.text = str(_filter.q)
	_syncing = false

func _refresh_grid() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_tiles.clear()
	var hand: Array = SaveData.towers.hand
	var shown := HandLogic.visible(_entries, _filter, hand, _sort)
	for e in shown:
		var t := TdTowerTile.make(e, _portrait(e.type), hand.find(e.id))
		t.set_selected(e.id == _selected)
		t.pressed.connect(_select)
		t.double_pressed.connect(toggle)
		_grid.add_child(t)
		_tiles[e.id] = t
	_count.text = HandLogic.count_text(shown.size(), _entries.size())
	_clear.visible = HandLogic.filter_active(_filter)
	_empty.visible = shown.is_empty()
	_grid_scroll.visible = not shown.is_empty()

func _refresh_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var e := _entry(_selected)
	if e.is_empty():
		var l := TdMenu.wrap_label("Select a tower to see its details.", "body", TdTheme.color("ink.2"), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_vertical = SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_detail.add_child(l)
		return
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 10)
	var n := TdMenu.label(e.name, "h2", TdTheme.color("accent.ink"), 32)
	head.add_child(n)
	var num := TdMenu.label(HandLogic.number_text(e), "micro", TdTheme.color("ink.2"), 18)
	num.size_flags_vertical = SIZE_SHRINK_END
	head.add_child(num)
	_detail.add_child(head)
	var cost := TdMenu.rich("[img=20x20 color=%s]%s[/img] [font_size=22][color=%s]%d[/color][/font_size] energy" % [TdTheme.rich("gold.ink"),
		TdTheme.texture("icon_energy").resource_path, TdTheme.rich("gold.ink"), e.cost], "small", TdTheme.color("ink.2"), 18)
	_detail.add_child(cost)
	var type: TowerAsset = e.type
	var desc := type.description if type != null else ""
	if desc == "" and type != null and type.entity != null: desc = type.entity.description
	if desc != "": _detail.add_child(TdMenu.rich(TooltipText.describe(desc), "body", TdTheme.color("ink"), 18))
	var def: EntityDef = e.def
	var vocab: Vocabulary = GameApp.rules.vocabulary if GameApp.rules != null else null
	var me: IEntity = DefStats.new(def) if def != null else null
	if me != null and vocab != null:
		var tiles := GridContainer.new()
		tiles.columns = 2
		tiles.add_theme_constant_override("h_separation", 6)
		tiles.add_theme_constant_override("v_separation", 6)
		for t in HandLogic.stat_tiles(me, vocab): tiles.add_child(_stat_tile(t[0], t[1], t[2]))
		_detail.add_child(tiles)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_detail.add_child(scroll)
	var rows := TdMenu.vbox(0)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(rows)
	if def != null:
		for ab in def.abilities:
			var asset = GameApp.convert.asset_of(ab, "AbilityAsset")
			var icon: Texture2D = TdTheme.ability_icon(MenuLogic.icon_name(asset.icon)) if asset != null and asset.icon != "" else null
			var pills := []
			if me != null and vocab != null:
				for r in AbilityText.tags(ab, me, vocab): pills.append([str(r[0]), MenuLogic.result_name(str(r[1]))])
			rows.add_child(_ability_row(icon, ab.display_name, HandLogic.ability_subtitle(ab.tags, ab.cooldown, ab.cooldown_until_reset), pills, "", false))
		for pv in PassiveView.of(def):
			var asset = GameApp.convert.asset_of(pv.def, "PassiveAsset")
			var icon: Texture2D = GameApp.icon_texture(asset.icon) if asset != null and asset.icon != "" else null
			rows.add_child(_ability_row(icon, pv.name, "Passive · always on", [], TooltipText.describe(pv.def.description), true))
	# the action
	var foot := TdMenu.vbox(6)
	_detail.add_child(foot)
	var towers := SaveData.towers
	var at := towers.hand.find(e.id)
	if at >= 0:
		foot.add_child(TdMenu.label("In your hand · key %d" % (at + 1), "plate", TdTheme.color("good.ink"), 18))
		var b := TdMenu.button(TdButton.Style.SECONDARY, "Remove from hand", Vector2(340, 58), TdTheme.texture("icon_close"))
		var id: String = e.id
		b.clicked.connect(func(): remove(id))
		foot.add_child(b)
	else:
		var reason := HandLogic.add_reason(towers, e.id)
		if reason != "":
			var why := TdMenu.hbox(6)
			var w := TdMenu.picture(TdMenu.warn_icon(), Vector2(20, 20))
			w.size_flags_vertical = SIZE_SHRINK_CENTER
			why.add_child(w)
			var wl := TdMenu.wrap_label(reason, "plate", TdTheme.color("gold.ink"), 18)
			wl.custom_minimum_size = Vector2(300, 0)
			why.add_child(wl)
			foot.add_child(why)
		var b := TdMenu.button(TdButton.Style.PRIMARY, "Add to hand", Vector2(340, 58), TdTheme.texture("icon_plus"))
		if reason != "": b.set_interactable(false, reason)
		var id: String = e.id
		b.clicked.connect(func(): add(id))
		foot.add_child(b)

const STAT_ICONS := {"MaxHp": "icon_heart", "Power": "icon_power", "Potency": "icon_del-spark", "Duration": "icon_clock",
	"Speed": "icon_speed", "Range": "icon_range", "Radius": "icon_range"}

func _stat_tile(stat: String, label: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TdTheme.stylebox("paper_stat", Color.WHITE, [8, 2, 8, 2]))
	p.custom_minimum_size = Vector2(167, 44)
	p.size_flags_horizontal = SIZE_EXPAND_FILL
	var h := TdMenu.hbox(6)
	p.add_child(h)
	var ic := TdMenu.picture(TdTheme.texture(STAT_ICONS.get(stat, "icon_power")), Vector2(18, 18))
	ic.modulate = TdTheme.color("bad.ink") if stat == "MaxHp" else TdTheme.color("ink.2")
	ic.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := TdMenu.label(value, "header", TdTheme.color("ink"), 22)
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(v)
	var l := TdMenu.label(label, "small", TdTheme.color("ink.2"), 18)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	l.clip_text = true
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(l)
	return p

func _ability_row(icon: Texture2D, name_text: String, sub: String, pills: Array, text: String, passive: bool) -> Control:
	var box := TdMenu.vbox(0)
	var line := DashLine.new()
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	box.add_child(m)
	var h := TdMenu.hbox(10)
	m.add_child(h)
	if passive:
		var med := TdMenu.medallion(icon, 42)
		med.size_flags_vertical = SIZE_SHRINK_BEGIN
		h.add_child(med)
	else:
		var ic := TdMenu.picture(icon, Vector2(44, 44))
		ic.size_flags_vertical = SIZE_SHRINK_BEGIN
		h.add_child(ic)
	var v := TdMenu.vbox(2)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(TdMenu.label(name_text, "header", TdTheme.color("ink"), 20))
	var s := TdMenu.wrap_label(sub, "small", TdTheme.color("ink.2"), 18)
	v.add_child(s)
	if text != "": v.add_child(TdMenu.rich(text, "body", TdTheme.color("ink"), 18))
	if not pills.is_empty():
		var f := HFlowContainer.new()
		f.add_theme_constant_override("h_separation", 6)
		f.add_theme_constant_override("v_separation", 4)
		for p in pills:
			f.add_child(TdMenu.pill("[font=%s]%s[/font] %s" % [TdTheme.font("plinth").resource_path, p[0], p[1]],
				Color(0, 0, 0, 0), TdTheme.color("ink.2"), 18, Color(TdTheme.color("ink.2"), 0.45)))
		v.add_child(f)
	return box

# ------------------------------------------------------------------ actions

func _entry(id: String) -> Dictionary:
	for e in _entries:
		if e.id == id: return e
	return {}

## Shows a tower's details (no grid rebuild: keeps the card under the pointer for a double click).
func _select(id: String) -> void:
	_selected = id
	for k in _tiles: _tiles[k].set_selected(k == id)
	for s in _slots: s.set_selected(s.tower_id != "" and s.tower_id == id)
	_refresh_detail()

## Adds a tower at the end of the hand (says why not when it cannot).
func add(id: String) -> bool:
	var reason := HandLogic.add_reason(SaveData.towers, id)
	if reason != "":
		_say(reason)
		_shake_tray()
		return false
	if not HandLogic.add(SaveData.towers, id): return false
	_selected = id
	_hand_changed()
	return true

## Takes a tower out of the hand.
func remove(id: String) -> bool:
	if not HandLogic.remove(SaveData.towers, id): return false
	_hand_changed()
	return true

## Double-click: in or out of the hand.
func toggle(id: String) -> void:
	_selected = id
	if SaveData.towers.hand.has(id): remove(id)
	else: add(id)

## A tower dropped on a hand slot (see HandLogic.drop_on_slot).
func drop_on_slot(id: String, slot: int) -> bool:
	if not SaveData.towers.hand.has(id) and slot >= SaveData.towers.hand.size():
		return add(id)
	if not HandLogic.drop_on_slot(SaveData.towers, id, slot): return false
	_selected = id
	_hand_changed()
	return true

func _on_drop(data: Dictionary, slot: int) -> void:
	_drag_hand_id = ""
	drop_on_slot(str(data.get("id", "")), slot)

## A drag dropped on the strip but not on a slot: a collection card goes to the end; a hand piece stays.
func _on_tray_drop(data: Dictionary) -> void:
	_drag_hand_id = ""
	if data.get("kind", "") == "grid": add(str(data.get("id", "")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_hand_id != "":
		var id := _drag_hand_id
		_drag_hand_id = ""
		# a hand piece dropped outside the strip: out of the hand
		if is_open and not get_viewport().gui_is_drag_successful(): remove(id)

## Loads layout i (the current hand stays saved in the active one).
func switch_layout(i: int) -> void:
	if _renaming >= 0: return
	if not HandLogic.switch_layout(SaveData.data, i): return
	var hand: Array = SaveData.towers.hand
	if not hand.is_empty() and not hand.has(_selected): _selected = hand[0]
	_hand_changed(true)

func _commit_rename(i: int, text: String) -> void:
	_renaming = -1
	if HandLogic.rename_layout(SaveData.data, i, text): SaveData.save()
	_refresh_layouts.call_deferred()

func clear_filters() -> void:
	_filter = HandLogic.default_filter()
	_refresh_filters()
	_refresh_grid()

func _hand_changed(pop := false) -> void:
	HandLogic.sync_layout(SaveData.data)
	SaveData.save()
	_refresh_head()
	_refresh_tray(pop)
	_refresh_layouts()
	_refresh_grid()
	_refresh_detail()
	changed.emit()

func _say(text: String) -> void:
	_msg_label.text = text
	_msg.visible = true
	_msg_serial += 1
	var serial := _msg_serial
	get_tree().create_timer(2.6, true, false, true).timeout.connect(func():
		if serial == _msg_serial and is_instance_valid(_msg): _msg.visible = false)

func _shake_tray() -> void:
	var tw := TdTheme.tween(_tray)
	for dx in [-7.0, 7.0, -4.0, 4.0, 0.0]:
		tw.tween_property(_tray, "position:x", dx, 0.05)

## Esc / right click: first cancels a rename, then closes.
func back() -> void:
	if _renaming >= 0:
		_renaming = -1
		_refresh_layouts()
		return
	close()

func _miniature(type: TowerAsset) -> Texture2D:
	if type == null or type.entity == null: return null
	var t: Texture2D = GameApp.icon_texture(type.entity.miniature) if type.entity.miniature != "" else null
	return t if t != null else _portrait(type)

func _portrait(type: TowerAsset) -> Texture2D:
	if type == null: return null
	var view := type.entity.view if type.entity != null else ""
	return TdMenu.unit_picture(view, type.icon)

# ------------------------------------------------------------------ small parts

## The hand strip: also takes drops between slots.
class TrayDrop extends HBoxContainer:
	var editor
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["hand", "grid"]
	func _drop_data(_at: Vector2, data: Variant) -> void:
		editor._on_tray_drop(data)

## A layout tab: wood (cobalt outline when active), click to load.
class LayoutTab extends Control:
	signal clicked
	var active := false
	var _hover := false
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		if active:
			sb.bg_color = Color("#303A52")
			sb.border_color = TdTheme.color("accent.light")
			sb.set_border_width_all(3)
		else:
			sb.bg_color = Color("#5E4A3A") if _hover else Color("#4A3A2E")
			sb.border_color = TdTheme.color("rim")
			sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
				and Rect2(Vector2.ZERO, size).has_point(event.position):
			clicked.emit()

## The search field's magnifier.
class SearchGlyph extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := TdTheme.color("ink.2")
		draw_arc(Vector2(9, 9), 6.5, 0, TAU, 24, c, 2.5, true)
		draw_line(Vector2(14, 14), Vector2(20, 20), c, 3.0, true)

## The dashed rule between ability rows.
class DashLine extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_dashed_line(Vector2(0, 1), Vector2(size.x, 1), Color(TdTheme.color("ink.2"), 0.3), 2.0, 6.0)
