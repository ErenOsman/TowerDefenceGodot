class_name HudCoop
extends Control
## The co-op parts of the battle HUD (Multiplayer — Design, co-op; UI/UX mockups screens-b/co-op-pass and
## lobby-match-left), added by Hud only when controller.is_coop:
##  - the turn order INSIDE the tracker: each player's initial on a wood disc in this round's order (the acting one
##    in a cobalt ring, ✓ = ended their turn, ↻ = passed), joined by "›", the name in a tooltip; no per-player colours;
##  - Pass (v2): a small wood coin at End turn's lower-left, joined by a thin neck, key chip (KeyBinds "Pass", Tab);
##    disabled = solid dark wood, dimmed label, the reason in its tooltip; hidden with one player left;
##  - while someone else acts, End turn is covered by a solid dark wood face with their medallion and "Şule's turn";
##    once you ended your turn, a green "Done · Waiting for N" face;
##  - the toast under the tracker (a player left: leave icon + "Their towers are neutral now…"; a desync);
##  - the chat: the last 3 lines as bare outlined text above the hand tray, fading after a few seconds; the input
##    only while typing (KeyBinds "Chat", T, opens it; Enter sends, Esc closes) — Enter itself stays End turn.
## The Pass dial and the End turn face live in the top bar (under / over its End turn button).

const CHAT_LINES := 3
const CHAT_W := 560.0
const CHAT_SHOW := 6.0
const CHAT_FADE := 1.0
const TOAST_SECONDS := 4.0

var controller: LevelController

var order_row: HBoxContainer
var dial: PassDial
var face: EndFace
var toast: PanelContainer
var toast_title: Label
var toast_sub: Label
var chat_feed: VBoxContainer
var chat_hint: Label
var chat_input: LineEdit

var _order_key := []
var _last_turn := "-"
var _chat_key := []

func _init() -> void:
	name = "Coop"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	_build()

func _build() -> void:
	if toast != null: return
	toast = PanelContainer.new()
	toast.name = "CoopNotice"
	toast.mouse_filter = MOUSE_FILTER_IGNORE
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(TdTheme.color("wood.900"), 0.94)
	tb.border_color = Color(TdTheme.color("gold"), 0.55)
	tb.set_border_width_all(2)
	tb.set_corner_radius_all(12)
	tb.content_margin_left = 24; tb.content_margin_right = 28
	tb.content_margin_top = 12; tb.content_margin_bottom = 14
	toast.add_theme_stylebox_override("panel", tb)
	toast.visible = false
	add_child(toast)
	var th := HudArt.hbox(18)
	toast.add_child(th)
	var leave := HudArt.sprite("icon_quit", Vector2(30, 30), TdTheme.color("gold"))
	leave.size_flags_vertical = SIZE_SHRINK_CENTER
	th.add_child(leave)
	var tv := HudArt.vbox(2)
	th.add_child(tv)
	toast_title = HudArt.label("", "h3", TdTheme.color("cream.100"), 28)
	tv.add_child(toast_title)
	toast_sub = HudArt.label("", "body", TdTheme.color("cream.200"), 21)
	tv.add_child(toast_sub)

	chat_feed = HudArt.vbox(2)
	chat_feed.name = "ChatFeed"
	chat_feed.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(chat_feed)
	chat_hint = HudArt.label("", "small", Color(TdTheme.color("cream.200"), 0.8), 18)
	_outline(chat_hint)
	add_child(chat_hint)
	chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.placeholder_text = "Say something…  (Enter sends, Esc closes)"
	chat_input.max_length = 200
	chat_input.custom_minimum_size = Vector2(CHAT_W, 48)
	chat_input.size = Vector2(CHAT_W, 48)
	TdTheme.apply_type(chat_input, "body", TdTheme.color("ink"), 22)
	chat_input.add_theme_color_override("font_placeholder_color", Color(TdTheme.color("ink"), 0.55))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("efe2c4")
	field.set_corner_radius_all(10)
	field.border_color = TdTheme.color("rim")
	field.set_border_width_all(2)
	field.content_margin_left = 14; field.content_margin_right = 14
	chat_input.add_theme_stylebox_override("normal", field)
	chat_input.add_theme_stylebox_override("focus", field)
	chat_input.visible = false
	chat_input.text_submitted.connect(_on_submit)
	chat_input.gui_input.connect(_on_input_key)
	chat_input.focus_exited.connect(func(): if chat_input.visible and chat_input.text == "": close_chat())
	add_child(chat_input)
	resized.connect(_layout)

