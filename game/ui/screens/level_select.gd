extends TdPopup
## Level select (UI_LevelSelect.cs; Level Select — Design; the UI/UX mockup screens-b/level-select.html, 2026-10-13):
## "Choose a level" over dark wood, three wood windows and Back.
## - Left: the chapters as headings ("Chapter 1 · 4 levels", "new" while none of its levels was played) with numbered
##   rows (number medallion, name, on the right "✓ Won" green, "● New" for unlocked-not-played, or a lock with the
##   requirement line "Win Rock Garden first" for the one locked level shown, at 60 %); the selected row is cobalt.
##   Every unlocked level plus the first locked one shows (LevelCatalog.visible); in the Camp only one chapter.
## - Centre: "Chapter 1 · level 3 ✓ Won", the title, the description, four fact tiles (waves, enemies, towers in hand,
##   energy + "+N a round"), "Enemies in this level" as portrait chips "Slime ×3" (only once the level has been played
##   at least once; before that the same heading over one muted line "You'll see them when you play it.",
##   MenuLogic.has_played; the enemies fact tile always shows the kit's icon_enemy) whose tooltip has HP, Shield,
##   Speed, Power and the abilities with their cooldown; on the right the level's board as a rendered diorama
##   (TdLevelPreview → CoopBoardPic: 35°, contain, blurred margin; the pre-rendered PNG of LevelPreviewCache, live
##   only for a level without a fresh one), the first-win reward card (teal) and Play
##   (bottom-right, flat cobalt). A locked level shows the same panel greyed with its requirement and Play disabled.
## - Bottom: "Your hand" with a note ("Two Roads takes the first 4 towers; the rest wait on the bench."), all 8 slots
##   (miniature, cost coin, slot number; empty slots dashed "Empty"), a gold divider after the level's hand cap, the
##   zones "In this level: N" (gold underline) and "Bench", "N of 8 slots used" and Change hand (the hand editor popup).
## - Back bottom-left with its Esc key chip (UI Design Rules: full screens use Back bottom-left); Esc / right click too.
## A save without towers gets the catalog's starting towers. The last selected level is remembered
## (LevelProgress.last_selected). As a scene (SceneFlow.LevelSelect) Back goes to the main menu; in the Camp it is a
## full-screen panel showing one chapter (show_chapter) and Back closes it.

const HAND_EDITOR := "res://game/ui/screens/hand_editor.tscn"
## The layout's reference frame (centred: 16:10 and wider screens get even margins).
const FRAME := Vector2(1920, 1080)
const LIST_RECT := Rect2(64, 112, 470, 560)
const DETAIL_RECT := Rect2(566, 112, 1290, 560)
const HAND_RECT := Rect2(64, 696, 1792, 280)
const BACK_RECT := Rect2(64, 996, 210, 52)
const MAP_SIZE := Vector2(580, 300)
const ROW_SIZE := Vector2(408, 60)

## On in the Camp: one chapter, Back closes the panel.
var in_camp := false
var chapter_filter := -1
var selected := ""
var visible_rows: Array = []

var _catalog: LevelCatalog
var _asset: GameCatalogAsset
var _frame: Control
var _list: VBoxContainer
var _info: VBoxContainer
var _kicker: HBoxContainer
var _title: Label
var _desc: Label
var _facts: GridContainer
var _enemies_head: Label
var _enemies_note: Label
var _enemies: HFlowContainer
var _map_col: VBoxContainer
var _preview: TdLevelPreview
var _reward: PanelContainer
var _reward_title: Label
var _reward_line: Label
var _reward_icon: Control
var _play: TdMenuButton
var _note: Label
var _tray: HBoxContainer
var _slots_used: Label
var _popups: Control
var _rows: Array = []
var _pieces: Array = []
var _chips: Array = []

func _init() -> void:
	super._init()
	use_scrim = false
	right_click_closes = true # Esc and right click = Back (TdPopup routes both to back())

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
	_frame = Control.new()
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.size = FRAME
	_frame.set_anchors_preset(PRESET_CENTER)
	_frame.offset_left = -FRAME.x / 2.0; _frame.offset_right = FRAME.x / 2.0
	_frame.offset_top = -FRAME.y / 2.0; _frame.offset_bottom = FRAME.y / 2.0
	add_child(_frame)
	var title := TdMenu.label("Choose a level", "h1", TdTheme.color("cream.100"), 48)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.position = Vector2(64, 34)
	_frame.add_child(title)
	_build_list()
	_build_detail()
	_build_hand()
	var back_b := _key_button("Back", "icon_back", "", BACK_RECT.size)
	back_b.position = BACK_RECT.position
	back_b.pressed.connect(back)
	_frame.add_child(back_b)
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popups)

