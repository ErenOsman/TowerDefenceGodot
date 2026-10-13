class_name HudCoop
extends Control
## The co-op parts of the battle HUD (Multiplayer — Design, co-op), added by Hud only when controller.is_coop:
##  - the turn strip under the tracker: this round's order as name chips in slot colours (the acting player first,
##    lit; players who ended their turn greyed after them; "You" for you);
##  - "Your turn" as a board banner when your turn starts;
##  - Pass left of End turn (gives the turn away: you move to the end of this round's order; End turn is final);
##  - the notice banner (a player left, a desync, the connection lost) under the strip;
##  - the chat toggle at the bottom-left over the hand tray: the last 5 lines and an input (Net.chat).
## Full-rect and pointer-transparent; only the chips' tooltips, Pass and the chat take the pointer.

const CHAT_LINES := 5
const CHAT_W := 460.0

var controller: LevelController

var strip: HBoxContainer
var pass_button: TdButton
var notice: PanelContainer
var notice_label: Label
var chat_button: TdButton
var chat_panel: PanelContainer
var chat_box: VBoxContainer
var chat_input: LineEdit

var _strip_key := []
var _last_turn := "-"
var _unread := 0
var _pass_state := []

func _init() -> void:
	name = "Coop"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	_build()

func _build() -> void:
	if strip != null: return
	strip = HudArt.hbox(8)
	strip.name = "TurnStrip"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(strip)

	pass_button = TdButton.new()
	pass_button.name = "PassButton"
	pass_button.style = TdButton.Style.SECONDARY
	pass_button.text = "Pass"
	pass_button.custom_minimum_size = Vector2(128, 56)
	pass_button.size = Vector2(128, 56)
	add_child(pass_button)
	pass_button.clicked.connect(func(): if controller != null: controller.pass_turn())
	TdTooltipTrigger.attach(pass_button, TooltipText.title("Pass", TooltipText.neutral_color()),
		"Gives your turn away: you move to the end of this round's order and act again after the others. " +
		"You can pass as often as you like.\n" + TooltipText.colored(TooltipText.neutral_color(),
		"End turn is final: your turn does not come back until the next round.")).set_placement(TdTooltipPlacement.Side.ABOVE)

	notice = HudArt.panel("pill_wood", [28, 10, 28, 12])
	notice.name = "CoopNotice"
	notice.mouse_filter = MOUSE_FILTER_IGNORE
	notice.visible = false
	add_child(notice)
	notice_label = HudArt.label("", "h3", TdTheme.color("cream.100"), 26)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_child(notice_label)

	chat_button = TdButton.new()
	chat_button.name = "ChatButton"
	chat_button.style = TdButton.Style.SECONDARY
	chat_button.text = "Chat"
	chat_button.custom_minimum_size = Vector2(112, 48)
	chat_button.size = Vector2(112, 48)
	add_child(chat_button)
	chat_button.clicked.connect(toggle_chat)
	TdTooltipTrigger.attach(chat_button, TooltipText.title("Chat", TooltipText.neutral_color()),
		"Talk to the others in this match. Enter sends, Esc closes.").set_placement(TdTooltipPlacement.Side.ABOVE)

	chat_panel = PanelContainer.new()
	chat_panel.name = "ChatPanel"
	chat_panel.visible = false
	chat_panel.mouse_filter = MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(TdTheme.color("ink"), 0.82)
	bg.set_corner_radius_all(12)
	bg.content_margin_left = 16; bg.content_margin_right = 16
	bg.content_margin_top = 12; bg.content_margin_bottom = 12
	chat_panel.add_theme_stylebox_override("panel", bg)
	add_child(chat_panel)
	var v := HudArt.vbox(8)
	chat_panel.add_child(v)
	chat_box = HudArt.vbox(2)
	chat_box.custom_minimum_size = Vector2(CHAT_W - 32, 0)
	v.add_child(chat_box)
	chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.placeholder_text = "Say something…"
	chat_input.max_length = 200
	chat_input.custom_minimum_size = Vector2(CHAT_W - 32, 48)
	TdTheme.apply_type(chat_input, "body", TdTheme.color("ink"), 22)
	chat_input.add_theme_color_override("font_placeholder_color", Color(TdTheme.color("ink"), 0.55))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("efe2c4")
	field.set_corner_radius_all(10)
	field.content_margin_left = 14; field.content_margin_right = 14
	chat_input.add_theme_stylebox_override("normal", field)
	chat_input.add_theme_stylebox_override("focus", field)
	chat_input.text_submitted.connect(_on_submit)
	chat_input.gui_input.connect(_on_input_key)
	v.add_child(chat_input)
	resized.connect(_layout)
	_layout()

