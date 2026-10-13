class_name CoopLobby
extends TdPopup
## The co-op lobby (mockups lobby-list / -empty / -offline): "Co-op" with the connection pill, search, Show full
## rooms, Refresh, Create room; the room list (lock or Open, level thumbnail, name + level, host, players n/count,
## state) and the selected room's level card with Join. Offline: "Can't reach the server." with Retry and Offline
## practice. Opened from the Camp's Multiplayer station; connects Net to the relay when opened. Child popups: create
## room, join (password), the room screen (when you are in a room). Back closes it (and leaves the connection idle).

var net: Node = null   # the Net autoload (RelayClient), or a test's client

var _status: PanelContainer
var _search: LineEdit
var _show_full: CheckButton
var _create: TdButton
var _list_well: PanelContainer
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _empty_box: VBoxContainer
var _empty_title: Label
var _empty_text: Label
var _empty_actions: HBoxContainer
var _detail: VBoxContainer
var _detail_title: Label
var _detail_sub: Label
var _card: Dictionary
var _not_connected: Label
var _join: TdButton
var _footer: Label
var _popups: Control
var selected_room := ""
var room_popup: TdPopup = null

func _init() -> void:
	super._init()
	close_on_scrim = false

func _build() -> void:
	var w := CoopUi.window(self, Vector2(1460, 864), 32)
	window = w.panel
	var body: VBoxContainer = w.body
	var head := CoopUi.title_row("Co-op")
	head.close.clicked.connect(back)
	body.add_child(head.row)
	_status = TdMenu.pill("", Color(0.1, 0.08, 0.06, 0.9), CoopUi.GOOD, 20)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.row.add_child(_status)
	head.row.move_child(_status, 1)
	var tools := TdMenu.hbox(18)
	body.add_child(tools)
	_search = CoopUi.field("Search room name", 420)
	_search.text_changed.connect(func(_t): _draw_list())
	tools.add_child(_search)
	_show_full = CheckButton.new()
	_show_full.text = "Show full rooms"
	_show_full.button_pressed = true
	_show_full.focus_mode = Control.FOCUS_NONE
	TdTheme.apply_type(_show_full, "body", TdTheme.color("cream.100"), 22)
	_show_full.toggled.connect(func(_v): _draw_list())
	tools.add_child(_show_full)
	var refresh := TdMenu.wood_button("Refresh", Vector2(170, 56))
	refresh.pressed.connect(refresh_rooms)
	tools.add_child(refresh)
	var sp := TdMenu.spacer()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(sp)
	_create = TdMenu.button(TdButton.Style.SECONDARY, "Create room", Vector2(266, 62), TdTheme.texture("icon_plus"))
	_create.font_size = 28
	_create.clicked.connect(open_create)
	tools.add_child(_create)
	var cols := TdMenu.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	# the list
	_list_well = CoopUi.flat_panel(CoopUi.WELL_BG, 14, Color(0.3, 0.22, 0.16), Vector4(10, 8, 10, 12))
	_list_well.custom_minimum_size = Vector2(932, 0)
	_list_well.mouse_filter = Control.MOUSE_FILTER_PASS
	cols.add_child(_list_well)
	var lv := TdMenu.vbox(8)
	_list_well.add_child(lv)
	var header := TdMenu.hbox(0)
	for c in [["", 72], ["Room", 362], ["Host", 220], ["Players", 110], ["", 24], ["State", 160]]:
		var l := TdMenu.label(c[0], "h3", TdTheme.color("cream.200"), 21)
		l.custom_minimum_size = Vector2(c[1], 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if c[0] == "Players" else HORIZONTAL_ALIGNMENT_LEFT
		header.add_child(l)
	header.name = "Header"
	lv.add_child(header)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(_list_scroll)
	_list = TdMenu.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	_empty_box = TdMenu.vbox(14)
	_empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(_empty_box)
	_empty_title = TdMenu.label("", "h2", TdTheme.color("cream.100"), 34)
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_box.add_child(_empty_title)
	_empty_text = TdMenu.wrap_label("", "body", TdTheme.color("cream.200"), 23)
	_empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_text.custom_minimum_size = Vector2(520, 0)
	_empty_text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_box.add_child(_empty_text)
	_empty_actions = TdMenu.hbox(16)
	_empty_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_box.add_child(_empty_actions)
	_footer = TdMenu.label("Only rooms on your game version are shown.", "body", TdTheme.color("cream.200"), 21)
	lv.add_child(_footer)
	# the detail
	var right := TdMenu.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_detail = TdMenu.vbox(10)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	_detail_title = TdMenu.label("", "h2", TdTheme.color("cream.100"), 34)
	_detail.add_child(_detail_title)
	_detail_sub = TdMenu.label("", "body", TdTheme.color("cream.200"), 21)
	_detail.add_child(_detail_sub)
	_card = CoopUi.level_card(440, 200)
	_card.turns.visible = false
	_detail.add_child(_card.panel)
	var note := TdMenu.label("Co-op gives no rewards or records to your story.", "body", TdTheme.color("cream.200"), 20)
	_detail.add_child(note)
	_not_connected = TdMenu.label("Not connected.", "body", TdTheme.color("cream.200"), 22)
	_not_connected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_not_connected.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_not_connected.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_not_connected)
	var join_row := TdMenu.hbox(0)
	join_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(join_row)
	_join = TdMenu.button(TdButton.Style.PRIMARY, "Join", Vector2(222, 66), TdTheme.texture("icon_play"))
	_join.font_size = 30
	_join.clicked.connect(join_selected)
	join_row.add_child(_join)
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popups)