func _window(r: Rect2, pad: float) -> TdPanel:
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, pad)
	p.position = r.position
	p.size = r.size
	p.custom_minimum_size = r.size
	_frame.add_child(p)
	return p

# ------------------------------------------------------------------ build

func _build_list() -> void:
	var left := _window(LIST_RECT, 20)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	TdDragScroll.attach(scroll)
	_list = TdMenu.vbox(10)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list)

func _build_detail() -> void:
	var detail := _window(DETAIL_RECT, 28)
	var cols := TdMenu.hbox(32)
	detail.add_child(cols)
	# the text column sits in a plain Control: a long enemy list is cut off instead of growing the window
	var holder := Control.new()
	holder.size_flags_horizontal = SIZE_EXPAND_FILL
	holder.clip_contents = true
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	cols.add_child(holder)
	_info = TdMenu.vbox(0)
	_info.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# room for the fact tiles' rims (paper_stat hangs 2 px past its rect): the clip must not cut them
	_info.offset_left = 3.0
	_info.offset_right = -3.0
	holder.add_child(_info)
	_kicker = TdMenu.hbox(12)
	_info.add_child(_kicker)
	_title = TdMenu.label("", "h1", TdTheme.color("cream.100"), 52)
	_title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	_info.add_child(_title)
	_desc = TdMenu.wrap_label("", "body", TdTheme.color("cream.200"), 22)
	_desc.custom_minimum_size = Vector2(540, 0)
	_desc.size_flags_horizontal = SIZE_SHRINK_BEGIN
	_info.add_child(TdMenu.spacer(6))
	_info.add_child(_desc)
	# 12, not 18 (edge clip 2026-10-17): with 18 a two-line description, the facts and three rows of enemy chips
	# (The Glutton) ran 7 px past the clipping holder and the last row's chips were cut at the bottom
	_info.add_child(TdMenu.spacer(12))
	_facts = GridContainer.new()
	_facts.columns = 2
	_facts.add_theme_constant_override("h_separation", 12)
	_facts.add_theme_constant_override("v_separation", 12)
	_info.add_child(_facts)
	_info.add_child(TdMenu.spacer(12))
	_enemies_head = TdMenu.label("Enemies in this level", "plate", TdTheme.color("cream.300"), 20)
	_info.add_child(_enemies_head)
	# shown instead of the chips until the level has been played once (MenuLogic.EnemiesUnplayedText)
	_enemies_note = TdMenu.label(MenuLogic.EnemiesUnplayedText, "body", TdTheme.color("cream.300"))
	_enemies_note.visible = false
	_info.add_child(_enemies_note)
	_info.add_child(TdMenu.spacer(10))
	_enemies = HFlowContainer.new()
	_enemies.add_theme_constant_override("h_separation", 12)
	_enemies.add_theme_constant_override("v_separation", 10)
	_info.add_child(_enemies)
	# the right column: preview, reward, Play
	# 12 px gaps: preview 300 + reward + Play (with its bleed room) fit the window's 504 px inside (it never grows)
	_map_col = TdMenu.vbox(12)
	_map_col.custom_minimum_size = Vector2(MAP_SIZE.x, 0)
	cols.add_child(_map_col)
	# the preview: the picture in a rounded mask, a wood ring and a rim ring over it
	var map_frame := Control.new()
	map_frame.custom_minimum_size = MAP_SIZE
	map_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_map_col.add_child(map_frame)
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", _flat(Color("#1A130F"), 14))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mask.mouse_filter = MOUSE_FILTER_IGNORE
	map_frame.add_child(mask)
	_preview = TdLevelPreview.new()
	_preview.custom_minimum_size = MAP_SIZE
	_preview.size = MAP_SIZE
	mask.add_child(_preview)
	_preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for ring_def in [[TdTheme.color("wood.500"), 4, 14, 0], [TdTheme.color("rim"), 3, 17, 3]]:
		var ring := Panel.new()
		var rs := _flat(Color(0, 0, 0, 0), ring_def[2], ring_def[0], ring_def[1])
		rs.draw_center = false
		rs.expand_margin_left = ring_def[3]; rs.expand_margin_right = ring_def[3]
		rs.expand_margin_top = ring_def[3]; rs.expand_margin_bottom = ring_def[3]
		ring.add_theme_stylebox_override("panel", rs)
		ring.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		ring.mouse_filter = MOUSE_FILTER_IGNORE
		map_frame.add_child(ring)
	# the reward card
	_reward = PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.09, 0.067, 0.051, 0.55)
	rsb.border_color = Color(TdTheme.color("teal"), 0.35)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(14)
	rsb.content_margin_left = 16; rsb.content_margin_right = 16
	rsb.content_margin_top = 10; rsb.content_margin_bottom = 10
	_reward.add_theme_stylebox_override("panel", rsb)
	_reward.mouse_filter = MOUSE_FILTER_IGNORE
	_map_col.add_child(_reward)
	var rrow := TdMenu.hbox(14)
	_reward.add_child(rrow)
	_reward_icon = Control.new()
	_reward_icon.custom_minimum_size = Vector2(48, 48)
	_reward_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	_reward_icon.mouse_filter = MOUSE_FILTER_IGNORE
	rrow.add_child(_reward_icon)
	var rtext := TdMenu.vbox(0)
	rtext.size_flags_horizontal = SIZE_EXPAND_FILL
	rrow.add_child(rtext)
	_reward_title = TdMenu.label("", "plate", TdTheme.color("teal"), 22)
	rtext.add_child(_reward_title)
	_reward_line = TdMenu.label("", "small", TdTheme.color("cream.300"), 18)
	rtext.add_child(_reward_line)
	var fill := Control.new()
	fill.size_flags_vertical = SIZE_EXPAND_FILL
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	_map_col.add_child(fill)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_END
	_map_col.add_child(play_row)
	_play = TdMenuButton.new()
	_play.style = TdButton.Style.PRIMARY # flat: depth is for the main menu and Welcome only
	_play.custom_minimum_size = Vector2(300, 76)
	_play.size = Vector2(300, 76)
	_play.text = "Play"
	_play.font_size = 34
	_play.icon = TdTheme.texture("icon_play")
	_play.left_pad = 86
	_play.clicked.connect(play)
	play_row.add_child(_play)

