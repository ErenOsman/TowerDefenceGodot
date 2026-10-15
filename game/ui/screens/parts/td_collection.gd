class_name TdCollection
extends HBoxContainer
## The tower collection of Hand select, shared by the hand editor and the Workshop picker (mockups hand-select,
## workshop-picker): left a well with search, Role / Delivery chips and the cost slider (with extras: the cost quick
## chips and the Heals / Applies statuses / Hide my hand toggles); centre a well with "37 towers", Sort and the grid of
## every owned tower (TdTowerTile: cost coin, portrait, form badge, name; in the hand editor the hand key). Filtering
## and sorting are HandLogic's. The screen owns the detail card beside it.
## Signals: `selected(id)` on a click, `activated(id)` on a double click. Set `entries` (HandLogic.entries), `hand`
## (for the keys and Hide my hand), then refresh().

signal selected(tower_id: String)
signal activated(tower_id: String)

## The cost quick chips and the three toggles (the hand editor; the Workshop picker has neither).
var extras := true
## Tiles show the hand's slot number and can be dragged onto hand slots.
var hand_keys := true
var columns := 6
## Tile size (TdTowerTile.SIZE / WIDE) and the grid's gap.
var tile_size := TdTowerTile.SIZE
var gap := 10
## Width of the filter column.
var filter_width := 248.0
## Whether the filter well is shown at all (hidden until Chapter 1 is cleared, Eren 2026-10-15: new players see only the grid).
var filters_shown := true

var entries: Array = []
var hand: Array = []
var filter := HandLogic.default_filter()
var sort := "number"
var selected_id := ""
## The pictures of the tiles: Callable(entry) → Texture2D (defaults to the type's portrait).
var picture_of: Callable = Callable()
## tower id → "" (rested) or its tired line (the hand editor: Missions & Guild tower energy); unset = never tired.
var tired_of: Callable = Callable()

var tiles := {}   # tower id → TdTowerTile
var shown: Array = []

var search: LineEdit
var count_label: Label
var sort_pick: OptionButton
var grid: GridContainer
var grid_scroll: ScrollContainer
var _role_chips := {}
var _deliv_chips := {}
var _cost_chips: Array = []
var _cost_value: Label
var _cost_slider: HSlider
var _toggles := {}
var _clear: Button
var _empty: VBoxContainer
var _syncing := false
var _built := false

func _init() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

## Builds the two wells (call once after setting extras / hand_keys; refresh() builds on first use too).
func build() -> void:
	if _built: return
	_built = true
	var filters_well := _build_filters()
	filters_well.visible = filters_shown
	add_child(filters_well)
	add_child(_build_grid())

func _build_filters() -> Control:
	var well := TdMenu.panel(TdPanel.Kind.WELL, 12)
	well.custom_minimum_size = Vector2(filter_width, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	# when it scrolls (the hand editor's longer list) the bar stood 4 px from the search field's rim (QA 2026-10-15)
	scroll.add_theme_constant_override("scrollbar_v_separation", 8)
	well.add_child(scroll)
	var v := TdMenu.vbox(8) # 8 px between the filter groups (they touched at 4)
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
	search = LineEdit.new()
	search.placeholder_text = "Search towers"
	search.size_flags_horizontal = SIZE_EXPAND_FILL
	search.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	search.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	TdTheme.apply_type(search, "body", TdTheme.color("ink"), 20)
	search.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	search.clear_button_enabled = true
	# its 4-character minimum (+ the clear icon) pushed the Workshop's filter well from 224 to 234 px (QA 2026-10-15)
	search.add_theme_constant_override("minimum_character_width", 0)
	# focus by a click only, and Enter gives the keys back: Tab used to park the caret here and every later Enter / arrow
	# went into the field (QA 2026-10-15: Workshop picker Enter stopped opening Modify)
	search.focus_mode = FOCUS_CLICK
	search.text_submitted.connect(func(_t: String): search.release_focus())
	search.text_changed.connect(func(t: String):
		filter.q = t
		refresh_grid())
	fh.add_child(search)
	# the field's paper rim hangs past its rect (sprite outset): room for it inside the scroll, which clips
	var rim := MarginContainer.new()
	var o: Array = TdTheme.sprite_outset("field_paper_normal")
	var sides := ["left", "top", "right", "bottom"]
	for i in 4: rim.add_theme_constant_override("margin_" + sides[i], int(ceil(float(o[i]) if o.size() > i else 0.0)))
	rim.add_child(field)
	v.add_child(rim)
	v.add_child(_heading("Role"))
	var roles := _flow()
	for r in HandLogic.ROLES:
		var c := chip(r, HandLogic.ROLE_COLORS[r])
		var role: String = r
		c.toggled.connect(func(_on): if not _syncing: HandLogic.toggle_in(filter.roles, role); refresh_filters(); refresh_grid())
		roles.add_child(c)
		_role_chips[r] = c
	v.add_child(roles)
	v.add_child(_heading("Delivery"))
	var dl := _flow()
	for d in HandLogic.DELIVERIES:
		var c := chip(d)
		var dv: String = d
		c.toggled.connect(func(_on): if not _syncing: HandLogic.toggle_in(filter.delivery, dv); refresh_filters(); refresh_grid())
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
		filter.cost_min = 0
		filter.cost_max = int(val)
		refresh_filters()
		refresh_grid())
	var sm := MarginContainer.new()
	# the knob overhangs the track by half its width at 0 and at the top: room so it never touches the well's rim
	sm.add_theme_constant_override("margin_left", 22)
	sm.add_theme_constant_override("margin_right", 22)
	sm.add_child(_cost_slider)
	v.add_child(sm)
	if not extras: return well
	var qc := _flow()
	for i in HandLogic.COST_CHIPS.size():
		var c := chip(HandLogic.COST_CHIPS[i][0])
		var k := i
		c.toggled.connect(func(_on): if not _syncing: HandLogic.toggle_cost_chip(filter, k); refresh_filters(); refresh_grid())
		qc.add_child(c)
		_cost_chips.append(c)
	v.add_child(qc)
	for pair in [["heal", "Heals"], ["status", "Applies statuses"], ["hide", "Hide my hand"]]:
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
		t.toggled.connect(func(on: bool): if not _syncing: filter[key] = on; refresh_filters(); refresh_grid())
		v.add_child(t)
		_toggles[key] = t
	return well

