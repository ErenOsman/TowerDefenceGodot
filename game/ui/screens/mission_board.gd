class_name MissionBoardScreen
extends TdPopup
## The mission board (Missions & Guild — Design § The Guild "Missions"; mockup screens-b/mission-board.html): a wood
## window over the Guild. Header "Missions · Earn tokens for the Workshop · plays reset at midnight (in 5 h)", the
## token pills (every token kind and how many you have) and ×. One card per mission in board order (the catalog's
## `missions`, unlocked or not): the board thumbnail, the name with its mode chip (Solo / Co-op 2–6 / Any · solo or
## 1–4), the level (and "2 plays a day"), the drops in two rows "Each win" / "First win" (first-win coins gold-rimmed,
## dimmed with "✓ claimed" once taken), and the state line: "⧗ 1 play left today" with a small Play (Solo / Any) or
## Find a room (co-op) button, "✓ Done today · resets in 5 h" (greyed card) or "🔒 Win Hold the Gate first".
## Clicking a card opens the mission's detail (MissionDetail) over the board. Texts: MissionUiLogic.
## Class name MissionBoardScreen: MissionBoard is the rules class (sim/meta).

## Find a room (a card's button or the detail's): the Guild opens the lobby with this mission picked.
signal find_room(mission_id: String)

const WIN := Vector2(1620, 800)
const CARD := Vector2(504, 318)
const THUMB := Vector2(160, 116)

var cards := {}   # mission id → the card
var detail: TdPopup = null
var _grid: GridContainer
var _sub: Label
var _inv: HBoxContainer
var _popups: Control

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 30)
	p.custom_minimum_size = WIN
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(18)
	p.add_child(col)
	var head := TdMenu.hbox(16)
	col.add_child(head)
	var t := TdMenu.label(MissionUiLogic.BoardTitle, "h1", TdTheme.color("cream.100"), 52)
	t.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	t.add_theme_constant_override("shadow_offset_y", 3)
	head.add_child(t)
	_sub = TdMenu.label("", "body", TdTheme.color("cream.200"), 21)
	_sub.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(_sub)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(fill)
	_inv = TdMenu.hbox(6)
	_inv.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(_inv)
	var x := TdMenu.close_button()
	x.tooltip_text = "Back to the Guild (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(scroll)
	TdDragScroll.attach(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_grid)
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popups)

func _on_open() -> void:
	refresh()

## Redraws the header and the cards (pop: the cards pop in).
func refresh() -> void:
	_sub.text = MissionUiLogic.board_subtitle()
	for c in _inv.get_children():
		_inv.remove_child(c)
		c.queue_free()
	if GameApp.catalog != null:
		for tok in GameApp.catalog.tokens:
			var id: String = tok.get_id()
			var have: int = SaveData.tokens.count(id)
			var pill := TdDrops.coin(id, have, false, false, 40.0, str(have))
			# "Found in" as the Workshop's token chips say it (QA 2026-10-14: the two tooltips of a token differed)
			var where := WorkshopLogic.found_in_text(id, GameApp.missions())
			TdTooltipTrigger.attach(pill, TooltipText.title(tok.get_display_name(), TooltipText.value_color(), "Token"),
				tok.description + ("\nFound in: %s." % where if where != "" else ""), "You have", str(have))
			_inv.add_child(pill)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	cards.clear()
	var made := []
	for m in GameApp.missions():
		var card := _card(m)
		_grid.add_child(card)
		cards[m.id] = card
		made.append(card)
	TdMenu.pop_in(made, 0.03)

func _state(m: MissionDef) -> Dictionary:
	var unlocked := MissionBoard.is_unlocked(m, SaveData.progress, SaveData.missions, GameApp.catalog)
	var reason := MissionBoard.last_reason
	return MissionUiLogic.card_state(m, unlocked, reason, SaveData.missions)

