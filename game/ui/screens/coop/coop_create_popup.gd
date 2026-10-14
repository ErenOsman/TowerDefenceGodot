class_name CoopCreatePopup
extends TdPopup
## Create room (mockups lobby-create / -create-refused): room name (≤ 24, counter), password (optional, Show; empty
## = open room), players 1–6 (default 2), the level from the Multiplayer list (CoopList), the level card on the
## right, Create. A refused name (the relay's swear filter: bad_name) turns the field red with the reason.
## Closes once the relay puts you in the new room.
## Missions & Guild (mockups lobby-mission-picker, lobby-create-refused): the list is the co-op missions, each row
## "1 play left today · Any 1–4"; a mission used up today is greyed with "Done today · resets in 5 h" and cannot be
## picked; the card names the mission, its plays note and its drops; Create is refused (the warning line) when the
## mission has no play left (CoopLevels.can_create / last_reason). The player count is kept within the mission's range.

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
var _create_warn: HBoxContainer
var _plays_note: PanelContainer
var _drops: VBoxContainer
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
	left.add_child(TdMenu.label("Mission", "h3", TdTheme.color("cream.100"), 22))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS # more levels below: the bar says so
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CoopUi.style_scrollbar(scroll)
	left.add_child(scroll)
	# a gutter between the rows and the always-shown bar (the bar hid the rows' right rim; QA 2026-10-14)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 8)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gutter)
	_levels = TdMenu.vbox(6)
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(_levels)
	var right := TdMenu.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_card = CoopUi.level_card(460, 210)
	right.add_child(_card.panel)
	_card.turns.visible = false
	_plays_note = CoopUi.note_row("", "")
	CoopUi.set_note_icon(_plays_note, TdDrops.icon_texture("hourglass")) # plays: the hourglass (the clock is for rounds)
	_card.extra.add_child(_plays_note)
	_drops = TdMenu.vbox(0)
	_card.extra.add_child(_drops)
	var sp := TdMenu.spacer()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	_create_warn = CoopUi.warning()
	right.add_child(_create_warn)
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
	# a mission used up today cannot be picked: start on the first one with a play left
	if not CoopLevels.can_create(level_id):
		for id in levels:
			if CoopLevels.can_create(id):
				level_id = id
				break
	if room_name == "":
		var sd = get_node_or_null("/root/SaveData")
		var who: String = sd.profile.player_name if sd != null and sd.profile != null else ""
		room_name = NetProtocol.clamp_text(("%s's room" % who) if who != "" else "Co-op room", NetProtocol.MAX_ROOM_NAME)
	_name.text = room_name
	if net != null:
		if not net.error_received.is_connected(_on_error): net.error_received.connect(_on_error)
		if not net.room_changed.is_connected(_on_room): net.room_changed.connect(_on_room)
		if not net.state_changed.is_connected(_on_state): net.state_changed.connect(_on_state)
	_refresh()

func _on_state(_s: int) -> void:
	if is_open: _refresh()

## Keeps the player count within the picked mission's range: counts outside it are disabled with the reason
## ("Hold the Gate needs 2–6 players") and the picker shows the clamped count.
func _clamp_count() -> void:
	var m := CoopLevels.mission_for_level(level_id)
	for i in _picker.size():
		var n := i + NetProtocol.MIN_COUNT
		var ok := m == null or (n >= m.min_players and n <= m.max_players)
		_picker[i].set_interactable(ok, MissionUiLogic.players_reason(m))
	if m == null: return
	count = m.clamp_players(count)
	for i in _picker.size(): _picker[i].set_selected(i + NetProtocol.MIN_COUNT == count)