## Connects to the controller and the top bar (Hud calls it once the controller is co-op).
func bind(c: LevelController, top_bar: HudTopBar) -> void:
	controller = c
	_build()
	order_row = HudArt.hbox(4)
	order_row.name = "TurnOrder"
	order_row.size_flags_vertical = SIZE_SHRINK_CENTER
	top_bar.add_tracker_part(order_row)
	dial = PassDial.new()
	dial.hud = self
	top_bar.add_child(dial)
	top_bar.move_child(dial, top_bar.end_turn.get_index()) # under End turn
	face = EndFace.new()
	face.hud = self
	top_bar.add_child(face) # over End turn
	dial.end_turn = top_bar.end_turn
	face.end_turn = top_bar.end_turn
	c.chat_changed.connect(func(): _chat_key = [])
	refresh()

## The chat input has the keyboard: the level's keys wait (Hud folds it into ui_panel_open).
func typing() -> bool:
	return chat_input != null and chat_input.visible and chat_input.has_focus()

func open_chat() -> void:
	chat_input.visible = true
	chat_input.grab_focus.call_deferred()
	_chat_key = []

func close_chat() -> void:
	chat_input.clear()
	chat_input.release_focus()
	chat_input.visible = false
	_chat_key = []

func _on_submit(text: String) -> void:
	if controller != null and text.strip_edges() != "": controller.send_chat(text)
	close_chat()

func _on_input_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		chat_input.accept_event()
		close_chat()

# ------------------------------------------------------------------ refresh

func _process(_delta: float) -> void:
	if controller == null or controller.coop == null: return
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	if keys != null and not controller.ui_panel_open and not chat_input.visible and keys.pressed("Chat"): open_chat()
	refresh()

func refresh() -> void:
	var c := controller
	if c == null or c.coop == null: return
	_turn_order()
	_toast()
	_chat()
	var turn: String = c.current_player
	if turn != _last_turn:
		var was := _last_turn
		_last_turn = turn
		if turn != "" and turn == c.local_player and was != turn and c.overlay != null:
			c.overlay.banner("Your turn", 1.2, false, "coop_turn")
	_layout()

func _toast() -> void:
	var c := controller
	toast.visible = c.coop_notice != ""
	if not toast.visible: return
	toast_title.text = c.coop_notice
	toast_sub.text = c.coop_notice_sub
	toast_sub.visible = c.coop_notice_sub != ""
	var bad: bool = c.coop.desync or c.coop.lost
	toast_title.add_theme_color_override("font_color", TdTheme.color("bad").lightened(0.35) if bad else TdTheme.color("cream.100"))

## This round's order: the players still to act (the first is acting), then the ones who ended.
func order_now() -> Array:
	var cs: CoopSession = controller.coop.coop
	var out: Array = []
	for p in cs.turn_order: out.append([p, "passed" if controller.coop.passed.has(p) else "wait"])
	for p in cs.players:
		if not cs.turn_order.has(p): out.append([p, "ended"])
	if not out.is_empty() and controller.current_player != "": out[0][1] = "acting"
	return out

func _turn_order() -> void:
	var order := order_now()
	var key := [order, controller.local_player]
	if key == _order_key: return
	_order_key = key
	for ch in order_row.get_children(): ch.free()
	for i in order.size():
		if i > 0:
			var arrow := HudArt.label("›", "h3", TdTheme.color("cream.300"), 24)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			order_row.add_child(arrow)
		order_row.add_child(_medal(order[i][0], order[i][1]))

