extends TdPopup
## The Camp's chapter picker (UI_ChapterSelect.cs; Camp & Chapters — Design; a medium window, 70 % × 70 %, title
## top-left, × top-right): main chapters in a row, side chapters in a row below (hidden while there are none).
## A card shows the chapter at a glance: a board thumbnail of its first level (rendered once by ChapterThumbs on a wood
## well; the minimap until then), its name, one dot per level (green ✓ won, filled cobalt open, hollow locked), a progress bar
## (GOOD green when complete, cobalt only on the active chapter: the one holding the next level to play) with
## "2 / 4 won" / "4 / 4 won ✓ Complete", and the tower its last level gives on the first clear. A locked chapter
## shows why ("Finish Chapter 1 first"). Picking an open chapter emits chapter_opened(chapter) (the Camp opens the
## level select panel on it, over this popup; Back there comes back here).

signal chapter_opened(chapter: int)

const CARD_H := 280.0
## Cards are shorter while there is a side-chapter row too, so both rows fit the window.
const CARD_H_COMPACT := 236.0
const CARD_PAD := 20.0
const THUMB_W := 304.0
const DOT := 22.0
const GAP := 24
const BODY_SEP := 18
const HEAD_H := 52.0   # the title row (× button height)
const COL_SEP := 18

var cards: Array = []   # TdButton per chapter card
var card_infos: Array = []   # the MenuLogic.chapter_cards dictionaries, same order as cards
var _main_row: HFlowContainer
var _side_row: HFlowContainer
var _side_label: Control
var _scroll: ScrollContainer
var _main_heading: Control
var _card_h := CARD_H

func _build() -> void:
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 32)
	# medium window: 70 % wide, as tall as its rows (centred; _fit_height sets the height after each draw)
	p.anchor_left = 0.15
	p.anchor_right = 0.85
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = 0; p.offset_right = 0
	p.grow_vertical = GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(1180, 0)
	add_child(p)
	window = p
	var col := TdMenu.vbox(COL_SEP)
	p.add_child(col)
	var head := TdMenu.hbox(16)
	col.add_child(head)
	var t := TdMenu.label("Chapters", "h1", TdTheme.color("cream.100"))
	head.add_child(t)
	var hint := TdMenu.label("Pick a chapter, then a level", "body", TdTheme.color("cream.300"), 24)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(hint)
	var x := TdMenu.close_button()
	x.size_flags_vertical = SIZE_SHRINK_CENTER # its 52 px face, not stretched to the title row
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	col.add_child(_scroll)
	var body := TdMenu.vbox(BODY_SEP)
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_main_heading = TdMenu.section_heading("Story", 30)
	body.add_child(_main_heading)
	_main_row = _flow()
	body.add_child(_main_row)
	_side_label = TdMenu.section_heading("Side chapters", 30)
	body.add_child(_side_label)
	_side_row = _flow()
	body.add_child(_side_row)

func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", GAP)
	f.add_theme_constant_override("v_separation", GAP)
	f.mouse_filter = MOUSE_FILTER_IGNORE
	return f

func _on_open() -> void:
	draw()

func draw() -> void:
	for c in cards: c.queue_free()
	cards.clear()
	card_infos.clear()
	var asset: GameCatalogAsset = GameApp.catalog
	if asset == null: return
	var catalog := asset.to_catalog()
	var main := MenuLogic.chapter_cards(asset, catalog, SaveData.progress, ChapterKind.Main)
	var side := MenuLogic.chapter_cards(asset, catalog, SaveData.progress, ChapterKind.Side)
	var w := _card_width()
	_card_h = CARD_H if side.is_empty() else CARD_H_COMPACT
	for c in main: cards.append(_card(_main_row, c, w))
	for c in side: cards.append(_card(_side_row, c, w))
	card_infos.append_array(main)
	card_infos.append_array(side)
	_side_label.visible = not side.is_empty()
	_side_row.visible = not side.is_empty()
	_fit_height(main.size(), side.size(), w)
	TdMenu.pop_in(cards)

