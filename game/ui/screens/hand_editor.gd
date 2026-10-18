extends TdPopup
## The hand editor = "Hand select" (UI Design Rules § Hand select; mockup ~/uiux/mockups/screens-b/hand-select.html,
## hand-select-level.html): a large window "Your hand 4 / 8" over the screen that opened it.
##  - Top: the 8 hand slots in order (slot number = the in-level key); drag to reorder, drag a piece out of the strip
##    (or its × on hover) to take it out, drop a collection card on a slot to put it there (on a filled slot it
##    replaces that tower). Before a level, a divider bar at the level's cap (no note: Eren 2026-10-17). Adding or
##    removing a tower never changes the window's size or layout (fixed strip and header; nothing appears in them).
##  - Beside it: 4 fixed layout tabs (rename only); the active one is the hand levels use; click one to load it.
##  - Centre: a bar with Filters (a button with the count of set filters; it opens the Role / Delivery / Cost / toggle
##    filters in a small popup), the search and Sort (Default (the hidden release number) / Name / Cost), then every
##    owned tower over the full width (each its own card). Right: the selected tower's detail card ("Drummer #2") and
##    Add to hand / Remove. No instruction texts (UI Design Rules "No explanations in everyday places").
## Everything saves as you go (TowerCollection + GameData.hand_layouts through SaveData.save()) and emits `changed`.
## Opened from level select (with its level: set `level`, or set_level_context(cap, name)), the Camp's Towers station
## and the co-op room. Esc / right click / × close it (TdPopup).
## Missions & Guild (mockup hand-select-mission): towers that went on a mission today are dimmed with the moon badge
## (in the strip and the collection; the tooltip says when they rest). Opened for a mission (`mission` set, from the
## mission detail), the strip shows only the hand's rested towers (MissionUiLogic.rested_hand: the ones the mission can
## take; key = place in that strip), the divider bar at the cap.

signal changed

## The level the hand is for (null: none, e.g. the Camp). Its hand cap and name give the divider and note.
var level: LevelAsset = null
## Overrides the level's cap when ≥ 0 (set_level_context).
var hand_cap := -1
## Overrides the level's name when not "".
var level_name := ""
## The mission the hand is for (null: none): the strip shows only the hand's rested towers.
var mission: MissionDef = null

const WIN := Vector2(1460, 864)
## The grid has the window's full width (the filters are in a popup): 8 tiles of 108 px.
const GRID_COLUMNS := 8
## The header row's fixed height (the title; the hand-full message appears in it without moving anything).
const HEAD_H := 56.0

var _selected := ""
var _entries: Array = []
var _renaming := -1
var _rename_edit: LineEdit = null
var _drag_hand_id := ""
var _msg_serial := 0

var _cap_label: RichTextLabel
var _msg: PanelContainer
var _msg_label: Label
var _tray: HBoxContainer
var _tray_panel: PanelContainer
var _layouts: GridContainer
## The collection (filters + grid), shared with the Workshop picker.
var collection: TdCollection
var _detail: VBoxContainer
var _slots: Array = []

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
	_layouts.visible = GameApp.camp_unlocked() # no layouts until Chapter 1 is cleared (Eren 2026-10-15)
	var body := TdMenu.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(body)
	collection = TdCollection.new()
	collection.filters_shown = GameApp.camp_unlocked() # no filters until Chapter 1 is cleared (Eren 2026-10-15)
	collection.filters_popup = true # a Filters button + popup, the grid over the full width (Eren 2026-10-17)
	collection.extras = true
	collection.hand_keys = true
	collection.columns = GRID_COLUMNS
	collection.tired_of = func(id: String) -> String: return MissionUiLogic.tired_line(null, false) if MissionBoard.is_tired(id, SaveData.missions) else ""
	collection.build()
	collection.selected.connect(_select)
	collection.activated.connect(toggle)
	body.add_child(collection)
	body.add_child(_build_detail())

func _build_head() -> Control:
	var head := TdMenu.hbox(14)
	head.custom_minimum_size = Vector2(0, HEAD_H)
	head.add_child(TdMenu.label("Your hand", "h1", TdTheme.color("cream.100"), 44))
	_cap_label = TdMenu.rich("", "body", TdTheme.color("cream.300"), 28)
	_cap_label.add_theme_font_override("normal_font", TdTheme.font("plinth"))
	_cap_label.add_theme_font_override("bold_font", TdTheme.font("plinth"))
	_cap_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cap_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_cap_label.size_flags_vertical = SIZE_SHRINK_CENTER
	_cap_label.custom_minimum_size = Vector2(70, 0)
	head.add_child(_cap_label)
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
	x.size_flags_vertical = SIZE_SHRINK_CENTER # its 52 px face, not stretched to the title row
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	return head