func _card(m: MissionDef) -> Control:
	var st := _state(m)
	var greyed: bool = st.state in [MissionUiLogic.Done, MissionUiLogic.Locked]
	var card := MissionCard.new()
	card.custom_minimum_size = CARD
	card.greyed = greyed
	card.clicked.connect(func(): open_detail(m.id))
	var h := TdMenu.hbox(16)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	h.position = Vector2(16, 16)
	h.size = CARD - Vector2(32, 32)
	card.add_child(h)
	var lv := GameApp.mission_level(m)
	var thumb := CoopUi.thumb_rect(m.level_id, THUMB)
	thumb.size_flags_vertical = SIZE_SHRINK_BEGIN
	if greyed: thumb.modulate = Color(0.7, 0.7, 0.7, 0.75)
	if st.state == MissionUiLogic.Locked: (thumb.get_child(0) as CoopBoardPic).grey = true # a locked mission: no colour
	h.add_child(thumb)
	var body := TdMenu.vbox(6)
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.mouse_filter = MOUSE_FILTER_IGNORE
	if greyed: body.modulate = Color(1, 1, 1, 0.8)
	h.add_child(body)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 10)
	top.add_theme_constant_override("v_separation", 4)
	top.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(top)
	var nm := TdMenu.label(m.name, "h3", TdTheme.color("cream.300") if greyed else TdTheme.color("cream.100"), 26)
	top.add_child(nm)
	top.add_child(TdDrops.mode_chip(m, 19))
	var ll := TdMenu.label(MissionUiLogic.level_line(m, lv.get_display_name() if lv != null else m.level_id), "body", TdTheme.color("cream.300"), 19)
	body.add_child(ll)
	var drops := TdDrops.rows(m, MissionUiLogic.first_win_claimed(m, SaveData.missions), 34.0, 92.0, 19)
	body.add_child(drops)
	var line := TdMenu.hbox(8)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(line)
	var icon_name: String = {"play": "hourglass", "room": "hourglass", "done": "check", "locked": "lock"}[st.state]
	line.add_child(TdDrops.icon(icon_name, 18, TdTheme.color("cream.300")))
	var sl := TdMenu.label(st.text, "plate", TdTheme.color("cream.200"), 19)
	sl.size_flags_vertical = SIZE_SHRINK_CENTER
	line.add_child(sl)
	if st.button != "":
		var row := TdMenu.hbox(0)
		row.mouse_filter = MOUSE_FILTER_IGNORE
		body.add_child(row)
		var b := TdMenu.button(TdButton.Style.SECONDARY, st.button, Vector2(124 if st.button == "Play" else 206, 50),
			TdTheme.texture("icon_play") if st.button == "Play" else null)
		b.font_size = 24
		if st.button != "Play":
			b.icon = TdDrops.icon_texture("users")
		var id := m.id
		if st.button == "Play": b.clicked.connect(func(): play(id))
		else: b.clicked.connect(func(): request_room(id))
		row.add_child(b)
	TdTooltipTrigger.attach(card, "", "Click: see the mission")
	return card

## Opens a mission's detail over the board; returns it.
func open_detail(mission_id: String) -> TdPopup:
	var d := MissionDetail.new()
	d.free_on_close = true
	d.mission_id = mission_id
	_popups.add_child(d)
	d.find_room.connect(request_room)
	d.closed.connect(func():
		detail = null
		if is_instance_valid(self) and is_open: refresh())
	d.open()
	detail = d
	return d

## A card's Play: plays the mission alone (GameApp.play_mission); refused → its detail says why.
func play(mission_id: String) -> bool:
	if GameApp.play_mission(mission_id): return true
	open_detail(mission_id)
	return false

## A co-op card's Find a room: the lobby with the mission picked (the Guild listens).
func request_room(mission_id: String) -> void:
	find_room.emit(mission_id)

## A board card: dark wood panel, a lighter rim on hover; greyed when done or locked.
class MissionCard extends Control:
	signal clicked
	var greyed := false
	var _hover := false

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.bg_color = Color("#2A1E17") if greyed else (Color("#4A3829") if _hover else Color("#3B2C22"))
		sb.border_color = TdTheme.color("accent.light") if _hover else Color("#5B4535")
		sb.set_border_width_all(3 if _hover else 2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
				and Rect2(Vector2.ZERO, size).has_point(event.position):
			clicked.emit()