func _medal(player: String, state: String) -> Control:
	var c := controller
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(44, 44)
	holder.mouse_filter = MOUSE_FILTER_PASS
	holder.size_flags_vertical = SIZE_SHRINK_CENTER
	var disc := InitialDisc.new()
	disc.letter = c.player_name(player).left(1).to_upper()
	disc.current = state == "acting"
	disc.position = Vector2(2, 2)
	if state == "ended": disc.modulate.a = 0.55
	holder.add_child(disc)
	if state == "ended" or state == "passed":
		var badge := TurnBadge.new()
		badge.kind = state
		badge.position = Vector2(28, 28)
		holder.add_child(badge)
	var me := player == c.local_player
	var who := c.player_name(player) + (" (you)" if me else "")
	var what: String = {"acting": "Acting now", "wait": "Waiting for their turn", "passed": "Passed: acts again after the others",
		"ended": "Ended their turn this round"}[state]
	TdTooltipTrigger.attach(holder, TooltipText.title(who, TdTheme.rich("ink")), what).set_placement(TdTooltipPlacement.Side.BELOW)
	return holder

# ------------------------------------------------------------------ chat feed

func _chat() -> void:
	var c := controller
	var now := Time.get_ticks_msec()
	var lines: Array = c.chat_lines.slice(maxi(0, c.chat_lines.size() - CHAT_LINES))
	var alphas: Array = []
	for l in lines:
		var age := (now - int(l.get("at", now))) / 1000.0
		var a := 1.0 if chat_input.visible else clampf(1.0 - (age - CHAT_SHOW) / CHAT_FADE, 0.0, 1.0)
		alphas.append(snappedf(a, 0.05))
	var key := [c.chat_lines.size(), alphas, chat_input.visible]
	if key == _chat_key: return
	_chat_key = key
	for ch in chat_feed.get_children(): ch.free()
	for i in lines.size():
		if alphas[i] <= 0.0: continue
		var line: Dictionary = lines[i]
		var r := HudArt.rich("body", TdTheme.color("cream.100"), 21)
		r.custom_minimum_size = Vector2(CHAT_W, 0)
		r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		r.add_theme_constant_override("outline_size", 6)
		var t := str(line.text).replace("[", "[lb]")
		if line.system: r.text = "[i][color=#%s]%s[/color][/i]" % [TdTheme.color("cream.300").to_html(false), t] # text.muted
		else: r.text = "[b][color=#%s]%s[/color][/b] %s" % [TdTheme.color("accent.light").to_html(false), str(line.name).replace("[", "[lb]"), t]
		r.modulate.a = alphas[i]
		chat_feed.add_child(r)
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	var k: String = keys.first("Chat") if keys != null else "T"
	chat_hint.text = "%s · chat" % k if k != "" else ""
	chat_hint.visible = not chat_input.visible and chat_hint.text != ""

static func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)

# ------------------------------------------------------------------ layout

func _layout() -> void:
	if toast == null: return
	var s := size
	toast.size = toast.get_combined_minimum_size()
	toast.position = Vector2((s.x - toast.size.x) / 2.0, HudLayout.TOP_BAR + 8.0)
	var tray_top := s.y - HudLayout.TRAY_H
	chat_hint.size = chat_hint.get_combined_minimum_size()
	chat_hint.position = Vector2(HudLayout.MARGIN + 6.0, tray_top - 6.0 - chat_hint.size.y)
	var bottom := chat_hint.position.y - 2.0
	if chat_input.visible:
		chat_input.position = Vector2(HudLayout.MARGIN, tray_top - 10.0 - chat_input.size.y)
		bottom = chat_input.position.y - 6.0
	chat_feed.size = Vector2(CHAT_W, chat_feed.get_combined_minimum_size().y)
	chat_feed.position = Vector2(HudLayout.MARGIN + 6.0, bottom - chat_feed.size.y)

# ------------------------------------------------------------------ texts the parts share

## Pass's tooltip (and why it is off).
func pass_tip() -> Array:
	var c := controller
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	var k: String = keys.first("Pass") if keys != null else "Tab"
	var sub := ("%s · as often as you like" % k) if k != "" else "As often as you like"
	if c.can_pass:
		var after: Array = []
		var order: Array = c.coop.coop.turn_order.duplicate()
		order.remove_at(0)
		order.append(c.local_player)
		for p in order: after.append("you" if p == c.local_player else c.player_name(p))
		return [TooltipText.title("Pass", TdTheme.rich("ink"), sub),
			"Let the others go first. You act again after them this round.", "Order after passing", " → ".join(after)]
	var why := ""
	var cs: CoopSession = c.coop.coop
	if c.session.phase != Phase.Player or c.session.is_over: why = "Enemies are moving."
	elif not cs.turn_order.has(c.local_player): why = "You ended your turn; Pass works only before that."
	elif c.wait_reason != "": why = c.wait_reason + "."
	elif cs.turn_order.size() <= 1: why = "Nobody else is left to act this round."
	else: why = "Not now."
	return [TooltipText.title("Pass", TdTheme.rich("ink"), TooltipText.colored(TooltipText.harmful_color(), "Not available")), why, "", ""]

