class_name CoopRoomSettings
extends TdPopup
## Room settings, host only (mockups lobby-room-settings / -settings-changed / -settings-lower): the co-op levels
## (the current one tagged "Current"), the picked level's card with its description and energy rule ("Rules come with
## the level."), the player count 1–6 with "n players are in the room. Fewer slots remove the last to join.", and
## Apply. Any change warns "Everyone's Ready resets."; lowering below the players present names who will be removed and
## Apply turns red ("Apply and remove 2").

var net: Node = null
var level_id := ""
var count := 2

var _levels: VBoxContainer
var _card: Dictionary
var _picker: Array = []
var _count_note: Label
var _lower_warn: HBoxContainer
var _apply_note: HBoxContainer
var _apply: TdButton

func _build() -> void:
	var w := CoopUi.window(self, Vector2(1340, 790), 32)
	window = w.panel
	var body: VBoxContainer = w.body
	var head := CoopUi.title_row("Room settings", "Only the host sees this.", 56)
	head.close.clicked.connect(close)
	body.add_child(head.row)
	var cols := TdMenu.hbox(28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, 0)
	cols.add_child(scroll)
	_levels = TdMenu.vbox(6)
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_levels)
	var right := TdMenu.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_card = CoopUi.level_card(560, 190, true)
	_card.turns.visible = false
	_card.extra.add_child(TdMenu.label("Rules come with the level.", "body", TdTheme.color("ink"), 20))
	right.add_child(_card.panel)
	right.add_child(TdMenu.label("Players", "h3", TdTheme.color("cream.100"), 26))
	var picker := TdMenu.hbox(8)
	right.add_child(picker)
	_picker = CoopUi.count_picker(picker, count, func(n):
		count = n
		_refresh())
	_count_note = TdMenu.label("", "body", TdTheme.color("cream.200"), 20)
	right.add_child(_count_note)
	_lower_warn = CoopUi.warning()
	right.add_child(_lower_warn)
	var sp := TdMenu.spacer()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	var ar := TdMenu.hbox(14)
	ar.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(ar)
	_apply_note = CoopUi.warning()
	_apply_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ar.add_child(_apply_note)
	_apply = TdMenu.button(TdButton.Style.PRIMARY, "Apply", Vector2(222, 64), TdTheme.texture("icon_check"))
	_apply.font_size = 28
	_apply.clicked.connect(ask_apply)
	ar.add_child(_apply)

func _on_open() -> void:
	if net != null and net.in_room:
		level_id = str(net.room.get("level", ""))
		count = NetProtocol.int_of(net.room, "count", 2)
	for b in _picker: b.set_selected(b.text == str(count))
	_refresh()

func _current_level() -> String:
	return str(net.room.get("level", "")) if net != null and net.in_room else ""

func _current_count() -> int:
	return NetProtocol.int_of(net.room, "count", 2) if net != null and net.in_room else 2

## The players lowering the count would remove (the last joined), by name.
func removed_names() -> Array:
	if net == null or not net.in_room: return []
	var players := NetProtocol.players_by_slot(net.room)
	var out := []
	for i in range(count, players.size()): out.append(str(players[i].get("name", "?")))
	return out