func _build_hand() -> void:
	var hand := _window(HAND_RECT, 0)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	hand.add_child(pad)
	var row := TdMenu.hbox(24)
	pad.add_child(row)
	var col := TdMenu.vbox(8)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(col)
	var head := TdMenu.hbox(16)
	col.add_child(head)
	var ht := TdMenu.label("Your hand", "h3", TdTheme.color("cream.100"), 28)
	head.add_child(ht)
	_note = TdMenu.label("", "small", TdTheme.color("cream.300"), 20)
	_note.size_flags_vertical = SIZE_SHRINK_END
	head.add_child(_note)
	var tray_box := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = TdTheme.color("wood.800")
	tsb.border_color = TdTheme.color("rim")
	tsb.set_border_width_all(3)
	tsb.set_corner_radius_all(22)
	tsb.content_margin_left = 16; tsb.content_margin_right = 16
	tsb.content_margin_top = 10; tsb.content_margin_bottom = 8
	tray_box.add_theme_stylebox_override("panel", tsb)
	tray_box.size_flags_horizontal = SIZE_SHRINK_BEGIN
	tray_box.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(tray_box)
	_tray = TdMenu.hbox(6)
	tray_box.add_child(_tray)
	var side := TdMenu.vbox(14)
	side.custom_minimum_size = Vector2(300, 0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var change := _key_button("Change hand", "icon_cards", "", Vector2(300, 60))
	change.pressed.connect(open_hand_editor)
	side.add_child(change)
	_slots_used = TdMenu.label("", "small", TdTheme.color("cream.300"), 18)
	side.add_child(_slots_used)

## A wood button with an icon, its label and an optional key chip ("Esc").
func _key_button(text: String, icon_name: String, key: String, sz: Vector2) -> Button:
	var b := TdMenu.wood_button("", sz)
	b.size = sz
	var h := TdMenu.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(h)
	if icon_name != "" and TdTheme.has_sprite(icon_name):
		var ic := TdMenu.picture(TdTheme.texture(icon_name), Vector2(26, 26))
		ic.modulate = TdTheme.color("cream.100")
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := TdMenu.label(text, "h3", TdTheme.color("cream.100"), 24 if key != "" else 26)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(l)
	if key != "":
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", TdTheme.stylebox("kbd_paper", Color.WHITE, [8, 0, 8, 2]) if TdTheme.has_sprite("kbd_paper") else _flat(TdTheme.color("paper"), 7))
		chip.size_flags_vertical = SIZE_SHRINK_CENTER
		chip.mouse_filter = MOUSE_FILTER_IGNORE
		var kl := TdMenu.label(key, "micro", TdTheme.color("ink"), 18)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(kl)
		h.add_child(chip)
		b.tooltip_text = ""
	return b

static func _flat(c: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb

# ------------------------------------------------------------------ open / select

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
	if _is_unlocked(level_id): SaveData.progress.last_selected = level_id
	refresh(false)

func _is_unlocked(level_id: String) -> bool:
	for v in visible_rows:
		if v.entry.level_id == level_id: return v.unlocked
	return false

## Redraws the list, the selected level and the hand.
func refresh(pop := false) -> void:
	if _catalog == null: return
	visible_rows = MenuLogic.visible_levels(_catalog, SaveData.progress, chapter_filter)
	_draw_list(pop)
	var unlocked := _is_unlocked(selected)
	var level := _asset.find_level(selected)
	_draw_level(level, unlocked)
	_draw_hand(level, pop)
	_play.set_interactable(level != null and unlocked and SaveData.towers.hand.size() > 0,
		MenuLogic.requirement_line(_catalog, _asset, selected, SaveData.progress) if not unlocked else "No towers in your hand: add some with Change hand")

# ------------------------------------------------------------------ list

func _draw_list(pop: bool) -> void:
	for c in _list.get_children(): # removed at once: a queued child would still count below
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var progress := SaveData.progress
	for item in MenuLogic.list_items(_asset, visible_rows):
		if item.has("heading"):
			if _list.get_child_count() > 0: _list.add_child(TdMenu.spacer(8))
			var h := TdMenu.hbox(12)
			h.mouse_filter = MOUSE_FILTER_IGNORE
			var hl := TdMenu.label(item.heading, "h3", TdTheme.color("cream.200"), 26)
			hl.size_flags_horizontal = SIZE_EXPAND_FILL
			h.add_child(TdMenu.spacer(0, 4))
			h.add_child(hl)
			var tag := TdMenu.label(MenuLogic.chapter_tag(_catalog, progress, item.chapter), "plate", TdTheme.color("cream.300"), 18)
			tag.size_flags_vertical = SIZE_SHRINK_CENTER
			h.add_child(tag)
			h.add_child(TdMenu.spacer(0, 4))
			_list.add_child(h)
			continue
		var b := _row(item)
		_list.add_child(b)
		_rows.append(b)
	if pop: TdMenu.pop_in(_rows)

func _row(item: Dictionary) -> TdButton:
	var id: String = item.level_id
	var level := _asset.find_level(id)
	var state := MenuLogic.row_state(SaveData.progress, id, item.unlocked)
	var b := TdButton.new()
	b.style = TdButton.Style.ROW
	b.custom_minimum_size = ROW_SIZE
	b.size = ROW_SIZE
	b.text = ""
	b.selectable = true
	b.selected = id == selected
	var sel := b.selected
	var face := b.face_node()
	# the number medallion
	var num := Panel.new()
	num.add_theme_stylebox_override("panel", _flat(TdTheme.color("wood.600") if state == "locked" else TdTheme.color("paper"), 20, TdTheme.color("rim"), 2))
	num.position = Vector2(10, 10)
	num.size = Vector2(40, 40)
	num.mouse_filter = MOUSE_FILTER_IGNORE
	face.add_child(num)
	var nl := TdMenu.label(str(MenuLogic.level_number(_catalog, id)), "micro", TdTheme.color("cream.300") if state == "locked" else TdTheme.color("ink"), 22)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.size = Vector2(40, 40)
	nl.position = Vector2(0, -1)
	num.add_child(nl)
	# the name (and the requirement under it when locked)
	var name_col := TdMenu.vbox(0) # name 31 + requirement 26: fits the 60 px row without the lines touching
	name_col.position = Vector2(64, 0)
	name_col.size = Vector2(ROW_SIZE.x - 64 - 110, ROW_SIZE.y)
	name_col.alignment = BoxContainer.ALIGNMENT_CENTER
	name_col.mouse_filter = MOUSE_FILTER_IGNORE
	face.add_child(name_col)
	var name_text := level.get_display_name() if level != null else id
	var nm := TdMenu.label(name_text, "plate", Color.WHITE if sel else (TdTheme.color("cream.300") if state == "locked" else TdTheme.color("cream.100")), 22)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_col.add_child(nm)
	if state == "locked":
		name_col.size.x = ROW_SIZE.x - 64 - 52
		var req := TdMenu.label(MenuLogic.requirement_line(_catalog, _asset, id, SaveData.progress), "small", Color(1, 1, 1, 0.85) if sel else TdTheme.color("cream.300"), 18)
		req.clip_text = true
		req.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_col.add_child(req)
	# the right-hand state
	var end := _state_badge(state, sel)
	if end != null:
		end.position = Vector2(ROW_SIZE.x - 16 - end.get_combined_minimum_size().x, (ROW_SIZE.y - end.get_combined_minimum_size().y) / 2.0)
		face.add_child(end)
	if state == "locked" and not sel:
		b.set_extra_state("Locked")
		b.modulate.a = 0.6
	b.clicked.connect(func(): select(id)) # a locked row shows what opens it
	return b

## The row's right-hand state: "✓ Won" (good), "● New" (accent dot), a lock; null for none.
func _state_badge(state: String, sel: bool) -> Control:
	var h := TdMenu.hbox(6)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	match state:
		"won":
			var ic := TdMenu.picture(TdTheme.texture("icon_check"), Vector2(20, 20))
			ic.modulate = Color.WHITE if sel else TdTheme.color("good")
			ic.size_flags_vertical = SIZE_SHRINK_CENTER
			h.add_child(ic)
			h.add_child(TdMenu.label("Won", "plate", Color.WHITE if sel else TdTheme.color("good"), 18))
		"new":
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(16, 16)
			dot.add_theme_stylebox_override("panel", _flat(Color.WHITE if sel else TdTheme.color("accent.light"), 8, TdTheme.color("rim"), 2))
			dot.size_flags_vertical = SIZE_SHRINK_CENTER
			dot.mouse_filter = MOUSE_FILTER_IGNORE
			h.add_child(dot)
			h.add_child(TdMenu.label("New", "plate", Color.WHITE if sel else TdTheme.color("accent.light"), 18))
		"locked":
			var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(28, 28))
			lock.modulate = Color.WHITE if sel else TdTheme.color("cream.300")
			h.add_child(lock)
		_:
			return null
	h.size = h.get_combined_minimum_size()
	return h

# ------------------------------------------------------------------ detail

func _draw_level(level: LevelAsset, unlocked: bool) -> void:
	for c in _kicker.get_children(): c.queue_free()
	for c in _facts.get_children(): c.queue_free()
	for c in _enemies.get_children(): c.queue_free()
	_chips.clear()
	var dim := 1.0 if unlocked else 0.6
	_info.modulate = Color(1, 1, 1, 1)
	if level == null:
		_title.text = selected if selected != "" else "No level"
		_desc.text = "No level to play." if selected == "" else "This level is missing from the catalog."
		_enemies_head.visible = false
		_enemies_note.visible = false
		_reward.visible = false
		_preview.show_level(null)
		return
	var entry := _catalog.find(selected)
	var chapter := MenuLogic.chapter_name(_asset, entry.chapter) if entry != null else ""
	var state := MenuLogic.row_state(SaveData.progress, selected, unlocked)
	var k := TdMenu.label(MenuLogic.kicker_text(chapter, MenuLogic.level_number(_catalog, selected)), "plate", TdTheme.color("cream.300"), 20)
	_kicker.add_child(k)
	if state == "locked":
		var lock := TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(22, 22))
		lock.modulate = TdTheme.color("cream.200")
		lock.size_flags_vertical = SIZE_SHRINK_CENTER
		_kicker.add_child(lock)
		_kicker.add_child(TdMenu.label(MenuLogic.requirement_line(_catalog, _asset, selected, SaveData.progress), "plate", TdTheme.color("cream.100"), 20))
	else:
		var badge := _state_badge(state, false)
		if badge != null: _kicker.add_child(badge)
	_title.text = level.get_display_name()
	_title.modulate.a = dim
	_desc.text = TooltipText.from_rich(level.description)
	_desc.modulate.a = dim
	var f := MenuLogic.level_facts(level)
	# the enemies are a surprise until the first attempt: no portrait on the tile, no chips (MenuLogic.has_played)
	var played := MenuLogic.has_played(SaveData.progress, selected)
	var tiles := [
		_fact("icon_wave", str(f.waves), MenuLogic.plural(f.waves, "wave")),
		_fact("icon_enemy", str(f.enemies), MenuLogic.plural(f.enemies, "enemy", "enemies")), # always the kit's enemy glyph (UI review 2026-10-14)
		_fact("icon_cards", str(f.hand), MenuLogic.plural(f.hand, "tower") + " in hand"),
		_fact("icon_energy", str(f.energy), "energy", null, "+%d a round" % f.per_round),
	]
	for t in tiles:
		t.modulate.a = dim
		_facts.add_child(t)
	var counts := MenuLogic.enemy_counts(level) if played else []
	_enemies_head.visible = not played or not counts.is_empty()
	_enemies_head.modulate.a = dim
	_enemies_note.visible = not played
	_enemies_note.modulate.a = dim
	var compact := counts.size() > 4
	_enemies.add_theme_constant_override("v_separation", 8 if compact else 10)
	_enemies.add_theme_constant_override("h_separation", 10 if compact else 12)
	for pair in counts:
		var chip := _enemy_chip(pair[0], pair[1], compact)
		chip.modulate.a = dim
		_enemies.add_child(chip)
		_chips.append(chip)
	_draw_reward(entry, level)
	_preview.show_level(level)
	_preview.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.75, 0.75, 0.75, 0.6)

