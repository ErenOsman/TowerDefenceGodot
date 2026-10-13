extends Control
## The Camp (UI_Camp.cs; Camp & Chapters — Design): the home between levels once Chapter 1 is won. A small 3D
## camp (map-kit ground with the camp props: War Table, Miniature Shelf, Codex Lectern, Tower Workshop, Signal Post,
## Tent, Campfire, Supplies) with a station button over each prop: Chapters (the chapter picker, then a chapter's
## levels), Towers (the hand editor over every owned tower), Codex, and Main menu; Workshop and Multiplayer are
## locked ("Coming later"). The first visit (PlayerProfile.camp_seen) shows a welcome card, then a tour: the
## Princess's speech bubble (TdTextBubble) points at each station in turn, the station highlighted; a click goes on,
## Skip ends it. Map music comes from SceneFlow (AudioMgr.play_scene_music).

const SCREENS := "res://game/ui/screens/"
## [id, label, icon, prop, tile position (x, depth), prop scale, locked]
const STATIONS := [
	["Chapters", "Chapters", "icon_castle", "War Table", Vector2(2.2, 2.0), 1.7, false],
	["Towers", "Towers", "icon_cards", "Miniature Shelf", Vector2(0.9, 3.4), 1.5, false],
	["Codex", "Codex", "icon_codex", "Codex Lectern", Vector2(3.9, 3.5), 1.7, false],
	["Workshop", "Workshop", "icon_edit", "Tower Workshop", Vector2(6.0, 3.1), 1.6, true],
	["Multiplayer", "Multiplayer", "icon_onboard", "Signal Post", Vector2(6.6, 1.1), 1.4, true],
]
const DECOR := [["Campfire", Vector2(4.1, 1.5), 1.6, 0.0], ["Tent", Vector2(0.4, 1.0), 1.6, 35.0], ["Supplies", Vector2(5.3, 0.3), 1.5, -20.0]]
const TOUR := [
	["Chapters", "Chapters: pick a chapter, then a level. Side chapters appear here as you open them."],
	["Towers", "Towers: every tower you own. Choose which ones you bring in your hand."],
	["Codex", "Codex: every tower, enemy and status you have met, and tips."],
	["Workshop", "Workshop: changing your towers comes later."],
	["Multiplayer", "Multiplayer: playing with others comes later."],
]
const TOUR_SPEAKER := "Princess"
const GROUND := Vector2i(8, 5)

var buttons := {}       # station id → TdMenuButton
var props := {}         # station id → Node3D
var tour_step := -1
var bubble: TdTextBubble
var welcome_card: Control
var popups: Control

var _vp: SubViewport
var _cam: Camera3D
var _highlighted: TdButton

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	TdMenu.wood_background(self)
	_build_world()
	_build_ui()
	if GameApp.catalog != null and GameApp.catalog.grant_starting_towers(SaveData.towers): SaveData.save()
	welcome_card.visible = not SaveData.profile.camp_seen
	if welcome_card.visible:
		await get_tree().process_frame
		TdPanelTransition.open(welcome_card.get_child(0))

# ------------------------------------------------------------------ the 3D camp

func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	TdDiorama._add_light(root, TdTheme.color("wood.900"))
	# the ground: the map kit's ground pieces (BoardView over an empty map)
	var level := LevelAsset.new()
	var rows: Array[String] = []
	for y in GROUND.y: rows.append(".".repeat(GROUND.x))
	level.terrain = rows
	var board := BoardView.new()
	root.add_child(board)
	var kit: Array = GameApp.lib.rules.tiles if GameApp.lib.rules != null else []
	board.build(BattleGrid.new(GROUND.x, GROUND.y), level, kit, func(p): return GameApp.model_scene(p))
	for s in STATIONS: props[s[0]] = _prop(root, s[3], s[4], s[5], 0.0)
	for d in DECOR: _prop(root, d[0], d[1], d[2], d[3])
	_cam = Camera3D.new()
	_cam.fov = 34.0
	root.add_child(_cam)
	_cam.current = true
	var c := Vector3((GROUND.x - 1) / 2.0, 0.0, -(GROUND.y - 1) / 2.0)
	_cam.position = c + Vector3(0, 7.2, 8.6)
	_cam.look_at(c + Vector3(0, 0, -0.2), Vector3.UP)