func _net() -> Node:
	if net == null: net = get_node_or_null("/root/Net")
	return net

func _on_open() -> void:
	var n := _net()
	if n == null: return
	for pair in [["state_changed", _on_state], ["rooms_changed", _on_rooms], ["room_changed", _on_room], ["error_received", _on_error]]:
		if not n.is_connected(pair[0], pair[1]): n.connect(pair[0], pair[1])
	if not n.is_online and not n.practice: n.connect_relay()
	elif n.is_online: n.list_rooms()
	refresh()
	if n.in_room: _open_room()

func close() -> void:
	super.close()

func back() -> void:
	var n := _net()
	if n != null and n.practice: n.disconnect_relay()
	close()

## Asks for the room list again (or retries the connection when offline).
func refresh_rooms() -> void:
	var n := _net()
	if n == null: return
	if n.is_online: n.list_rooms()
	else: n.connect_relay()
	refresh()

func _on_state(_s: int) -> void: refresh()
func _on_rooms(_r: Array) -> void: refresh()
func _on_error(code: String, _text: String) -> void:
	if code in ["full", "not_found", "started", "version"]: refresh_rooms()

func _on_room(room: Dictionary) -> void:
	if not is_open: return
	if not room.is_empty() and room_popup == null: _open_room()

## Redraws everything from Net's state.
func refresh() -> void:
	var n := _net()
	var online: bool = n != null and n.is_online
	var practice: bool = n != null and n.practice
	var rich: RichTextLabel = _status.get_child(0)
	if practice:
		rich.text = "[b]● Offline practice[/b]"
		rich.add_theme_color_override("default_color", CoopUi.GOLD)
	elif online:
		rich.text = "[b]● Online · %d room%s[/b]" % [n.rooms.size(), "" if n.rooms.size() == 1 else "s"]
		rich.add_theme_color_override("default_color", CoopUi.GOOD)
	elif n != null and (n.state == RelayClient.State.CONNECTING or n.state == RelayClient.State.HELLO):
		rich.text = "[b]● Connecting…[/b]"
		rich.add_theme_color_override("default_color", TdTheme.color("cream.200"))
	else:
		rich.text = "[b]● Offline[/b]"
		rich.add_theme_color_override("default_color", CoopUi.BAD)
	_create.set_interactable(online, "Not connected")
	_draw_list()