## Connects to the controller (Hud calls it once the controller is co-op).
func bind(c: LevelController) -> void:
	controller = c
	_build()
	c.chat_changed.connect(_on_chat)
	c.coop_notice_changed.connect(func(_t): refresh())
	refresh()

## The chat input has the keyboard: the level's keys wait (Hud folds it into ui_panel_open).
func typing() -> bool:
	return chat_input != null and chat_input.has_focus()

func toggle_chat() -> void:
	chat_panel.visible = not chat_panel.visible
	if chat_panel.visible:
		_unread = 0
		_fill_chat()
		chat_input.grab_focus()
	else: chat_input.release_focus()
	_chat_label()
	_layout()

func _on_submit(text: String) -> void:
	if controller != null and text.strip_edges() != "": controller.send_chat(text)
	chat_input.clear()

func _on_input_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		chat_input.accept_event()
		toggle_chat()

func _on_chat() -> void:
	if not chat_panel.visible: _unread += 1
	_fill_chat()
	_chat_label()

func _chat_label() -> void:
	chat_button.text = "Chat" if _unread == 0 else "Chat (%d)" % _unread
	chat_button.fit_to_content(112)

func _fill_chat() -> void:
	for ch in chat_box.get_children(): ch.free()
	if controller == null: return
	var lines: Array = controller.chat_lines.slice(maxi(0, controller.chat_lines.size() - CHAT_LINES))
	if lines.is_empty():
		chat_box.add_child(HudArt.label("No messages yet.", "body", Color(TdTheme.color("cream.300"), 0.8), 20))
	for line in lines:
		var r := HudArt.rich("body", TdTheme.color("cream.100"), 20)
		r.custom_minimum_size = Vector2(CHAT_W - 32, 0)
		var t := str(line.text).replace("[", "[lb]")
		if line.system: r.text = "[i][color=#%s]%s[/color][/i]" % [TdTheme.color("cream.300").to_html(false), t]
		else: r.text = "[b][color=#%s]%s[/color][/b]  %s" % [(line.color as Color).lightened(0.3).to_html(false), str(line.name).replace("[", "[lb]"), t]
		chat_box.add_child(r)

# ------------------------------------------------------------------ refresh

func _process(_delta: float) -> void:
	if controller == null or controller.coop == null: return
	refresh()

func refresh() -> void:
	var c := controller
	if c == null or c.coop == null: return
	_turn_strip()
	# Pass: your turn only, with someone to pass to
	var can_pass: bool = c.can_act and c.coop.coop.turn_order.size() > 1
	var why := c.wait_reason
	if why == "" and c.can_act: why = "Nobody else is left to act this round"
	if why == "": why = "Not now"
	var st := [can_pass, why, c.session.phase == Phase.Player and not c.session.is_over]
	if st != _pass_state:
		_pass_state = st
		pass_button.set_interactable(can_pass, why)
		pass_button.visible = st[2]
	notice.visible = c.coop_notice != ""
	if notice.visible:
		notice_label.text = c.coop_notice
		var bad: bool = c.coop.desync or c.coop.lost
		notice_label.add_theme_color_override("font_color", TdTheme.color("bad").lightened(0.35) if bad else TdTheme.color("cream.100"))
	var turn: String = c.current_player
	if turn != _last_turn:
		var was := _last_turn
		_last_turn = turn
		if turn != "" and turn == c.local_player and was != turn and c.overlay != null:
			c.overlay.banner("Your turn", 1.2, false, "coop_turn")
	_layout()