## The strip's padding (left, top, right, bottom): fixed, nothing appears above or under the slots.
const TRAY_PAD := [14, 12, 14, 4]

func _build_tray() -> Control:
	_tray_panel = PanelContainer.new()
	_tray_panel.add_theme_stylebox_override("panel", TdTheme.stylebox("hand_tray", Color.WHITE, TRAY_PAD))
	_tray_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	var drop := TrayDrop.new()
	drop.editor = self
	drop.add_theme_constant_override("separation", 8)
	_tray_panel.add_child(drop)
	_tray = drop
	return _tray_panel

func _build_detail() -> Control:
	var paper := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	paper.custom_minimum_size = Vector2(372, 0)
	_detail = TdMenu.vbox(10)
	paper.add_child(_detail)
	return paper

# ------------------------------------------------------------------ refresh

func _on_open() -> void:
	SaveData.data.ensure_layouts()
	_entries = HandLogic.entries(SaveData.towers, GameApp.catalog, GameApp.convert)
	# every tower in the collection is discovered in the Codex (owned; Eren 2026-10-17)
	if GameApp.catalog != null and MenuLogic.discover_owned(SaveData.codex, SaveData.towers, GameApp.catalog): SaveData.save()
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
	var ids := strip_ids()
	# the divider bar stands at the cap whatever the hand holds: the strip never changes width (Eren 2026-10-17)
	var cut := HandLogic.divider_slot(cap())
	var made := []
	for i in TowerCollection.MaxHand:
		if i == cut: _tray.add_child(_divider())
		var s: TdHandSlot
		if i < ids.size():
			var owned := towers.find(ids[i])
			var type: TowerAsset = GameApp.catalog.find_tower(owned.type) if owned != null else null
			s = TdHandSlot.filled(i, owned, type, _miniature(type))
			s.set_selected(owned != null and owned.id == _selected)
			s.pressed.connect(_select)
			s.removed.connect(remove)
			s.drag_began.connect(func(id: String): _drag_hand_id = id)
			if mission == null and MissionBoard.is_tired(str(ids[i]), SaveData.missions): s.set_tired(MissionUiLogic.tired_line(null, false))
			made.append(s)
		else:
			s = TdHandSlot.empty(i)
		s.set_late(cut >= 0 and i >= cut and not s.tired)
		s.dropped.connect(_on_drop)
		_tray.add_child(s)
		_slots.append(s)
	if pop: TdMenu.pop_in(made, 0.03)

## The towers the strip shows, in order: the hand; opened for a mission, only its rested towers (Eren 2026-10-17).
func strip_ids() -> Array:
	var hand: Array = SaveData.towers.hand
	return MissionUiLogic.rested_hand(hand, SaveData.missions) if mission != null else hand

## The hand index a drop on strip slot `slot` means (the mission strip skips tired towers).
func _hand_slot(slot: int) -> int:
	if mission == null: return slot
	return MissionUiLogic.strip_to_hand_slot(SaveData.towers.hand, strip_ids(), slot)

## The divider bar at the level's cap (no note).
func _divider() -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(26, TdHandSlot.SIZE.y)
	d.mouse_filter = MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = Color(TdTheme.color("cream.100"), 0.35)
	bar.position = Vector2(11, 6)
	bar.size = Vector2(3, TdHandSlot.SIZE.y - 6)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	d.add_child(bar)
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
	tab.custom_minimum_size = Vector2(0, 46)
	tab.size_flags_horizontal = SIZE_EXPAND_FILL
	tab.tooltip_text = str(l.name) # the full name (the tab trims a long one)
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
	v.alignment = BoxContainer.ALIGNMENT_CENTER # the tab holds only the layout's name and its rename pencil
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
		# leaving the field (focus lost, or a click anywhere else: see _input) commits too; Esc cancels
		e.focus_exited.connect(func(): if _renaming == i: _commit_rename(i, e.text))
		e.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				e.accept_event()
				cancel_rename())
		_rename_edit = e
		e.size_flags_vertical = SIZE_SHRINK_CENTER
		v.visible = false # the name field fills the tab while renaming
		m.add_theme_constant_override("margin_top", 0) # the field's line height fits the 46 px tab
		m.add_theme_constant_override("margin_bottom", 0)
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
	return tab

func _refresh_filters() -> void:
	collection.refresh_filters()