func _build_grid() -> Control:
	var well := TdMenu.panel(TdPanel.Kind.WELL, 12)
	well.size_flags_horizontal = SIZE_EXPAND_FILL
	var v := TdMenu.vbox(14) # the count / Sort row clear of the first row of tiles (and their hover lift)
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
	count_label = TdMenu.label("", "plate", TdTheme.color("cream.300"), 18)
	count_label.size_flags_vertical = SIZE_SHRINK_CENTER
	gh.add_child(count_label)
	var sl := TdMenu.label("Sort", "plate", TdTheme.color("cream.300"), 18)
	sl.size_flags_vertical = SIZE_SHRINK_CENTER
	gh.add_child(sl)
	sort_pick = OptionButton.new()
	for n in HandLogic.SORT_NAMES: sort_pick.add_item(n)
	sort_pick.focus_mode = FOCUS_NONE
	sort_pick.custom_minimum_size = Vector2(150, 42)
	sort_pick.add_theme_font_size_override("font_size", 18)
	sort_pick.item_selected.connect(func(i: int):
		sort = HandLogic.SORTS[i]
		refresh_grid())
	gh.add_child(sort_pick)
	grid_scroll = ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(grid_scroll)
	TdDragScroll.attach(grid_scroll) # drag empty space to scroll; a press on a draggable tile still drags the tile
	grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(grid)
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

func _heading(text: String) -> Label:
	return TdMenu.label(text, "header", TdTheme.color("cream.200"), 20)

func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	return f

static var _dots := {}

## A filter chip: a pill toggle (cobalt when on), with an optional colour dot.
static func chip(text: String, dot := Color(0, 0, 0, 0)) -> Button:
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

func refresh() -> void:
	build()
	refresh_filters()
	refresh_grid()

func refresh_filters() -> void:
	build()
	_syncing = true
	for r in _role_chips: _role_chips[r].button_pressed = filter.roles.has(r)
	for d in _deliv_chips: _deliv_chips[d].button_pressed = filter.delivery.has(d)
	for i in _cost_chips.size():
		var c: Array = HandLogic.COST_CHIPS[i]
		_cost_chips[i].button_pressed = filter.cost_min == c[1] and filter.cost_max == c[2]
	_cost_slider.value = filter.cost_max
	_cost_value.text = HandLogic.cost_text(filter)
	for k in _toggles: _toggles[k].button_pressed = bool(filter[k])
	if search.text != str(filter.q): search.text = str(filter.q)
	_syncing = false

func refresh_grid() -> void:
	build()
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	tiles.clear()
	shown = HandLogic.visible(entries, filter, hand, sort)
	for e in shown:
		var pic: Texture2D = picture_of.call(e) if picture_of.is_valid() else portrait(e.type)
		var t := TdTowerTile.make(e, pic, hand.find(e.id) if hand_keys else -1, tile_size)
		t.draggable = hand_keys
		t.set_selected(e.id == selected_id)
		if tired_of.is_valid(): t.set_tired(str(tired_of.call(e.id)))
		t.pressed.connect(select)
		t.double_pressed.connect(func(id: String): activated.emit(id))
		grid.add_child(t)
		tiles[e.id] = t
	count_label.text = HandLogic.count_text(shown.size(), entries.size())
	_clear.visible = HandLogic.filter_active(filter)
	_empty.visible = shown.is_empty()
	grid_scroll.visible = not shown.is_empty()

## Marks a tower selected (no grid rebuild: keeps the card under the pointer for a double click) and emits selected.
func select(id: String) -> void:
	selected_id = id
	for k in tiles: tiles[k].set_selected(k == id)
	selected.emit(id)

func clear_filters() -> void:
	filter = HandLogic.default_filter()
	refresh_filters()
	refresh_grid()

## Removes all children at once (a queued child would still count in a container for a frame).
static func clear_children(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

## A tower type's portrait (bust render, else its icon).
static func portrait(type: TowerAsset) -> Texture2D:
	if type == null: return null
	var view := type.entity.view if type.entity != null else ""
	return TdMenu.unit_picture(view, type.icon)

## The search field's magnifier.
class SearchGlyph extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := TdTheme.color("ink.2")
		draw_arc(Vector2(9, 9), 6.5, 0, TAU, 24, c, 2.5, true)
		draw_line(Vector2(14, 14), Vector2(20, 20), c, 3.0, true)
