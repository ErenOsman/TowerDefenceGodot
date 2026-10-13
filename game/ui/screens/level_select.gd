extends TdPopup
## Level select (UI_LevelSelect.cs; Level Select — Design; the Unity build's layout): "Select a level", the chapters
## and their levels on the left (every unlocked level plus the first locked one: LevelCatalog.visible), the selected
## level's detail (title, description, facts "15 × 9 · 2 waves · Hand 5 · Start energy 550 (+45 a round)", enemies,
## a minimap drawn from the level's layers, Play → GameApp.play_level), the hand strip under it (the first hand_cap
## towers bright, the rest dimmed, a note, Change hand → the hand editor popup) and Back.
## A locked level shows what opens it. A save without towers gets the catalog's starting towers. The last selected
## level is remembered (LevelProgress.last_selected).
## As a scene (SceneFlow.LevelSelect) Back goes to the main menu; in the Camp it is a full-screen panel showing one
## chapter (show_chapter) and Back closes it.

const HAND_EDITOR := "res://game/ui/screens/hand_editor.tscn"

## On in the Camp: one chapter, Back closes the panel.
var in_camp := false
var chapter_filter := -1
var selected := ""
var visible_rows: Array = []

var _catalog: LevelCatalog
var _asset: GameCatalogAsset
var _list: VBoxContainer
var _title: Label
var _desc: Label
var _facts: Label
var _enemies: Label
var _map_frame: PanelContainer
var _map: TextureRect
var _play: TdMenuButton
var _cards: HBoxContainer
var _note: Label
var _popups: Control
var _rows: Array = []

func _init() -> void:
	super._init()
	use_scrim = false
	right_click_closes = false

func _ready() -> void:
	super._ready()
	if get_tree().current_scene == self or get_parent() == get_tree().root:
		# the LevelSelect scene: shown at once, no transition
		is_open = true
		visible = true
		mouse_filter = MOUSE_FILTER_STOP
		TdPopup.open_popups.append(self)
		_on_open()