## Name chips in this round's order: the acting player lit, then the others waiting, then those who ended (greyed).
func _turn_strip() -> void:
	var c := controller
	var cs: CoopSession = c.coop.coop
	var order: Array = []
	for p in cs.turn_order: order.append([p, "wait"])
	for p in cs.players:
		if not cs.turn_order.has(p): order.append([p, "ended"])
	if not order.is_empty() and c.current_player != "": order[0][1] = "acting"
	var key := [order, c.local_player]
	if key == _strip_key: return
	_strip_key = key
	for ch in strip.get_children(): ch.free()
	for o in order:
		strip.add_child(_chip(o[0], o[1]))

func _chip(player: String, state: String) -> Control:
	var c := controller
	var col: Color = c.player_color(player)
	var chip := PanelContainer.new()
	chip.mouse_filter = MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = Color(TdTheme.color("ink"), 0.78 if state == "acting" else 0.55)
	box.set_corner_radius_all(18)
	box.content_margin_left = 12; box.content_margin_right = 16
	box.content_margin_top = 4; box.content_margin_bottom = 6
	if state == "acting":
		box.border_color = col
		box.set_border_width_all(3)
	chip.add_theme_stylebox_override("panel", box)
	var row := HudArt.hbox(8)
	chip.add_child(row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = SIZE_SHRINK_CENTER
	dot.mouse_filter = MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = col if state != "ended" else Color(col, 0.35)
	ds.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", ds)
	row.add_child(dot)
	var me := player == c.local_player
	var text := ("You" if me else c.player_name(player))
	var label_col := TdTheme.color("cream.100") if state == "acting" else TdTheme.color("cream.300")
	if state == "ended": label_col = Color(label_col, 0.55)
	var l := HudArt.label(text, "small", label_col, 22 if state == "acting" else 20)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var what: String = {"acting": "Acting now", "wait": "Waiting for their turn", "ended": "Ended their turn this round"}[state]
	TdTooltipTrigger.attach(chip, TooltipText.title(text, TooltipText.neutral_color()), what).set_placement(TdTooltipPlacement.Side.BELOW)
	return chip

func _layout() -> void:
	if strip == null: return
	var s := size
	strip.size = strip.get_combined_minimum_size()
	strip.position = Vector2((s.x - strip.size.x) / 2.0, HudLayout.TOP_BAR + 4.0)
	notice.size = notice.get_combined_minimum_size()
	notice.position = Vector2((s.x - notice.size.x) / 2.0, strip.position.y + 52.0)
	var end := HudLayout.end_turn_rect(s)
	var px := end.position.x - 12.0 - pass_button.size.x
	var py := end.end.y - pass_button.size.y - 8.0
	# a wide action bar reaching End turn: Pass goes above End turn instead
	var hud := get_parent()
	var bar = hud.find_child("ActionBar", false, false) if hud != null else null
	if bar == null and hud != null:
		for ch in hud.get_children():
			if ch is HudActionBar: bar = ch
	if bar != null and bar.visible and bar.position.x + bar.size.x > px - 8.0 and bar.position.y + bar.size.y > py:
		px = end.end.x - pass_button.size.x
		py = end.position.y - 12.0 - pass_button.size.y
	pass_button.position = Vector2(px, py)
	var tray_top := s.y - HudLayout.TRAY_H
	chat_button.position = Vector2(HudLayout.MARGIN, tray_top - 10.0 - chat_button.size.y)
	chat_panel.size = chat_panel.get_combined_minimum_size()
	chat_panel.position = Vector2(HudLayout.MARGIN, chat_button.position.y - 8.0 - chat_panel.size.y)