func _first_enemy_icon(level: LevelAsset) -> Texture2D:
	var counts := MenuLogic.enemy_counts(level)
	if counts.is_empty(): return null
	var e: EntityAsset = counts[0][0]
	return GameApp.icon_texture(e.icon) if e.icon != "" else null

## One fact tile (paper_stat): icon, value, word, and an optional gold-ink note on the right ("+25 a round").
func _fact(icon_name: String, value: String, word: String, icon_tex: Texture2D = null, note := "") -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TdTheme.stylebox("paper_stat", Color.WHITE, [14, 0, 14, 0]))
	p.custom_minimum_size = Vector2(0, 56)
	p.size_flags_horizontal = SIZE_EXPAND_FILL
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := TdMenu.hbox(8)
	p.add_child(h)
	var tex := icon_tex if icon_tex != null else (TdTheme.texture(icon_name) if icon_name != "" else null)
	if tex != null:
		var ic := TdMenu.picture(tex, Vector2(24, 24))
		if icon_tex == null: ic.modulate = TdTheme.color("gold.ink") if icon_name == "icon_energy" else TdTheme.color("ink.2")
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
	var v := TdMenu.label(value, "micro", TdTheme.color("ink"), 28)
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(v)
	var w := TdMenu.label(word, "small", TdTheme.color("ink.2"), 20)
	w.size_flags_vertical = SIZE_SHRINK_CENTER
	w.size_flags_horizontal = SIZE_EXPAND_FILL
	w.clip_text = true
	w.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(w)
	if note != "":
		var n := TdMenu.label(note, "plate", TdTheme.color("gold.ink"), 18)
		n.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(n)
	return p