## Sizes the window to its content: the title row, the headings and the card rows (2 per row), scrolling only when
## that is taller than 80 % of the screen. One row of cards is the smallest it gets.
func _fit_height(n_main: int, n_side: int, w: float) -> void:
	var b4 := TdButton.bleed_for(TdButton.Style.ROW, Vector2(w, _card_h))
	var row_h := _card_h + b4.y + b4.w
	var heading_h := _main_heading.get_combined_minimum_size().y
	var rows := func(n: int) -> float:
		var r := maxi(1, ceili(n / 2.0))
		return r * row_h + (r - 1) * GAP
	var body_h: float = heading_h + BODY_SEP + rows.call(n_main)
	if n_side > 0: body_h += 2 * BODY_SEP + heading_h + rows.call(n_side)
	var screen := size if size.y > 0.0 else get_viewport_rect().size
	var pad := 2.0 * 32.0 + HEAD_H + COL_SEP
	var scroll_h := minf(body_h, screen.y * 0.8 - pad)
	_scroll.custom_minimum_size.y = scroll_h
	var h := pad + scroll_h
	window.offset_top = -h / 2.0
	window.offset_bottom = h / 2.0

## Two cards per row across the window's inside (the window is 70 % of the screen, at least its minimum width).
func _card_width() -> float:
	var screen := size if size.x > 0.0 else get_viewport_rect().size
	var win := maxf(screen.x * 0.7, window.custom_minimum_size.x)
	var inner := win - 64.0 - 16.0 # window padding, room for the scroll bar
	var b4 := TdButton.bleed_for(TdButton.Style.ROW, Vector2(600.0, CARD_H)) # the room a card keeps around its face
	return clampf(floorf((inner - GAP) / 2.0 - b4.x - b4.z), 520.0, 660.0)

func _card(row: HFlowContainer, info: Dictionary, w: float) -> TdButton:
	var open: bool = info.open
	var b := TdButton.new()
	b.style = TdButton.Style.ROW
	b.custom_minimum_size = Vector2(w, _card_h)
	b.size = b.custom_minimum_size
	b.text = ""
	row.add_child(b)
	var h := TdMenu.hbox(20)
	h.position = Vector2(CARD_PAD, CARD_PAD)
	h.size = Vector2(w - 2.0 * CARD_PAD, _card_h - 2.0 * CARD_PAD)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	b.face_node().add_child(h)
	h.add_child(_thumb(info))
	var v := TdMenu.vbox(8)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name_l := TdMenu.label(info.name, "h2", TdTheme.color("cream.100") if open else TdTheme.color("cream.300"), 34)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	v.add_child(_dots(info.levels))
	var grow := TdMenu.spacer()
	grow.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(grow)
	if open:
		v.add_child(_bar(info))
		v.add_child(_progress_line(info))
	else:
		v.add_child(_reason_line(info.reason if info.reason != "" else info.status))
	if info.reward != null: v.add_child(_reward(info))
	if not open:
		b.set_extra_state("Locked")
		b.set_interactable(false, info.reason if info.reason != "" else info.status)
	else:
		if info.active: b.face_node().add_child(_active_ring(Vector2(w, _card_h)))
		var c: int = info.chapter
		b.clicked.connect(func(): open_chapter(c))
	return b

## The first level's board (cached per chapter; the minimap until it has rendered), on a wood well. Locked: dimmed
## with a lock over it. The board is rendered on a transparent background, so it stands on the wood.
func _thumb(info: Dictionary) -> Control:
	var well := TdMenu.panel(TdPanel.Kind.WOOD, 6)
	well.custom_minimum_size = Vector2(THUMB_W, _card_h - 2.0 * CARD_PAD)
	well.clip_contents = true
	well.mouse_filter = MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = MOUSE_FILTER_IGNORE
	well.add_child(r)
	var lv: LevelAsset = info.first_level
	if lv != null:
		var key := lv.get_id()
		var tex := ChapterThumbs.cached(key)
		if tex != null: r.texture = tex
		else:
			r.texture = ChapterThumbs.placeholder(lv)
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ChapterThumbs.request(self, key, lv, func(t: Texture2D):
				if is_instance_valid(r):
					r.texture = t
					r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	if not info.open:
		r.modulate = Color(0.45, 0.42, 0.4)
		var c := CenterContainer.new()
		c.mouse_filter = MOUSE_FILTER_IGNORE
		well.add_child(c)
		var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(56, 56))
		lock.modulate = TdTheme.color("cream.200")
		c.add_child(lock)
	return well