# ------------------------------------------------------------------ parts

## ✓ (ended) or ↻ (passed) on a turn-order medallion.
class TurnBadge extends Control:
	var kind := "ended"
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size = Vector2(20, 20)
	func _draw() -> void:
		var ctr := Vector2(10, 10)
		draw_circle(ctr, 11.0, TdTheme.color("rim"))
		draw_circle(ctr, 9.0, TdTheme.color("good.ink") if kind == "ended" else TdTheme.color("wood.600"))
		var w := Color(1, 1, 1)
		if kind == "ended":
			draw_polyline(PackedVector2Array([Vector2(5.5, 10.5), Vector2(8.5, 13.5), Vector2(14.5, 6.5)]), w, 2.2, true)
		else:
			draw_arc(ctr, 5.0, deg_to_rad(-60), deg_to_rad(230), 16, TdTheme.color("cream.100"), 2.0, true)
			var tip := ctr + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * 5.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-3.5, -2.5), tip + Vector2(3.0, -1.0), tip + Vector2(-0.5, 3.5)]), TdTheme.color("cream.100"))

## A player's initial on a wood disc (players have no avatars); the acting player's disc gets the cobalt ring.
class InitialDisc extends Control:
	var letter := "?"
	var current := false
	var diameter := 40.0
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _ready() -> void:
		size = Vector2(diameter, diameter)
		custom_minimum_size = size
	func _draw() -> void:
		var r := diameter / 2.0
		var ctr := Vector2(r, r)
		if current:
			draw_circle(ctr, r + 7.0, Color(TdTheme.color("accent.light"), 0.25))
			draw_circle(ctr, r + 5.0, TdTheme.color("accent.light"))
		draw_circle(ctr, r + 2.0, TdTheme.color("rim"))
		draw_circle(ctr, r, Color("5A4636"))
		draw_circle(ctr + Vector2(0, -r * 0.18), r * 0.78, Color("6B5443", 0.6))
		var font: Font = TdTheme.font("plinth")
		var fs := int(diameter * 0.55)
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, ctr + Vector2(-w / 2.0, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TdTheme.color("cream.100"))