func _build() -> void:
	TdMenu.wood_background(self)
	var title := TdMenu.label("Select a level", "display", TdTheme.color("cream.100"), 64)
	title.position = Vector2(58, 28)
	add_child(title)
	# the list
	var left := TdMenu.panel(TdPanel.Kind.WINDOW, 18)
	left.position = Vector2(60, 132)
	left.size = Vector2(514, 816)
	left.custom_minimum_size = left.size
	add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	TdDragScroll.attach(scroll)
	_list = TdMenu.vbox(14)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)
	# the detail
	var detail := TdMenu.panel(TdPanel.Kind.WINDOW, 32)
	detail.position = Vector2(618, 132)
	detail.custom_minimum_size = Vector2(1242, 580)
	detail.size = detail.custom_minimum_size
	add_child(detail)
	var dcols := TdMenu.hbox(36)
	detail.add_child(dcols)
	var text := TdMenu.vbox(14)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	dcols.add_child(text)
	_title = TdMenu.label("", "display", TdTheme.color("cream.100"), 48)
	text.add_child(_title)
	_desc = TdMenu.wrap_label("", "body", TdTheme.color("cream.100"), 24)
	text.add_child(_desc)
	_facts = TdMenu.wrap_label("", "body", TdTheme.color("cream.300"), 22)
	text.add_child(_facts)
	_enemies = TdMenu.wrap_label("", "body", TdTheme.color("cream.300"), 22)
	text.add_child(_enemies)
	var right := TdMenu.vbox(30)
	right.custom_minimum_size = Vector2(486, 0)
	dcols.add_child(right)
	_map_frame = PanelContainer.new()
	var fr := StyleBoxFlat.new()
	fr.bg_color = Color(0.07, 0.055, 0.045)
	fr.set_corner_radius_all(14)
	fr.border_color = TdTheme.color("wood.600")
	fr.set_border_width_all(2)
	fr.set_content_margin_all(12)
	_map_frame.add_theme_stylebox_override("panel", fr)
	_map_frame.custom_minimum_size = Vector2(486, 370)
	right.add_child(_map_frame)
	_map = TextureRect.new()
	_map.custom_minimum_size = Vector2(0, 0)
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_frame.add_child(_map)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_END
	play_row.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(play_row)
	_play = TdMenuButton.new()
	_play.style = TdButton.Style.PRIMARY # flat: depth is for the main menu and Welcome only
	_play.custom_minimum_size = Vector2(270, 72)
	_play.size = Vector2(270, 72)
	_play.text = "Play"
	_play.font_size = 36
	_play.icon = TdTheme.texture("icon_play")
	_play.left_pad = 70
	_play.size_flags_vertical = SIZE_SHRINK_END
	_play.clicked.connect(play)
	play_row.add_child(_play)
	# the hand strip
	var hand := TdMenu.panel(TdPanel.Kind.WINDOW, 22)
	hand.position = Vector2(618, 736)
	hand.custom_minimum_size = Vector2(1242, 216)
	hand.size = hand.custom_minimum_size
	add_child(hand)
	var hrow := TdMenu.hbox(24)
	hand.add_child(hrow)
	var hcol := TdMenu.vbox(6)
	hcol.size_flags_horizontal = SIZE_EXPAND_FILL
	hrow.add_child(hcol)
	var hhead := TdMenu.hbox(12)
	hcol.add_child(hhead)
	var ht := TdMenu.section_heading("Your hand", 30)
	ht.size_flags_horizontal = SIZE_EXPAND_FILL
	hhead.add_child(ht)
	_note = TdMenu.label("", "body", TdTheme.color("cream.200"), 22)
	hhead.add_child(_note)
	_cards = TdMenu.hbox(10)
	hcol.add_child(_cards)
	var change := TdMenu.wood_button("Change hand", Vector2(236, 96))
	change.size_flags_vertical = SIZE_SHRINK_END
	change.pressed.connect(open_hand_editor)
	hrow.add_child(change)
	# back
	var back_b := TdMenu.wood_button("Back", Vector2(226, 70))
	back_b.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	back_b.offset_left = 60; back_b.offset_top = -106; back_b.offset_right = 286; back_b.offset_bottom = -36
	back_b.pressed.connect(back)
	add_child(back_b)
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popups)

func _on_open() -> void:
	_asset = GameApp.catalog
	if _asset == null:
		_title.text = "No game catalog"
		return
	_catalog = _asset.to_catalog()
	if _asset.grant_starting_towers(SaveData.towers): SaveData.save()
	visible_rows = MenuLogic.visible_levels(_catalog, SaveData.progress, chapter_filter)
	selected = MenuLogic.pick_start(visible_rows, SaveData.progress)
	refresh(true)

## Shows only one chapter's levels (the Camp's chapter picker), selecting where the player left off in it.
func show_chapter(chapter: int) -> void:
	chapter_filter = chapter
	if is_open: _on_open()

## Selects a visible level and shows it.
func select(level_id: String) -> void:
	selected = level_id
	SaveData.progress.last_selected = level_id
	refresh(false)

## Redraws the list, the selected level and the hand.
func refresh(pop := false) -> void:
	if _catalog == null: return
	visible_rows = MenuLogic.visible_levels(_catalog, SaveData.progress, chapter_filter)
	_draw_list(pop)
	var unlocked := false
	for v in visible_rows:
		if v.entry.level_id == selected and v.unlocked: unlocked = true
	var level := _asset.find_level(selected)
	_draw_level(level, unlocked)
	_draw_hand(level, pop)
	_play.set_interactable(level != null and unlocked and SaveData.towers.hand.size() > 0,
		"Locked" if not unlocked else "Your hand is empty: add towers with Change hand")