## An enemy chip: portrait, name, "×3"; hovering it shows its tooltip and lights the rim.
func _enemy_chip(e: EntityAsset, count: int, compact := false) -> Control:
	var p := PanelContainer.new()
	var normal := _flat(TdTheme.color("wood.900"), 28, TdTheme.color("rim"), 2)
	normal.content_margin_left = 6; normal.content_margin_right = 14
	normal.content_margin_top = 3; normal.content_margin_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = TdTheme.color("accent.light")
	hover.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", normal)
	p.custom_minimum_size = Vector2(0, 44 if compact else 56)
	p.mouse_filter = MOUSE_FILTER_STOP
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", hover))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", normal))
	var h := TdMenu.hbox(10)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(h)
	var tex: Texture2D = GameApp.icon_texture(e.icon) if e.icon != "" else null
	if tex == null: tex = TdMenu.unit_picture(e.view, e.icon)
	var m := TdMenu.medallion(tex, 34 if compact else 44, true)
	m.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(m)
	var n := TdMenu.label(MenuLogic.entity_name(e), "plate", TdTheme.color("cream.100"), 18 if compact else 20)
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(n)
	var c := TdMenu.label("×%d" % count, "micro", TdTheme.color("cream.200"), 20 if compact else 22)
	c.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(c)
	var tip := enemy_tooltip(e)
	TdTooltipTrigger.attach(p, tip.header, tip.body, tip.footer_label, tip.footer_value)
	return p