func _visible_rooms() -> Array:
	var n := _net()
	var out := []
	if n == null: return out
	var q := _search.text.strip_edges().to_lower()
	for r in n.rooms:
		var full: bool = NetProtocol.int_of(r, "players") >= NetProtocol.int_of(r, "count")
		if (full or bool(r.get("started", false))) and not _show_full.button_pressed: continue
		if q != "" and not str(r.get("name", "")).to_lower().contains(q): continue
		out.append(r)
	return out

func _draw_list() -> void:
	var n := _net()
	CoopUi.clear(_list)
	CoopUi.clear(_empty_actions)
	var online: bool = n != null and n.is_online
	var rooms := _visible_rooms() if online else []
	var header := _list_well.find_child("Header", true, false)
	header.visible = online and not rooms.is_empty()
	_footer.visible = online
	_list_scroll.visible = online and not rooms.is_empty()
	_empty_box.visible = not _list_scroll.visible
	if not online:
		var connecting: bool = n != null and (n.state == RelayClient.State.CONNECTING or n.state == RelayClient.State.HELLO)
		_empty_title.text = "Connecting…" if connecting else "Can't reach the server."
		_empty_title.add_theme_color_override("font_color", TdTheme.color("cream.100"))
		_empty_text.text = "Looking for the co-op server." if connecting else "Check your connection. The room list comes back when the server answers."
		var retry := TdMenu.wood_button("Retry", Vector2(220, 62))
		retry.pressed.connect(refresh_rooms)
		_empty_actions.add_child(retry)
		var practice := TdMenu.wood_button("Offline practice", Vector2(280, 62))
		practice.tooltip_text = "Play a co-op level alone on this computer."
		practice.pressed.connect(start_practice)
		_empty_actions.add_child(practice)
	elif rooms.is_empty():
		_empty_title.text = "No rooms yet."
		_empty_text.text = "Make the first one: pick a level and wait for friends to join." if n.rooms.is_empty() \
			else "No room matches. Clear the search or show full rooms."
		var make := TdMenu.button(TdButton.Style.PRIMARY, "Create room", Vector2(266, 62), TdTheme.texture("icon_plus"))
		make.font_size = 28
		make.clicked.connect(open_create)
		_empty_actions.add_child(make)
	if selected_room != "" and not rooms.any(func(r): return r.id == selected_room): selected_room = ""
	if selected_room == "" and rooms.size() > 0: selected_room = rooms[0].id
	for r in rooms: _list.add_child(_room_row(r))
	_draw_detail(online)

func _room_row(r: Dictionary) -> PanelContainer:
	var sel: bool = r.id == selected_room
	var full: bool = NetProtocol.int_of(r, "players") >= NetProtocol.int_of(r, "count")
	var started := bool(r.get("started", false))
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 76)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.add_theme_stylebox_override("panel", CoopUi.box(CoopUi.SEL_BG if sel else CoopUi.ROW_BG, 10,
		CoopUi.SEL_LINE if sel else CoopUi.ROW_LINE, 3 if sel else 2, Vector4(8, 6, 8, 6)))
	var h := TdMenu.hbox(0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var lockc := CenterContainer.new()
	lockc.custom_minimum_size = Vector2(64, 0)
	if bool(r.get("locked", false)):
		var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(28, 28))
		lock.modulate = TdTheme.color("cream.100")
		lockc.add_child(lock)
		lockc.tooltip_text = "Password"
	else:
		lockc.add_child(TdMenu.label("Open", "small", CoopUi.GOOD if not sel else Color.WHITE, 20))
	h.add_child(lockc)
	h.add_child(CoopUi.thumb_rect(str(r.get("level", "")), Vector2(80, 54), 4))
	h.add_child(TdMenu.spacer(0, 12))
	var nv := TdMenu.vbox(0)
	nv.custom_minimum_size = Vector2(270, 0)
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nv)
	var nm := TdMenu.label(str(r.get("name", "")), "h3", TdTheme.color("cream.100"), 26)
	nm.clip_text = true
	nv.add_child(nm)
	nv.add_child(TdMenu.label(CoopLevels.level_name(str(r.get("level", ""))), "small", TdTheme.color("cream.200"), 20))
	var host := TdMenu.label(str(r.get("host_name", "")), "body", TdTheme.color("cream.100"), 24)
	host.custom_minimum_size = Vector2(220, 0)
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(host)
	var count := TdMenu.label("%d/%d" % [NetProtocol.int_of(r, "players"), NetProtocol.int_of(r, "count")], "h3", TdTheme.color("cream.100"), 26)
	count.custom_minimum_size = Vector2(110, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count)
	var state := "Playing" if started else ("Full" if full else "Waiting")
	var pill := CoopUi.state_pill(state, Color("2f7d3a") if state == "Waiting" else Color(0.2, 0.16, 0.13), Color.WHITE if state == "Waiting" else TdTheme.color("cream.300"))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(TdMenu.spacer(0, 24))
	h.add_child(pill)
	if (full or started) and not sel: p.modulate.a = 0.6
	var id: String = r.id
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.double_click: join_selected()
			else: select_room(id))
	return p

