class_name CoopCreatePopup
extends TdPopup
## Create room (mockups lobby-create / -create-refused): room name (≤ 24, counter), password (optional, Show; empty
## = open room), players 1–6 (default 2), the level from the Multiplayer list (CoopList), the level card on the
## right, Create. A refused name (the relay's swear filter: bad_name) turns the field red with the reason.
## Closes once the relay puts you in the new room.

var net: Node = null
var room_name := ""
var level_id := ""
var count := NetProtocol.DEFAULT_COUNT

var _name: LineEdit
var _counter: Label
var _name_warn: HBoxContainer
var _password: LineEdit
var _count_note: Label
var _levels: VBoxContainer
var _card: Dictionary
var _create: TdButton
var _picker: Array = []

## The 1–6 buttons (tools select one).
func _picker_buttons() -> Array:
	return _picker

func _build() -> void:
	var w := CoopUi.window(self, Vector2(1340, 800), 32)
	window = w.panel
	var body: VBoxContainer = w.body
	var head := CoopUi.title_row("Create room", "", 56)
	head.close.clicked.connect(close)
	body.add_child(head.row)
	var cols := TdMenu.hbox(30)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := TdMenu.vbox(8)
	left.custom_minimum_size = Vector2(790, 0)
	cols.add_child(left)
	left.add_child(TdMenu.label("Room name", "h3", TdTheme.color("cream.100"), 22))
	var name_row := Control.new()
	name_row.custom_minimum_size = Vector2(0, 60)
	left.add_child(name_row)
	_name = CoopUi.field("Room name", 0, false, NetProtocol.MAX_ROOM_NAME)
	_name.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	TdTheme.apply_type(_name, "h3", TdTheme.color("ink"), 28)
	_name.text_changed.connect(func(t):
		room_name = t
		CoopUi.field_error(_name, false)
		CoopUi.set_warning(_name_warn, "")
		_refresh())
	name_row.add_child(_name)
	_counter = TdMenu.label("", "small", TdTheme.color("ink"), 20)
	_counter.set_anchors_and_offsets_preset(PRESET_CENTER_RIGHT)
	_counter.offset_left = -90; _counter.offset_right = -16; _counter.offset_top = -14; _counter.offset_bottom = 14
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.add_child(_counter)
	_name_warn = CoopUi.warning()
	left.add_child(_name_warn)
	left.add_child(TdMenu.label("Password", "h3", TdTheme.color("cream.100"), 22))
	var pw_row := TdMenu.hbox(10)
	left.add_child(pw_row)
	_password = CoopUi.field("No password", 0, true, 64)
	_password.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw_row.add_child(_password)
	var show := TdMenu.wood_button("Show", Vector2(110, 56))
	show.pressed.connect(func():
		_password.secret = not _password.secret
		show.text = "Hide" if not _password.secret else "Show")
	pw_row.add_child(show)
	left.add_child(TdMenu.label("Empty = open room: anyone in the lobby can join without a prompt.", "body", TdTheme.color("cream.200"), 20))
	left.add_child(TdMenu.label("Players", "h3", TdTheme.color("cream.100"), 22))
	var picker := TdMenu.hbox(8)
	left.add_child(picker)
	_picker = CoopUi.count_picker(picker, count, func(n):
		count = n
		_refresh())
	_count_note = TdMenu.label("", "body", TdTheme.color("cream.200"), 20)
	left.add_child(_count_note)
	left.add_child(TdMenu.label("Level", "h3", TdTheme.color("cream.100"), 22))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS # more levels below: the bar says so
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CoopUi.style_scrollbar(scroll)
	left.add_child(scroll)
	_levels = TdMenu.vbox(6)
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_levels)
	var right := TdMenu.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_card = CoopUi.level_card(460, 210)
	right.add_child(_card.panel)
	var sp := TdMenu.spacer()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	var cr := TdMenu.hbox(0)
	cr.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(cr)
	_create = TdMenu.button(TdButton.Style.PRIMARY, "Create", Vector2(222, 64), TdTheme.texture("icon_plus"))
	_create.font_size = 30
	_create.clicked.connect(create)
	cr.add_child(_create)

func _on_open() -> void:
	var levels := CoopLevels.list().level_ids()
	if level_id == "" and levels.size() > 0: level_id = levels[0]
	if room_name == "":
		var sd = get_node_or_null("/root/SaveData")
		var who: String = sd.profile.player_name if sd != null and sd.profile != null else ""
		room_name = NetProtocol.clamp_text(("%s's room" % who) if who != "" else "Co-op room", NetProtocol.MAX_ROOM_NAME)
	_name.text = room_name
	if net != null:
		if not net.error_received.is_connected(_on_error): net.error_received.connect(_on_error)
		if not net.room_changed.is_connected(_on_room): net.room_changed.connect(_on_room)
	_refresh()

func _refresh() -> void:
	_counter.text = "%d / %d" % [room_name.length(), NetProtocol.MAX_ROOM_NAME]
	_count_note.text = "Up to %d player%s. Each brings %d tower%s. The level decides the energy rule." % [count, "" if count == 1 else "s",
		CoopLevels.hand_cap(level_id), "" if CoopLevels.hand_cap(level_id) == 1 else "s"]
	CoopUi.clear(_levels)
	for id in CoopLevels.list().level_ids():
		var row := CoopUi.level_row(id, 750, id == level_id)
		var k: String = id
		row.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				level_id = k
				_refresh())
		_levels.add_child(row)
	CoopUi.fill_level_card(_card, level_id, count)
	var ok: bool = room_name.strip_edges() != "" and level_id != "" and net != null and net.is_online
	_create.set_interactable(ok, "Name the room" if room_name.strip_edges() == "" else "Not connected")

func create() -> void:
	if net == null: return
	if not NetProtocol.name_allowed(room_name) and net.practice:
		show_error("bad_name")
		return
	net.create_room(room_name, level_id, count, _password.text, CoopLevels.my_hand_types(CoopLevels.hand_cap(level_id)))

## Shows a relay refusal (bad_name: the name field red).
func show_error(code: String) -> void:
	CoopUi.set_warning(_name_warn, NetProtocol.error_text(code))
	CoopUi.field_error(_name, code == "bad_name")

func _on_error(code: String, _t: String) -> void:
	if is_open: show_error(code)

func _on_room(room: Dictionary) -> void:
	if is_open and not room.is_empty(): close()

func _exit_tree() -> void:
	super._exit_tree()
	if net != null:
		if net.error_received.is_connected(_on_error): net.error_received.disconnect(_on_error)
		if net.room_changed.is_connected(_on_room): net.room_changed.disconnect(_on_room)
