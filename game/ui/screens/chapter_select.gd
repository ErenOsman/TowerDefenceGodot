extends TdPopup
## The Camp's chapter picker (UI_ChapterSelect.cs; Camp & Chapters — Design): main chapters in one row, side chapters
## in another (hidden while there are none). A card shows the chapter's name and its progress ("2 / 4 won"), or what
## opens it while locked. Picking an open chapter emits chapter_opened(chapter) (the Camp opens the level select
## panel on it, over this popup; Back there comes back here).

signal chapter_opened(chapter: int)

var cards: Array = []   # TdButton per chapter card
var _main_row: HBoxContainer
var _side_row: HBoxContainer
var _side_label: Control

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 32)
	p.custom_minimum_size = Vector2(1180, 0)
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(20)
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
	x.clicked.connect(close)
	head.add_child(x)
	col.add_child(TdMenu.section_heading("Story", 30))
	_main_row = TdMenu.hbox(24)
	col.add_child(_main_row)
	_side_label = TdMenu.section_heading("Side chapters", 30)
	col.add_child(_side_label)
	_side_row = TdMenu.hbox(24)
	col.add_child(_side_row)

func _on_open() -> void:
	draw()

func draw() -> void:
	for c in cards: c.queue_free()
	cards.clear()
	var asset: GameCatalogAsset = GameApp.catalog
	if asset == null: return
	var catalog := asset.to_catalog()
	var main := MenuLogic.chapter_cards(asset, catalog, SaveData.progress, ChapterKind.Main)
	var side := MenuLogic.chapter_cards(asset, catalog, SaveData.progress, ChapterKind.Side)
	for c in main: cards.append(_card(_main_row, c))
	for c in side: cards.append(_card(_side_row, c))
	_side_label.visible = not side.is_empty()
	_side_row.visible = not side.is_empty()
	TdMenu.pop_in(cards)

func _card(row: HBoxContainer, info: Dictionary) -> TdButton:
	var b := TdButton.new()
	b.style = TdButton.Style.ROW
	b.custom_minimum_size = Vector2(360, 150)
	b.size = b.custom_minimum_size
	b.text = ""
	row.add_child(b)
	var v := TdMenu.vbox(6)
	v.position = Vector2(24, 22)
	v.size = Vector2(312, 106)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(v)
	var name_l := TdMenu.label(info.name, "h2", TdTheme.color("cream.100") if info.open else TdTheme.color("cream.300"), 34)
	name_l.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var status := TdMenu.wrap_label(info.status, "body", TdTheme.color("gold") if info.open else TdTheme.color("cream.300"), 24)
	status.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(status)
	if info.open and info.total > 0:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = info.total
		bar.value = info.won
		bar.custom_minimum_size = Vector2(300, 12)
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_child(bar)
	if not info.open:
		b.set_extra_state("Locked")
		b.set_interactable(false, info.status)
		var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(28, 28))
		lock.position = Vector2(316, 20)
		lock.modulate = TdTheme.color("cream.300")
		b.add_child(lock)
	else:
		var c: int = info.chapter
		b.clicked.connect(func(): open_chapter(c))
	return b

## Opens a chapter's levels.
func open_chapter(chapter: int) -> void:
	chapter_opened.emit(chapter)