## Pass v2: a small wood coin at End turn's lower-left (8 o'clock), tucked behind it and joined by a thin wood neck;
## ↻ over "Pass", the key chip on its lower-left edge. Draws, hit-tests and clicks itself (only the coin takes the
## pointer). Hidden outside the player phase and when you are the only player left (like single player).
class PassDial extends Control:
	const R := 36.0                         # coin radius (72 px)
	const OFFSET := Vector2(-100, 45)       # coin centre from End turn's centre (rim 20 px above the screen edge)
	const NECK := 16.0
	var hud: HudCoop
	var end_turn: Control
	var hovered := false
	var pressed_in := false
	var _state := []
	var _trigger: TdTooltipTrigger
	func _init() -> void:
		name = "PassButton"
		mouse_filter = MOUSE_FILTER_STOP
		# wide to the left on purpose: the tooltip opens ABOVE starting at this control's left edge, so it ends just
		# left of End turn (never over it); only the coin takes the pointer (_has_point)
		size = Vector2(340.0 + 4.0 + 84.0 + 30.0, 160) # battle tooltip 340 + gap + End turn radius + 30
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; pressed_in = false; queue_redraw())
	func _ready() -> void:
		# the tooltip opens above the coin itself (not the whole control)
		var anchor := Control.new()
		anchor.name = "CoinAnchor"
		anchor.mouse_filter = MOUSE_FILTER_IGNORE
		anchor.position = coin() - Vector2(R, R)
		anchor.size = Vector2(R, R) * 2.0
		add_child(anchor)
		_trigger = TdTooltipTrigger.attach(self)
		_trigger.set_placement(TdTooltipPlacement.Side.ABOVE, anchor)
	## The coin's centre in this control; End turn's centre is (size.x - 30, 50).
	func coin() -> Vector2: return end_centre() + OFFSET
	func end_centre() -> Vector2: return Vector2(size.x - 30.0, 50.0)
	func _has_point(p: Vector2) -> bool:
		return p.distance_to(coin()) <= R + 3.0
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: pressed_in = true
			elif pressed_in:
				pressed_in = false
				if hud.controller != null and hud.controller.can_pass: hud.controller.pass_turn()
			accept_event()
			queue_redraw()
	func _process(_d: float) -> void:
		var c: LevelController = hud.controller if hud != null else null
		if c == null or c.coop == null or end_turn == null: return
		var ec: Vector2 = end_turn.position + end_turn.size / 2.0
		position = ec - end_centre()
		visible = c.session.phase == Phase.Player and not c.session.is_over and c.coop.coop.players.size() > 1
		var tip := hud.pass_tip()
		var keys = get_tree().root.get_node_or_null("KeyBinds")
		var k: String = keys.first("Pass") if keys != null else "Tab"
		var st := [c.can_pass, hovered, pressed_in, k, tip]
		if st != _state:
			_state = st
			_trigger.set_content(tip[0], tip[1], tip[2], tip[3])
			queue_redraw()
	func _draw() -> void:
		var c: LevelController = hud.controller if hud != null else null
		if c == null: return
		var on: bool = c.can_pass
		var p := coin() + (Vector2(0, -3) if on and hovered and not pressed_in else Vector2.ZERO)
		var e := end_centre()
		var rim := TdTheme.color("rim")
		# the neck (End turn covers its far end)
		draw_line(p, e, rim, NECK + 4.0)
		draw_line(p, e, Color("3A2D24") if on else Color("1C1510"), NECK)
		draw_line(p + Vector2(0, -NECK * 0.2), e + Vector2(0, -NECK * 0.2), Color("4A3A2E") if on else Color("2E241C"), NECK * 0.35)
		# the coin
		draw_circle(p + Vector2(0, 4), R + 3.0, Color(0, 0, 0, 0.3))
		if on and hovered: draw_circle(p, R + 6.0, TdTheme.color("accent.light"))
		draw_circle(p, R + 3.0, rim)
		var fill := Color("5A4636")
		if on and hovered: fill = Color("7A6250")
		if on and pressed_in: fill = Color("46372B")
		if not on: fill = Color("2E241C")
		draw_circle(p, R, fill)
		draw_circle(p + Vector2(0, -R * 0.15), R * 0.8, Color(fill.lightened(0.08), 0.6) if on else Color(fill, 0.0))
		var lc := TdTheme.color("cream.100") if on else Color(TdTheme.color("cream.100"), 0.45)
		# ↻ above "Pass"
		var ic := p + Vector2(0, -9)
		draw_arc(ic, 7.0, deg_to_rad(-50), deg_to_rad(240), 20, lc, 2.4, true)
		var tip := ic + Vector2.from_angle(deg_to_rad(-50)) * 7.0
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-4.5, -3.0), tip + Vector2(3.5, -2.0), tip + Vector2(-0.5, 4.0)]), lc)
		var font: Font = TdTheme.font("plinth")
		var tw := font.get_string_size("Pass", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, p + Vector2(-tw / 2.0, 16), "Pass", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lc)
		# the key chip on the coin's lower-left edge
		var keys = get_tree().root.get_node_or_null("KeyBinds")
		var k: String = keys.first("Pass") if keys != null else "Tab"
		if k != "":
			var kw := font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
			var kr := Rect2(p + Vector2(-R - 12.0, R - 20.0), Vector2(kw, 20))
			var box := StyleBoxFlat.new()
			box.bg_color = TdTheme.color("paper") if on else Color("6E6253")
			box.set_corner_radius_all(5)
			box.border_color = rim
			box.set_border_width_all(2)
			draw_style_box(box, kr)
			draw_string(font, kr.position + Vector2(6, 15), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TdTheme.color("ink") if on else Color("2A211B"))