## One dot per level, in play order.
func _dots(levels: Array) -> Control:
	var row := TdMenu.hbox(8)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	for l in levels:
		var d := LevelDot.new()
		d.state = l.state
		d.custom_minimum_size = Vector2(DOT, DOT)
		d.tooltip_text = l.name
		row.add_child(d)
	return row

## Green when the chapter is complete, cobalt on the active chapter, a quiet cream otherwise.
func _bar(info: Dictionary) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(1, info.total)
	bar.value = info.won
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var col: Color = TdTheme.color("good") if info.complete else (TdTheme.color("accent") if info.active else TdTheme.color("cream.300"))
	bar.add_theme_stylebox_override("background", _flat(Color(TdTheme.color("wood.900"), 0.85), 7))
	bar.add_theme_stylebox_override("fill", _flat(col, 7))
	return bar

## "2 / 4 won", or "4 / 4 won" then a green ✓ Complete (the fonts have no ✓: the kit's check icon).
func _progress_line(info: Dictionary) -> Control:
	var row := TdMenu.hbox(8)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var text: String = info.progress
	var won_text := text.get_slice(" ✓", 0)
	row.add_child(TdMenu.label(won_text, "body", TdTheme.color("cream.100"), 22))
	if info.complete:
		var check := TdMenu.picture(TdTheme.texture("icon_check"), Vector2(20, 20))
		check.modulate = TdTheme.color("good")
		check.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(check)
		row.add_child(TdMenu.label(text.get_slice("✓ ", 1), "body", TdTheme.color("good"), 22))
	for c in row.get_children(): c.mouse_filter = MOUSE_FILTER_IGNORE
	return row

## A locked chapter's reason, with a lock.
func _reason_line(reason: String) -> Control:
	var row := TdMenu.hbox(8)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(20, 20))
	lock.modulate = TdTheme.color("cream.300")
	lock.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(lock)
	var l := TdMenu.wrap_label(reason, "body", TdTheme.color("cream.200"), 22)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row

## The tower the chapter's last level gives on the first clear: medallion + "Clear reward" / "Reward earned" + name.
func _reward(info: Dictionary) -> Control:
	var tw: TowerAsset = info.reward
	var row := TdMenu.hbox(12)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var medal := TdMenu.medallion(TdMenu.unit_picture(tw.entity.view if tw.entity != null else "", tw.icon), 52)
	medal.size_flags_vertical = SIZE_SHRINK_CENTER
	if not info.open: medal.modulate = Color(0.75, 0.72, 0.7)
	row.add_child(medal)
	var v := TdMenu.vbox(0)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(v)
	var cap := TdMenu.label("Reward earned" if info.complete else "Clear reward", "small", TdTheme.color("cream.300"), 18)
	cap.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var n := TdMenu.label(info.reward_name, "plate", TdTheme.color("cream.100") if info.open else TdTheme.color("cream.200"), 22)
	n.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(n)
	return row

## The active chapter's mark: a thin cobalt ring around the wood card (the face stays wood; blue means active).
func _active_ring(face: Vector2) -> Control:
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = TdTheme.color("accent")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	ring.add_theme_stylebox_override("panel", sb)
	ring.position = Vector2(-3, -3)
	ring.size = face + Vector2(6, 6)
	ring.mouse_filter = MOUSE_FILTER_IGNORE
	return ring

static func _flat(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	return sb

## Opens a chapter's levels.
func open_chapter(chapter: int) -> void:
	chapter_opened.emit(chapter)

## A level's dot: won = GOOD green with a check, open = filled cobalt, locked = a hollow cream ring.
class LevelDot:
	extends Control
	var state := "locked"
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		match state:
			"won":
				draw_circle(c, r, TdTheme.color("good.ink"))
				draw_circle(c, r - 2.0, TdTheme.color("good"))
				var check := TdTheme.texture("icon_check")
				if check != null:
					var s := r * 1.3
					draw_texture_rect(check, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false, TdTheme.color("good.ink"))
			"open":
				draw_circle(c, r, TdTheme.color("accent.ink"))
				draw_circle(c, r - 2.0, TdTheme.color("accent"))
			_:
				draw_arc(c, r - 1.5, 0.0, TAU, 32, TdTheme.color("cream.300"), 3.0, true)