func select_room(id: String) -> void:
	selected_room = id
	_draw_list()

func _selected() -> Dictionary:
	var n := _net()
	if n == null: return {}
	for r in n.rooms:
		if r.id == selected_room: return r
	return {}

func _draw_detail(online: bool) -> void:
	var r := _selected()
	_detail.visible = online and not r.is_empty()
	_not_connected.visible = not online or r.is_empty()
	_not_connected.text = "Not connected." if not online else "Pick a room, or make your own."
	_join.visible = online
	if r.is_empty():
		_join.set_interactable(false, "Pick a room")
		return
	_detail_title.text = str(r.get("name", ""))
	var bits := []
	bits.append("Password" if r.get("locked", false) else "Open")
	if str(r.get("host_name", "")) != "": bits.append("host " + str(r.host_name))
	bits.append("%d of %d" % [NetProtocol.int_of(r, "players"), NetProtocol.int_of(r, "count")])
	_detail_sub.text = " · ".join(bits)
	CoopUi.fill_level_card(_card, str(r.get("level", "")), NetProtocol.int_of(r, "count"))
	var full: bool = NetProtocol.int_of(r, "players") >= NetProtocol.int_of(r, "count")
	var started := bool(r.get("started", false))
	_join.set_interactable(not full and not started, "This room is full." if full else "The match has started.")

## Join: a password room asks for it first; an open room joins at once.
func join_selected() -> void:
	var r := _selected()
	var n := _net()
	if r.is_empty() or n == null: return
	if bool(r.get("locked", false)):
		var j := CoopJoinPopup.new()
		j.free_on_close = true
		j.net = n
		j.room_info = r
		_popups.add_child(j)
		CoopUi.show_popup(j)
		return
	n.join_room(r.id, "", CoopLevels.my_hand_types(CoopLevels.hand_cap(str(r.get("level", "")))))

func open_create() -> CoopCreatePopup:
	var c := CoopCreatePopup.new()
	c.free_on_close = true
	c.net = _net()
	_popups.add_child(c)
	CoopUi.show_popup(c)
	return c

## Offline practice: a local relay; a one-player room is made at once.
func start_practice() -> void:
	var n := _net()
	if n == null: return
	n.start_practice()
	var levels := CoopLevels.list().level_ids()
	var level: String = levels[0] if levels.size() > 0 else ""
	n.create_room("Practice", level, 1, "", CoopLevels.my_hand_types(CoopLevels.hand_cap(level)))
	n.poll()

func _open_room() -> void:
	if room_popup != null: return
	for p in _popups.get_children():
		if p is TdPopup and p.is_open: p.close()
	room_popup = CoopRoom.new()
	room_popup.free_on_close = true
	room_popup.net = _net()
	_popups.add_child(room_popup)
	room_popup.closed.connect(func():
		room_popup = null
		refresh())
	CoopUi.show_popup(room_popup)