## The enemy chip's tooltip (TooltipText.enemy): name, "Enemy", the description, one line of HP · Shield · Speed ·
## Power (DefStats: the definition's base stats; Shield = what its passives give it on arrival), then each ability
## with its cooldown ("Path Walk: 1 turn CD").
static func enemy_tooltip(e: EntityAsset) -> Dictionary:
	var def: EntityDef = GameApp.convert.entity(e) if GameApp.convert != null else null
	if def == null: return TooltipText.enemy(MenuLogic.entity_name(e), e.description)
	var me := DefStats.new(def)
	var vocab: Vocabulary = GameApp.rules.vocabulary if GameApp.rules != null else CombatVocabulary.create()
	var stat_line := []
	stat_line.append(["MaxHp", _num(me.stat("MaxHp")), "HP"])
	var parts := HudArt.tag_line(stat_line, 18)
	var shield := MenuLogic.spawn_shield(e)
	if shield > 0:
		var icon := "res://art/icons/Statuses/Shield.png"
		var img := "[img=20x20]%s[/img] " % icon if ResourceLoader.exists(icon) else ""
		parts += "  %s[b]%d[/b] Shield" % [img, shield]
	var more := []
	var sp = AbilityText.speed(me, vocab)
	if sp != null: more.append(["Speed", _num(sp), "Speed"])
	var pw = AbilityText.own_stat(me, "Power", vocab)
	if pw != null: more.append(["Power", _num(pw), "Power"])
	if not more.is_empty(): parts += "  " + HudArt.tag_line(more, 18)
	var abilities := []
	for ab in def.abilities:
		if ab == null: continue
		abilities.append(TooltipText.row(ab.display_name, TooltipText.cooldown_words(ab.cooldown, ab.cooldown_until_reset)))
	var body := TooltipText.body(TooltipText.describe(TooltipText.from_rich(e.description)),
		["[font_size=20]%s[/font_size]" % parts], abilities)
	return TooltipText.content(TooltipText.title(MenuLogic.entity_name(e), TooltipText.enemy_color(), "Enemy"), body)