func _draw_list(pop: bool) -> void:
	for c in _list.get_children(): # removed at once: a queued child would still count below (the 22 px jump)
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	for item in MenuLogic.list_items(_asset, visible_rows):
		if item.has("heading"):
			if _list.get_child_count() > 0: _list.add_child(TdMenu.spacer(8))
			_list.add_child(TdMenu.section_heading(item.heading, 30))
			continue
		var level := _asset.find_level(item.level_id)
		var b := TdButton.new()
		b.style = TdButton.Style.ROW
		b.custom_minimum_size = Vector2(456, 50) # + the button's bleed room
		b.size = Vector2(456, 50)
		b.text = level.get_display_name() if level != null else item.level_id
		b.font_size = 26
		b.selectable = true
		b.selected = item.level_id == selected
		if not item.unlocked:
			# locked: 60 % with a 24 px lock; the viewed row stays selected (cobalt) even when locked
			if not b.selected: b.set_extra_state("Locked")
			b.modulate.a = 1.0 if b.selected else 0.6
			var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(30, 30)) # the glyph is ~24 px inside its PNG
			lock.position = Vector2(414, 10)
			lock.modulate = TdTheme.color("cream.100")
			b.face_node().add_child(lock)
		var id: String = item.level_id
		b.clicked.connect(func(): select(id)) # a locked row shows what opens it
		_list.add_child(b)
		_rows.append(b)
	if pop: TdMenu.pop_in(_rows)

func _draw_level(level: LevelAsset, unlocked: bool) -> void:
	_map.texture = null
	_map_frame.visible = false
	if level == null:
		_title.text = selected
		_desc.text = "No level to play." if selected == "" else "This level is missing from the catalog."
		_facts.text = ""
		_enemies.text = ""
		return
	_title.text = level.get_display_name()
	if not unlocked:
		_desc.text = "Locked. " + MenuLogic.requirement_text(_catalog, _asset, selected, SaveData.progress)
		_facts.text = ""
		_enemies.text = ""
		return
	_desc.text = level.description
	_facts.text = MenuLogic.facts_text(level)
	_enemies.text = MenuLogic.enemies_text(level)
	var img := MenuLogic.minimap_image(level, 16)
	if img != null:
		_map.texture = ImageTexture.create_from_image(img)
		_map_frame.visible = true
		# the frame takes the map's shape (with a dark margin), at most 370 tall
		var w := 486.0
		_map_frame.custom_minimum_size = Vector2(w, clampf((w - 24.0) * img.get_height() / float(img.get_width()) + 24.0, 160.0, 370.0))

func _draw_hand(level: LevelAsset, pop: bool) -> void:
	for c in _cards.get_children(): c.queue_free()
	var towers := SaveData.towers
	var cap := level.hand_cap if level != null else TowerCollection.MaxHand
	var made := []
	for i in towers.hand.size():
		var owned := towers.find(towers.hand[i])
		var type := _asset.find_tower(owned.type) if owned != null else null
		var card := TdHandCard.make(owned, type)
		card.set_dimmed(i >= cap)
		card.pressed.connect(open_hand_editor)
		_cards.add_child(card)
		made.append(card)
	_note.text = MenuLogic.hand_note(towers.hand.size(), cap)
	if pop: TdMenu.pop_in(made)

## Opens the hand editor popup over this screen; returns it.
func open_hand_editor() -> TdPopup:
	var he: TdPopup = load(HAND_EDITOR).instantiate()
	he.free_on_close = true
	he.level = _asset.find_level(selected) if _asset != null else null
	_popups.add_child(he)
	he.changed.connect(func(): refresh(false))
	he.open()
	return he

## Plays the selected level.
func play() -> void:
	var level := _asset.find_level(selected) if _asset != null else null
	if level == null: return
	SaveData.progress.last_selected = selected
	SaveData.save()
	GameApp.play_level(level)

func back() -> void:
	SaveData.save()
	if in_camp: close()
	else: SceneFlow.go(SceneFlow.MainMenu)