func _refresh_grid() -> void:
	collection.entries = _entries
	collection.hand = strip_ids() # the keys the strip shows (a mission's strip: rested towers only)
	collection.selected_id = _selected
	collection.refresh_grid()

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
	# everything above the action scrolls (a tower with many stats or abilities)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_detail.add_child(scroll)
	TdDragScroll.attach(scroll, true) # mouse drag scrolls it too
	var gutter := MarginContainer.new()
	# no extra gutter: the ScrollContainer already counts its scrollbar in its width (a 14 px gutter on top made the
	# 372 px card grow to 386 px)
	gutter.add_theme_constant_override("margin_right", 6) # the tiles' rims stay clear of the scrollbar
	gutter.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(gutter)
	var body := TdMenu.vbox(10)
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	gutter.add_child(body)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 10)
	var n := TdMenu.label(HandLogic.entry_name(e), "h2", TdTheme.color("accent.ink"), 32) # "Drummer #2"
	head.add_child(n)
	body.add_child(head)
	var cost := TdMenu.rich("[img=20x20 color=%s]%s[/img] [font_size=22][color=%s]%d[/color][/font_size] energy" % [TdTheme.rich("gold.ink"),
		TdTheme.texture("icon_energy").resource_path, TdTheme.rich("gold.ink"), e.cost], "small", TdTheme.color("ink.2"), 18)
	body.add_child(cost)
	var desc: String = e.get("description", "")
	if desc != "": body.add_child(TdMenu.rich(TooltipText.describe(desc), "body", TdTheme.color("ink"), 18))
	var def: EntityDef = e.def
	var vocab: Vocabulary = GameApp.rules.vocabulary if GameApp.rules != null else null
	var me: IEntity = DefStats.new(def) if def != null else null
	if me != null and vocab != null: body.add_child(TdTowerCard.stat_grid(HandLogic.stat_tiles(me, vocab), 120)) # tiles fit beside the scrollbar (158 px pushed them under it)
	var rows := TdMenu.vbox(0)
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(rows)
	for r in TdTowerCard.def_rows(def, vocab): rows.add_child(r)
	# the action
	var foot := TdMenu.vbox(6)
	_detail.add_child(foot)
	var towers := SaveData.towers
	var at := towers.hand.find(e.id)
	if at >= 0:
		var b := TdMenu.button(TdButton.Style.SECONDARY, "Remove from hand", _action_size(TdButton.Style.SECONDARY), TdTheme.texture("icon_close"))
		b.font_size = 24 # at the default size the label ran to ~8 px of the rims in the fixed-width card (QA 2026-10-15)
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
		var b := TdMenu.button(TdButton.Style.PRIMARY, "Add to hand", _action_size(TdButton.Style.PRIMARY), TdTheme.texture("icon_plus"))
		if reason != "": b.set_interactable(false, reason)
		var id: String = e.id
		b.clicked.connect(func(): add(id))
		foot.add_child(b)

## The detail card's action button: the card's 340 px inside, less the button's bleed room (its rim and hover
## growth), so the 372 px card never grows wider (it did, to 390-402 px, squeezing the grid).
static func _action_size(style: int) -> Vector2:
	var b := TdButton.bleed_for(style, Vector2(340, 58))
	return Vector2(340.0 - b.x - b.z, 58)

# ------------------------------------------------------------------ actions

func _entry(id: String) -> Dictionary:
	for e in _entries:
		if e.id == id: return e
	return {}

## Shows a tower's details (no grid rebuild: keeps the card under the pointer for a double click).
func _select(id: String) -> void:
	_selected = id
	if collection.selected_id != id:
		collection.selected_id = id
		for k in collection.tiles: collection.tiles[k].set_selected(k == id)
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
func drop_on_slot(id: String, strip_slot: int) -> bool:
	var slot := _hand_slot(strip_slot)
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
	if _renaming != i: return
	_renaming = -1
	_rename_edit = null
	if HandLogic.rename_layout(SaveData.data, i, text): SaveData.save()
	_refresh_layouts.call_deferred()

func clear_filters() -> void:
	collection.clear_filters()

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
		cancel_rename()
		return
	close()

## Esc while renaming: the old name stays.
func cancel_rename() -> void:
	if _renaming < 0: return
	_renaming = -1
	_rename_edit = null
	_refresh_layouts.call_deferred()

## A click outside the name field while renaming commits it (a click on a non-focusable control would not take
## the focus away, so focus_exited alone is not enough).
func _input(event: InputEvent) -> void:
	if _renaming < 0 or not is_open or not (event is InputEventMouseButton) or not event.pressed: return
	if _rename_edit != null and is_instance_valid(_rename_edit) and not _rename_edit.get_global_rect().has_point(event.position):
		_commit_rename(_renaming, _rename_edit.text)

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