static func _num(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else str(snappedf(f, 0.01))

func _draw_reward(entry: CatalogEntry, level: LevelAsset) -> void:
	var reward: TowerAsset = null
	for e in _asset.entries():
		if e[0].level == level: reward = e[0].first_clear_reward
	_reward.visible = reward != null
	if reward == null: return
	# a tower shown as a prize is discovered in the Codex (Eren 2026-10-17)
	if SaveData.codex.discover(CodexSection.Towers, reward.get_id()): SaveData.save()
	var won := SaveData.progress.is_won(selected)
	var lines := MenuLogic.reward_lines(reward.get_display_name(), won)
	_reward_title.text = lines[0]
	_reward_line.text = lines[1]
	for c in _reward_icon.get_children(): c.queue_free()
	if won:
		var ic := TdMenu.picture(TdTheme.texture("icon_check"), Vector2(26, 26))
		ic.modulate = TdTheme.color("good")
		ic.position = Vector2(11, 11)
		_reward_icon.add_child(ic)
		_reward_icon.custom_minimum_size = Vector2(48, 48)
	else:
		var view := reward.entity.view if reward.entity != null else ""
		var m := TdMenu.medallion(TdMenu.unit_picture(view, reward.icon), 48)
		_reward_icon.add_child(m)
	_reward.modulate.a = 1.0 if _is_unlocked(selected) else 0.6

# ------------------------------------------------------------------ hand

func _draw_hand(level: LevelAsset, pop: bool) -> void:
	for c in _tray.get_children():
		_tray.remove_child(c)
		c.queue_free()
	_pieces.clear()
	var towers := SaveData.towers
	var cap := clampi(level.hand_cap if level != null else TowerCollection.MaxHand, 0, TowerCollection.MaxHand)
	for i in TowerCollection.MaxHand:
		if i == cap and cap > 0 and cap < TowerCollection.MaxHand: _tray.add_child(_cut())
		var piece := HandSlot.new()
		if i < towers.hand.size():
			var owned := towers.find(towers.hand[i])
			var type := _asset.find_tower(owned.type) if owned != null else null
			piece.setup(owned, type, i, i >= cap)
		else:
			piece.setup(null, null, i, i >= cap)
		piece.pressed.connect(open_hand_editor)
		_tray.add_child(piece)
		_pieces.append(piece)
	_note.text = MenuLogic.hand_strip_note(level.get_display_name() if level != null else "", towers.hand.size(), cap)
	_slots_used.text = MenuLogic.slots_used_text(towers.hand.size())
	if pop: TdMenu.pop_in(_pieces, 0.03)

func _cut() -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(4, 150)
	c.add_theme_stylebox_override("panel", _flat(TdTheme.color("gold"), 2, TdTheme.color("rim"), 1))
	c.size_flags_vertical = SIZE_SHRINK_CENTER
	c.mouse_filter = MOUSE_FILTER_IGNORE
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 6)
	wrap.add_theme_constant_override("margin_right", 6)
	wrap.mouse_filter = MOUSE_FILTER_IGNORE
	wrap.add_child(c)
	return wrap

## Opens the hand editor popup over this screen (with the selected level, for its hand cap); returns it.
func open_hand_editor() -> TdPopup:
	var he: TdPopup = load(HAND_EDITOR).instantiate()
	he.free_on_close = true
	var lv := _asset.find_level(selected) if _asset != null else null
	if "level" in he: he.set("level", lv)
	_popups.add_child(he)
	if he.has_signal("changed"): he.connect("changed", func(): refresh(false))
	he.closed.connect(func(): if is_instance_valid(self): refresh(false))
	he.open()
	return he

## Plays the selected level.
func play() -> void:
	var level := _asset.find_level(selected) if _asset != null else null
	if level == null or not _is_unlocked(selected): return
	SaveData.progress.last_selected = selected
	SaveData.save()
	GameApp.play_level(level)

## Closing drops the preview's pending live render first, so no SubViewport is still rendering (and nothing swaps in)
## after the panel is gone (the 1-frame flash on close, 2026-10-17). With pre-rendered previews there is none.
func close() -> void:
	if _preview != null: _preview.cancel()
	super.close()

func back() -> void:
	SaveData.save()
	if in_camp: close()
	else: SceneFlow.go(SceneFlow.MainMenu)

# ------------------------------------------------------------------ a hand slot