func _prop(root: Node3D, prop: String, at: Vector2, scale_by: float, yaw: float) -> Node3D:
	var sc: PackedScene = GameApp.camp_scene(prop)
	if sc == null: return null
	var m: Node3D = sc.instantiate()
	m.position = Vector3(at.x, 0.0, -at.y)
	m.scale = Vector3.ONE * scale_by
	m.rotation_degrees.y = yaw
	root.add_child(m)
	TdDiorama._idle(m)
	return m

## A prop's top in canvas coordinates (where its station button goes).
func _screen_of(n: Node3D, lift := 1.25) -> Vector2:
	if n == null or _cam == null: return Vector2.ZERO
	var p := _cam.unproject_position(n.global_position + Vector3(0, lift * n.scale.y, 0))
	return p * (size / Vector2(_vp.size)) if _vp.size.x > 0 else p

# ------------------------------------------------------------------ the UI

func _build_ui() -> void:
	var title := TdMenu.label("Camp", "display", TdTheme.color("cream.100"), 64)
	title.position = Vector2(58, 28)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)
	var sub := TdMenu.label("Your home between levels", "body", TdTheme.color("cream.200"), 24)
	sub.position = Vector2(62, 112)
	add_child(sub)
	for s in STATIONS:
		var b := TdMenuButton.new()
		b.style = TdButton.Style.MENU_PRIMARY if s[0] == "Chapters" else TdButton.Style.MENU_WOOD
		b.custom_minimum_size = Vector2(290, 72 if s[6] else 64)
		b.size = b.custom_minimum_size
		b.text = s[1]
		b.icon = TdTheme.texture(s[2])
		b.selectable = true
		b.left_pad = 24
		add_child(b)
		buttons[s[0]] = b
		if s[6]:
			b.sub = "Coming later"
			b.set_interactable(false, "Coming later")
	buttons["Chapters"].clicked.connect(func(): open_chapters())
	buttons["Towers"].clicked.connect(func(): open_towers())
	buttons["Codex"].clicked.connect(func(): open_popup("codex"))
	var menu := TdMenuButton.new()
	menu.style = TdButton.Style.MENU_WOOD
	menu.custom_minimum_size = Vector2(290, 64)
	menu.size = menu.custom_minimum_size
	menu.text = "Main menu"
	menu.icon = TdTheme.texture("icon_back")
	menu.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	menu.offset_left = 60; menu.offset_top = -110; menu.offset_right = 350; menu.offset_bottom = -46
	menu.clicked.connect(func(): SceneFlow.go(SceneFlow.MainMenu))
	add_child(menu)
	buttons["MainMenu"] = menu
	popups = Control.new()
	popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(popups)
	bubble = TdTextBubble.new()
	bubble.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bubble)
	bubble.letters_per_second = 60.0
	bubble.hide_bubble()
	bubble.clicked.connect(func(): show_tour_step(tour_step + 1))
	bubble.skip_clicked.connect(end_tour)
	_build_welcome()
	resized.connect(_place_buttons)
	_place_buttons.call_deferred()

func _place_buttons() -> void:
	for s in STATIONS:
		var b: TdButton = buttons[s[0]]
		var p := _screen_of(props.get(s[0]))
		b.position = p - Vector2(b.size.x / 2.0, b.size.y)