func _refresh() -> void:
	_clamp_count()
	_counter.text = "%d / %d" % [room_name.length(), NetProtocol.MAX_ROOM_NAME]
	_count_note.text = "Up to %d player%s. Each brings %d tower%s. The level decides the energy rule." % [count, "" if count == 1 else "s",
		CoopLevels.hand_cap(level_id), "" if CoopLevels.hand_cap(level_id) == 1 else "s"]
	# the disabled counts say why on a line too, not only on hover (QA 2026-10-14)
	var rm := CoopLevels.mission_for_level(level_id)
	if rm != null and (rm.min_players > NetProtocol.MIN_COUNT or rm.max_players < _picker.size() + NetProtocol.MIN_COUNT - 1):
		_count_note.text = "%s. Up to %d player%s, each brings %d tower%s." % [MissionUiLogic.players_reason(rm), count,
			"" if count == 1 else "s", CoopLevels.hand_cap(level_id), "" if CoopLevels.hand_cap(level_id) == 1 else "s"]
	CoopUi.clear(_levels)
	var sd = get_node_or_null("/root/SaveData")
	var mp: MissionProgress = sd.missions if sd != null else null
	for id in CoopLevels.list().level_ids():
		var m := CoopLevels.mission_for_level(id)
		var usable := CoopLevels.can_create(id)
		var row := mission_row(id, m, mp, id == level_id)
		var k: String = id
		if usable and id != level_id: # hover: a lighter rim (QA 2026-10-14: no hover state)
			var normal: StyleBox = row.get_theme_stylebox("panel")
			var lit := CoopUi.box(CoopUi.ROW_BG.lightened(0.06), 10, TdTheme.color("accent.light"), 2, Vector4(8, 6, 16, 6))
			row.mouse_entered.connect(func(): row.add_theme_stylebox_override("panel", lit))
			row.mouse_exited.connect(func(): row.add_theme_stylebox_override("panel", normal))
		if usable:
			row.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					level_id = k
					CoopUi.set_warning(_create_warn, "")
					_refresh())
		else:
			row.modulate.a = 0.55
			row.mouse_default_cursor_shape = Control.CURSOR_ARROW
			row.tooltip_text = CoopLevels.last_reason
		_levels.add_child(row)
	CoopUi.fill_level_card(_card, level_id, count)
	var cm := CoopLevels.mission_for_level(level_id)
	_plays_note.visible = cm != null
	CoopUi.clear(_drops)
	if cm != null:
		_card.title.text = cm.name
		var rich: RichTextLabel = _plays_note.get_child(0).get_child(_plays_note.get_child(0).get_child_count() - 1)
		rich.text = MissionUiLogic.create_plays_note(cm, mp)
		var box := CoopUi.flat_panel(Color("2b201a"), 10, Color(0, 0, 0, 0), Vector4(12, 8, 12, 8))
		box.add_child(TdDrops.rows(cm, MissionUiLogic.first_win_claimed(cm, mp), 34.0, 86.0, 19))
		_drops.add_child(box)
	var ok: bool = room_name.strip_edges() != "" and level_id != "" and net != null and net.is_online
	_create.set_interactable(ok, "Name the room" if room_name.strip_edges() == "" else "Not connected")

## A mission row of the picker (lobby-mission-picker.html): thumb, the mission's name, "1 play left today · Any 1–4"
## or "✓ Done today · resets in 5 h".
static func mission_row(id: String, m: MissionDef, mp: MissionProgress, selected: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(750, 70)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.add_theme_stylebox_override("panel", CoopUi.box(CoopUi.SEL_BG if selected else CoopUi.ROW_BG, 10,
		CoopUi.SEL_LINE if selected else CoopUi.ROW_LINE, 3 if selected else 2, Vector4(8, 6, 16, 6)))
	var h := TdMenu.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(CoopUi.thumb_rect(id, Vector2(80, 56), 4))
	var v := TdMenu.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(TdMenu.label(m.name if m != null else CoopLevels.level_name(id), "h3", TdTheme.color("cream.100"), 26))
	var line := MissionUiLogic.picker_line(m, mp) if m != null else "%d waves" % CoopUi.waves_of(id)
	var lh := TdMenu.hbox(6)
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if m != null and MissionBoard.plays_left(m, mp) <= 0: lh.add_child(TdDrops.icon("check", 18, TdTheme.color("cream.200")))
	lh.add_child(TdMenu.label(line, "small", TdTheme.color("cream.200"), 20))
	v.add_child(lh)
	return p

func create() -> void:
	if net == null: return
	if not CoopLevels.can_create(level_id): # a mission used up today: refused before sending
		CoopUi.set_warning(_create_warn, CoopLevels.last_reason)
		return
	_clamp_count()
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
		if net.state_changed.is_connected(_on_state): net.state_changed.disconnect(_on_state)