## One of the 8 slots of the hand strip (mockup .k-piece, 124 × 150): the tower's miniature over its shadow, the gold
## cost coin top-left, the slot number top-right, the name plate; benched slots greyed; an empty slot is a dashed
## plinth outline with "Empty". Hover lifts the miniature and rings the plate; a click opens Change hand.
class HandSlot extends Control:
	signal pressed

	const SLOT := Vector2(124, 150)

	var empty := true
	var bench := false
	var _mini: TextureRect
	var _plate: TdButton
	var _coin: Panel
	var _hovered := false

	func _init() -> void:
		custom_minimum_size = SLOT
		size = SLOT
		mouse_filter = MOUSE_FILTER_STOP
		mouse_entered.connect(func(): _hovered = true; _restyle())
		mouse_exited.connect(func(): _hovered = false; _restyle())

	func setup(owned: OwnedTower, type: TowerAsset, index: int, benched: bool) -> void:
		empty = owned == null
		bench = benched
		if not empty:
			var shadow := TdMenu.picture(TdTheme.texture("piece_shadow"), Vector2(104, 30))
			shadow.stretch_mode = TextureRect.STRETCH_SCALE
			shadow.position = Vector2(10, SLOT.y - 30 - 30)
			add_child(shadow)
			var tex: Texture2D = null
			if type != null and type.entity != null:
				tex = GameApp.icon_texture(type.entity.miniature) if type.entity.miniature != "" else null
				if tex == null: tex = TdMenu.unit_picture(type.entity.view, type.icon)
			_mini = TdMenu.picture(tex, Vector2(112, 112))
			_mini.position = Vector2(6, SLOT.y - 34 - 112)
			_mini.pivot_offset = Vector2(56, 112)
			if bench: _mini.modulate = Color(0.55, 0.55, 0.55, 0.5)
			add_child(_mini)
			# a formed tower: its form badge on the miniature (the plate already says the form's name)
			TdFormBadge.attach(_mini, MenuLogic.form_badge(MenuLogic.form_in(owned, type)), 112, 0.26, Vector2(0.86, 0.78))
			if type != null:
				var coin := Panel.new()
				coin.add_theme_stylebox_override("panel", LevelSelectStyle.coin(bench))
				coin.position = Vector2(2, 4)
				coin.size = Vector2(42, 42)
				coin.mouse_filter = MOUSE_FILTER_IGNORE
				var cl := TdMenu.label(str(type.cost), "micro", Color("#2A1D00"), 18 if type.cost < 1000 else 14)
				cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cl.size = coin.size
				coin.add_child(cl)
				if bench: coin.modulate.a = 0.6
				add_child(coin)
				_coin = coin
		else:
			var ghost := DashedEllipse.new()
			ghost.position = Vector2((SLOT.x - 96) / 2.0, SLOT.y - 40 - 34)
			ghost.size = Vector2(96, 34)
			add_child(ghost)
		var key := TdMenu.label(str(index + 1), "micro", TdTheme.color("cream.200"), 20)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.position = Vector2(SLOT.x - 40, 4)
		key.size = Vector2(34, 24)
		key.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
		key.add_theme_constant_override("shadow_offset_y", 2)
		key.visible = not empty
		add_child(key)
		_plate = TdButton.new()
		_plate.style = TdButton.Style.NAME_PLATE
		_plate.custom_minimum_size = Vector2(120, 30)
		_plate.size = Vector2(120, 30)
		_plate.text = "Empty" if empty else MenuLogic.tower_name(owned, type)
		_plate.mouse_filter = MOUSE_FILTER_IGNORE
		_plate.position = Vector2(2, SLOT.y - 32)
		if empty or bench: _plate.set_extra_state("Locked")
		add_child(_plate)
		if bench: modulate.a = 0.8 # benched slots a little dimmer (as in hand select)

	func _restyle() -> void:
		if _plate != null:
			_plate.force_state(_hovered, false)
		if _mini != null:
			var tw := TdTheme.tween(_mini)
			tw.set_parallel(true)
			tw.tween_property(_mini, "position:y", SLOT.y - 34 - 112 - (12.0 if _hovered else 0.0), TdTheme.motion("quick"))
			tw.tween_property(_mini, "scale", Vector2.ONE * (1.06 if _hovered else 1.0), TdTheme.motion("quick"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position): pressed.emit()
			accept_event()

## The empty slot's dashed plinth outline.
class DashedEllipse extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Color(0.933, 0.886, 0.776, 0.3)
		var center := size / 2.0
		var r := size / 2.0 - Vector2(1.5, 1.5)
		var n := 28
		for i in n:
			if i % 2 == 1: continue
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var pts := PackedVector2Array()
			for s in 5:
				var a := lerpf(a0, a1, s / 4.0)
				pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
			draw_polyline(pts, c, 3.0, true)

## Small shared styles.
class LevelSelectStyle:
	## The gold cost coin (mockup .k-piece .coin: 42 px, gold with a dark rim).
	static func coin(_bench: bool) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FFCF4D")
		sb.border_color = TdTheme.color("rim")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(21)
		sb.shadow_color = Color("#6D4A08")
		sb.shadow_offset = Vector2(0, 2)
		sb.shadow_size = 1
		return sb