func _build_welcome() -> void:
	welcome_card = Control.new()
	welcome_card.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(welcome_card)
	var scrim := TdScrim.new()
	scrim.color = Color(TdTheme.color("scrim"), 0.6)
	welcome_card.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	welcome_card.add_child(center)
	welcome_card.move_child(center, 0)
	welcome_card.move_child(scrim, 0)
	var p := TdMenu.panel(TdPanel.Kind.MENU, 0)
	p.custom_minimum_size = Vector2(760, 0)
	center.add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 48)
	p.add_child(m)
	var col := TdMenu.vbox(14)
	m.add_child(col)
	var eyebrow := TdMenu.label("CHAPTER 1 COMPLETE", "micro", TdTheme.color("gold"), 22)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(eyebrow)
	var t := TdMenu.label("Welcome to the Camp", "plaque_title", TdTheme.color("cream.100"), 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var l := TdMenu.wrap_label("This is your home between levels. From here you pick a chapter and a level, choose the towers you bring, and read the Codex.", "body", TdTheme.color("cream.200"), 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(660, 0)
	col.add_child(l)
	col.add_child(TdMenu.spacer(10))
	var row := CenterContainer.new()
	col.add_child(row)
	var ok := TdMenuButton.new()
	ok.style = TdButton.Style.MENU_PRIMARY
	ok.custom_minimum_size = Vector2(320, 68)
	ok.size = ok.custom_minimum_size
	ok.text = "Look around"
	ok.icon = TdTheme.texture("icon_play")
	ok.left_pad = 40
	ok.clicked.connect(close_welcome)
	row.add_child(ok)
	welcome_card.visible = false

## The first visit's welcome card is closed: never shown again; the tour starts.
func close_welcome() -> void:
	welcome_card.visible = false
	if not SaveData.profile.camp_seen:
		SaveData.profile.camp_seen = true
		SaveData.save()
	show_tour_step(0)

## Shows a tour step (stations missing are skipped): the bubble at the station, the station highlighted.
func show_tour_step(index: int) -> void:
	if _highlighted != null: _highlighted.selected = false
	_highlighted = null
	while index < TOUR.size():
		var b: TdButton = buttons.get(TOUR[index][0])
		if b == null or not b.visible:
			index += 1
			continue
		tour_step = index
		_highlighted = b
		b.selected = true
		bubble.show_line(TOUR_SPEAKER, TOUR[index][1], true, GameApp.portrait_texture("Princess"))
		bubble.set_hint("Tour · %d/%d" % [index + 1, TOUR.size()], "Click or [b]%s[/b]" % KeyBinds.first(KeyBinds.Skip))
		bubble.point_at(b.get_global_rect().get_center() + Vector2(0, b.size.y * 0.5))
		return
	end_tour()

func end_tour() -> void:
	tour_step = -1
	if _highlighted != null: _highlighted.selected = false
	_highlighted = null
	bubble.hide_bubble()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if welcome_card.visible and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		close_welcome()
		get_viewport().set_input_as_handled()
	elif tour_step >= 0 and TdPopup.open_popups.is_empty():
		if event.keycode == KEY_ESCAPE:
			end_tour()
			get_viewport().set_input_as_handled()
		elif KeyBinds.combo_from_event(event) != null and KeyBinds.combo_from_event(event).equals(KeyBinds.get_bind(KeyBinds.Skip, 0)):
			if bubble.is_fully_shown(): show_tour_step(tour_step + 1)
			else: bubble.reveal_all()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ stations

## Opens a popup by its scene name; returns it.
func open_popup(scene: String) -> TdPopup:
	end_tour()
	var p: TdPopup = load(SCREENS + scene + ".tscn").instantiate()
	p.free_on_close = true
	popups.add_child(p)
	p.open()
	return p

## Chapters: the chapter picker.
func open_chapters() -> TdPopup:
	var p := open_popup("chapter_select")
	p.chapter_opened.connect(open_chapter)
	return p

## A chapter's levels: the level select panel showing that chapter (Back closes it).
func open_chapter(chapter: int) -> TdPopup:
	var ls: TdPopup = load(SCREENS + "level_select.tscn").instantiate()
	ls.in_camp = true
	ls.chapter_filter = chapter
	ls.free_on_close = true
	popups.add_child(ls)
	ls.open()
	return ls

## Towers: the hand editor over every owned tower.
func open_towers() -> TdPopup:
	return open_popup("hand_editor")