## Over End turn while someone else acts (their medallion + "Şule's turn"), or "Done · Waiting for N" after yours.
class EndFace extends Control:
	var hud: HudCoop
	var end_turn: Control
	var _mode := ""
	var _medal: InitialDisc
	var _title: Label
	var _sub: Label
	var _trigger: TdTooltipTrigger
	var _t := 0.0
	func _init() -> void:
		name = "EndTurnFace"
		mouse_filter = MOUSE_FILTER_STOP
		size = Vector2(168, 168)
		visible = false
	func _ready() -> void:
		_medal = InitialDisc.new()
		_medal.diameter = 44.0
		_medal.pivot_offset = Vector2(22, 22)
		add_child(_medal)
		_title = HudArt.label("", "h3", TdTheme.color("cream.100"), 20)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_title)
		_sub = HudArt.label("", "small", Color("E6EFFF"), 18)
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_sub)
		_trigger = TdTooltipTrigger.attach(self)
		_trigger.set_placement(TdTooltipPlacement.Side.LEFT)
	func _has_point(p: Vector2) -> bool:
		return p.distance_to(size / 2.0) <= 87.0
	func _process(d: float) -> void:
		var c: LevelController = hud.controller if hud != null else null
		if c == null or c.coop == null or end_turn == null: return
		position = end_turn.position + (end_turn.size - size) / 2.0
		var cs: CoopSession = c.coop.coop
		var running: bool = c.session.phase == Phase.Player and not c.session.is_over and c.current_player != ""
		var mode := ""
		if running and not cs.turn_order.has(c.local_player) and not cs.left.has(c.local_player): mode = "done:%d" % cs.turn_order.size()
		elif running and c.current_player != c.local_player: mode = "other:" + c.current_player
		visible = mode != ""
		if mode != _mode:
			_mode = mode
			_apply(c, mode)
			queue_redraw()
		if visible and mode.begins_with("other"):
			_t += TdTheme.unscaled(d)
			_medal.scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * TAU / 1.8))
	func _apply(c: LevelController, mode: String) -> void:
		if mode == "": return
		var who := c.current_player
		if mode.begins_with("other"):
			_medal.visible = true
			_medal.letter = c.player_name(who).left(1).to_upper()
			_medal.queue_redraw()
			_medal.position = Vector2((size.x - 44) / 2.0, 42)
			_title.text = "%s's turn" % c.player_name(who)
			_title.add_theme_font_size_override("font_size", 20)
			_title.size = Vector2(size.x - 16, 28)
			_title.position = Vector2(8, 96)
			_sub.visible = false
			_trigger.set_content(TooltipText.title("%s's turn" % c.player_name(who), TdTheme.rich("ink")),
				"Wait for %s to finish. You can look around and select units meanwhile." % c.player_name(who))
		else:
			var n := int(mode.split(":")[1])
			_medal.visible = false
			_title.text = "Done"
			_title.add_theme_font_size_override("font_size", 30)
			_title.size = Vector2(size.x - 16, 36)
			_title.position = Vector2(8, 46)
			_sub.visible = true
			_sub.text = "Waiting\nfor %d" % n
			_sub.size = Vector2(size.x - 16, 48)
			_sub.position = Vector2(8, 88)
			_trigger.set_content(TooltipText.title("Turn ended", TdTheme.rich("ink")),
				"You ended your turn for this round. The enemies move once everyone has ended.")
	func _draw() -> void:
		var ctr := size / 2.0
		draw_circle(ctr, 87.0, TdTheme.color("rim"))
		if _mode.begins_with("done"):
			draw_circle(ctr, 84.0, Color("33503F"))
			draw_circle(ctr - Vector2(0, 12), 64.0, Color("4E6B5A", 0.55))
		else:
			draw_circle(ctr, 84.0, Color("2A211B"))
			draw_circle(ctr - Vector2(0, 14), 62.0, Color("4A3A2E", 0.55))
		draw_arc(ctr, 81.0, deg_to_rad(200), deg_to_rad(340), 32, Color(1.0, 0.86, 0.67, 0.14), 3.0, true)