func _refresh() -> void:
	CoopUi.clear(_levels)
	var sd = get_node_or_null("/root/SaveData")
	var mp: MissionProgress = sd.missions if sd != null else null
	for id in CoopLevels.list().level_ids():
		# a mission room lists missions as Create room does (QA 2026-10-14: it listed level names), a mission used up
		# today greyed and not pickable (the switch would make everyone who played it leave, the host too)
		var m := CoopLevels.mission_for_level(id)
		var row: PanelContainer
		var usable := true
		if m != null:
			row = CoopCreatePopup.mission_row(id, m, mp, id == level_id)
			row.custom_minimum_size.x = 600
			usable = id == _current_level() or CoopLevels.can_create(id)
			if id == _current_level():
				var t := TdMenu.pill("[b]Current[/b]", Color(0.12, 0.09, 0.07, 0.85), CoopUi.GOLD, 20)
				t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.get_child(0).add_child(t)
		else:
			row = CoopUi.level_row(id, 600, id == level_id, "Current" if id == _current_level() else "")
		var k: String = id
		if usable and id != level_id: # hover: a lighter rim, as the lobby's and Create room's rows
			var normal: StyleBox = row.get_theme_stylebox("panel")
			var lit := CoopUi.box(CoopUi.ROW_BG.lightened(0.06), 10, TdTheme.color("accent.light"), 2, Vector4(8, 6, 16, 6))
			row.mouse_entered.connect(func(): row.add_theme_stylebox_override("panel", lit))
			row.mouse_exited.connect(func(): row.add_theme_stylebox_override("panel", normal))
		if usable:
			row.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					level_id = k
					_refresh())
		else:
			row.modulate.a = 0.55
			row.mouse_default_cursor_shape = Control.CURSOR_ARROW
			row.tooltip_text = CoopLevels.last_reason
		_levels.add_child(row)
	# the player counts outside the picked mission's range are off, with the reason (as Create room)
	var pm := CoopLevels.mission_for_level(level_id)
	for i in _picker.size():
		var n := i + NetProtocol.MIN_COUNT
		_picker[i].set_interactable(pm == null or (n >= pm.min_players and n <= pm.max_players), MissionUiLogic.players_reason(pm))
	if pm != null:
		count = pm.clamp_players(count)
		for i in _picker.size(): _picker[i].set_selected(i + NetProtocol.MIN_COUNT == count)
	CoopUi.fill_level_card(_card, level_id, count)
	if pm != null: _card.title.text = pm.name
	var present: int = (net.room.get("players", []) as Array).size() if net != null and net.in_room else 1
	_count_note.text = "%d player%s %s in the room. Fewer slots remove the last to join." % [present, "" if present == 1 else "s", "is" if present == 1 else "are"]
	var gone := removed_names()
	CoopUi.set_warning(_lower_warn, "%s will be removed (joined last); everyone's Ready resets." % NetProtocol.join_names(gone) if gone.size() > 0 else "")
	var changed := level_id != _current_level() or count != _current_count()
	if gone.size() > 0:
		CoopUi.set_warning(_apply_note, "") # the names line above says it once
		_apply.style = TdButton.Style.DANGER
		_apply.text = "Apply and remove %d" % gone.size()
		_fit_apply()
	else:
		CoopUi.set_warning(_apply_note, "Everyone's Ready resets." if changed else "No changes yet.", CoopUi.GOLD if changed else TdTheme.color("cream.200"))
		_apply.style = TdButton.Style.PRIMARY
		_apply.text = "Apply"
		_fit_apply()
	_apply.set_interactable(changed, "No changes yet")

## Apply: lowering the count below the players present asks first (it removes them); any other change applies.
func ask_apply() -> TdConfirm:
	var gone := removed_names()
	if gone.is_empty():
		apply()
		return null
	return TdConfirm.ask(self, "Remove %s?" % NetProtocol.join_names(gone),
		"Fewer slots remove the last to join; everyone's Ready resets.", "Apply and remove %d" % gone.size(),
		func(yes: bool): if yes: apply(), {"danger": true})

func apply() -> void:
	if net == null: return
	if level_id != _current_level(): net.set_level(level_id)
	if count != _current_count(): net.set_count(count)
	close()

## Apply's width follows its label (24 px padding each side), at least 222.
func _fit_apply() -> void:
	var f: Font = TdTheme.font("button")
	var w := f.get_string_size(_apply.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _apply.font_size).x + 24.0 * 2.0 + 40.0 # + the check icon
	_apply.custom_minimum_size = Vector2(maxf(222.0, w), 64)
	_apply.size = _apply.custom_minimum_size
