extends Control
## The Camp (UI_Camp.cs; Camp & Chapters — Design): the home between levels once Chapter 1 is won. A 3D camp
## laid out from res://art/camp/layout.json (map-kit ground with its frame, the station props on a ring round the
## Campfire, all facing the camera; Tent and Supplies) with a station button over each prop: Chapters (the chapter picker, then a chapter's
## levels), Towers (the hand editor over every owned tower), Codex, Workshop (towers into their forms: workshop.gd; locked
## until Chapter 2 is cleared, MenuLogic.workshop_unlocked), and
## Main menu; Multiplayer (the co-op lobby, until the Guild opens: then gone, the lobby lives in the Guild). The
## Signpost has NO station button (user decision 2026-10-14): the prop itself is the way to the Guild, like the Guild
## Door — hover glow + "Guild · missions and co-op", click opens the Guild, a gold "New" floats by it until the first
## Guild visit; before Chapter 2 it is dimmed, its tooltip says "Opens after Chapter 2" and a click shakes it. The
## first visit (PlayerProfile.camp_seen) shows a welcome card, then a tour: the
## Princess's speech bubble (TdTextBubble) points at each station in turn, the station highlighted; a click goes on,
## Skip ends it. Map music comes from SceneFlow (AudioMgr.play_scene_music).

const SCREENS := "res://game/ui/screens/"
## Where the props stand: the Blender agent's camp layout (source of truth). Board 18×9 tiles, x left→right,
## depth front→back; Godot position = Vector3(x, 0, -depth); yaw = rotation_degrees.y.
const LAYOUT := "res://art/camp/layout.json"
## The stations, data-driven: adding one = an entry here + a slot with its name in layout.json.
## {id, label, icon, action (method name, "" for none), locked}
const STATIONS := [
	{"id": "Towers", "label": "Towers", "icon": "icon_cards", "action": "open_towers", "locked": false},
	{"id": "Chapters", "label": "Chapters", "icon": "icon_castle", "action": "open_chapters", "locked": false, "primary": true},
	{"id": "Codex", "label": "Codex", "icon": "icon_codex", "action": "open_codex", "locked": false},
	{"id": "Workshop", "label": "Workshop", "icon": "icon_edit", "action": "open_workshop", "locked": false, "gate": "workshop"},
	{"id": "Multiplayer", "label": "Multiplayer", "icon": "icon_onboard", "action": "open_multiplayer", "locked": false, "gate": "moved"},
]
## Used when layout.json cannot be read (same values as layout.json, the ring layout of 2026-10-13).
const FALLBACK_LAYOUT := {
	"board": {"tiles": [14, 10], "ground": "map kit (BoardView ground pieces + frame)"},
	"ring": {"centre": [6.5, 4.6], "radius": [5.2, 3.3], "slots": 7, "first_angle_deg": 90},
	"centre": {"prop": "Campfire", "tile": [6.5, 4.6], "scale": 3.0, "yaw": 0},
	"slots": [
		{"slot": 0, "tile": [6.5, 7.9], "face_yaw": 0.0, "row": "back", "station": "Chapters", "prop": "War Table", "scale": 3.2},
		{"slot": 1, "tile": [2.43, 6.66], "face_yaw": 0.0, "row": "back", "station": "Towers", "prop": "Miniature Shelf", "scale": 3.4},
		{"slot": 2, "tile": [1.43, 3.87], "face_yaw": 0.0, "row": "front", "station": "Workshop", "prop": "Tower Workshop", "scale": 3.2},
		{"slot": 3, "tile": [4.24, 1.63], "face_yaw": 0.0, "row": "front", "station": null, "prop": null},
		{"slot": 4, "tile": [8.76, 1.63], "face_yaw": 0.0, "row": "front", "station": "Missions", "prop": "Signpost", "scale": 2.6},
		{"slot": 5, "tile": [11.57, 3.87], "face_yaw": 0.0, "row": "front", "station": "Multiplayer", "prop": "Signal Post", "scale": 2.4},
		{"slot": 6, "tile": [10.57, 6.66], "face_yaw": 0.0, "row": "back", "station": "Codex", "prop": "Codex Lectern", "scale": 3.2},
	],
	"decor": [{"prop": "Tent", "tile": [4.45, 8.85], "scale": 2.1, "yaw": 0}, {"prop": "Supplies", "tile": [12.2, 8.9], "scale": 2.6, "yaw": -15}],
}
const BOARD := Vector2(14, 10)
const TOUR := [
	["Chapters", "Chapters: pick a chapter, then a level. Side chapters appear here as you open them."],
	["Towers", "Towers: every tower you own. Choose which ones you bring in your hand."],
	["Codex", "Codex: every tower, enemy and status you have met, and tips."],
	["Workshop", "Workshop: changing your towers comes later."],
	["Multiplayer", "Multiplayer: play a level together with friends online, each with your own towers."],
	["Missions", "The Signpost: after Chapter 2 it leads to the Guild, where missions earn tokens for the Workshop."],
]
const TOUR_SPEAKER := "Princess"

var buttons := {}       # station id → TdMenuButton
var props := {}         # station id → Node3D
var _front := {}        # station id → true when its slot is on the front of the ring (button below the prop)
var _board := BOARD
var tour_step := -1
var bubble: TdTextBubble
var welcome_card: Control
var popups: Control

var world: TdStationWorld
## The Signpost's hotspot (the way to the Guild) and its floating "New".
var signpost: Control
var signpost_tag: Control
const SIGNPOST := "Missions"
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
	elif has_node("/root/Net") and get_node("/root/Net").reopen_lobby: # back from a co-op match
		get_node("/root/Net").reopen_lobby = false
		open_multiplayer.call_deferred()

# ------------------------------------------------------------------ the 3D camp (TdStationWorld, shared with the Guild)

func _build_world() -> void:
	world = TdStationWorld.new()
	add_child(world)
	world.build(load_layout(), func(p): return GameApp.camp_scene(p), true)
	props = world.props
	_front = world.front
	_vp = world.vp
	_cam = world.cam
	_board = world.board

## The camp layout (layout.json), or the built-in copy when it cannot be read.
static func load_layout() -> Dictionary:
	return TdStationWorld.load_layout(LAYOUT, FALLBACK_LAYOUT)

static func _tile(t) -> Vector2:
	return TdStationWorld.tile_of(t)

func _prop_rect(n: Node3D) -> Rect2:
	return world.prop_rect(n)

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
	for st in STATIONS:
		var b := TdMenuButton.new()
		b.style = TdButton.Style.MENU_PRIMARY if st.get("primary", false) else TdButton.Style.MENU_WOOD
		b.custom_minimum_size = Vector2(236, 72 if st.locked else 60)
		b.size = b.custom_minimum_size
		b.text = st.label
		b.icon = TdDrops.icon_texture(st.icon.trim_prefix("extra:")) if st.icon.begins_with("extra:") else TdTheme.texture(st.icon)
		b.selectable = true
		b.left_pad = 20
		b.font_size = 26
		add_child(b)
		buttons[st.id] = b
		var locked_line := "Coming later" if st.locked else ""
		if st.get("gate", "") == "workshop" and not MenuLogic.workshop_unlocked(GameApp.catalog, SaveData.progress):
			locked_line = MenuLogic.workshop_locked_text(GameApp.catalog) # "Opens after Chapter 2"
		var action: String = st.action
		if st.get("gate", "") == "moved" and GameApp.guild_unlocked(): b.visible = false # the lobby lives in the Guild
		if locked_line != "":
			# locked (UI review 2026-10-14): a lock icon, "Opens after Chapter 2", the Disabled look
			b.custom_minimum_size = Vector2(maxf(236.0, 90.0 + TdTheme.font("nunito_bold").get_string_size(locked_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x), 72)
			b.size = b.custom_minimum_size
			b.icon = TdTheme.texture("icon_lock")
			b.sub = locked_line
			b.set_interactable(false, locked_line)
		elif action != "":
			b.clicked.connect(Callable(self, action))
		if not props.has(st.id): b.visible = false # no slot for it in the layout yet
		if not b.visible and b.has_meta("leader"): b.get_meta("leader").visible = false
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
	# the speaker's plate in teal (cobalt means "active" in style B)
	var plate := StyleBoxFlat.new()
	plate.bg_color = TdTheme.color("teal")
	plate.set_corner_radius_all(10)
	bubble._plate.add_theme_stylebox_override("panel", plate)
	bubble._name.add_theme_color_override("font_color", TdTheme.color("ink"))
	bubble.clicked.connect(func(): show_tour_step(tour_step + 1))
	bubble.skip_clicked.connect(end_tour)
	_build_welcome()
	_build_signpost()
	resized.connect(_place_buttons)
	_place_buttons.call_deferred()

## Each station's button sits above its prop with a leader line down to it (re-placed every frame: the 3D view's
## size settles late); TdStationWorld.place_buttons keeps them apart.
func _place_buttons() -> void:
	if world == null: return
	world.place_buttons(self, buttons, STATIONS.map(func(st): return st.id))
	world.place_hotspots()
	if signpost_tag != null and props.get(SIGNPOST) != null:
		var r := world.prop_rect(props[SIGNPOST])
		# just above the signpost's top-right, following the prop
		var ts := signpost_tag.get_combined_minimum_size()
		var top: Vector2 = world.screen_top(props[SIGNPOST]) # the post's real top (the projected box is loose)
		signpost_tag.position = Vector2(top.x + 8.0, top.y - ts.y * 0.5)

## Places buttons without overlaps (TdStationWorld.layout_buttons; kept here for the tests and tools).
static func layout_buttons(items: Array, width: float, gap: float, lift: float) -> Array:
	return TdStationWorld.layout_buttons(items, width, gap, lift)

func _process(_delta: float) -> void:
	_place_buttons()

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
	var eyebrow := TdMenu.label("CHAPTER 1 COMPLETE", "micro", TdTheme.color("cream.200"), 22)
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
		var prop_only: bool = b == null and props.get(TOUR[index][0]) != null # the Signpost: a prop, no button
		if not prop_only and (b == null or not b.visible):
			index += 1
			continue
		tour_step = index
		if b != null:
			_highlighted = b
			b.selected = true
		bubble.show_line(TOUR_SPEAKER, TOUR[index][1], true, GameApp.portrait_texture("Princess"))
		bubble.set_hint("Tour · %d/%d" % [index + 1, TOUR.size()], "Click or [b]%s[/b]" % KeyBinds.first(KeyBinds.Skip))
		# beside the station's prop (right of it, or left for props on the right half), under the station row: the
		# bubble's area is cut to that side, so it covers neither the prop it describes nor another station
		var pr := _prop_rect(props.get(TOUR[index][0]))
		var row_bottom := b.get_global_rect().end.y if b != null else pr.position.y
		var right_side := pr.get_center().x < size.x * 0.6
		var centre := absf(pr.get_center().x - size.x / 2.0) < size.x * 0.12
		var front: bool = _front.get(TOUR[index][0], false)
		var tip: Vector2
		if centre:
			# a station in the middle (props on both sides): the bubble opens under it, over the open ground
			bubble.offset_left = 0.0
			bubble.offset_right = 0.0
			bubble.offset_top = pr.end.y - 30.0
			tip = Vector2(pr.get_center().x, pr.end.y - 4.0)
		else:
			bubble.offset_top = (pr.position.y - 30.0) if front else (row_bottom - 30.0)
			bubble.offset_left = pr.end.x + 8.0 if right_side else 0.0
			bubble.offset_right = 0.0 if right_side else -(size.x - pr.position.x + 8.0)
			tip = Vector2(pr.end.x - 6.0 if right_side else pr.position.x + 6.0, maxf(row_bottom - 4.0, pr.position.y) if not front else pr.position.y + 6.0)
		bubble.point_at(tip)
		return
	end_tour()

func end_tour() -> void:
	tour_step = -1
	bubble.offset_left = 0.0
	bubble.offset_right = 0.0
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

## Codex station.
func open_codex() -> TdPopup:
	return open_popup("codex")

## Towers: the hand editor over every owned tower.
func open_towers() -> TdPopup:
	return open_popup("hand_editor")

## Workshop: the picker, then a tower's forms (Workshop — Design).
func open_workshop() -> TdPopup:
	return open_popup("workshop")

## Missions (the Signpost): the Guild.
func open_guild() -> void:
	end_tour()
	SaveData.save()
	SceneFlow.go(SceneFlow.Guild)

## The Signpost (the "Missions" prop in layout.json): a clickable prop leading to the Guild; locked before Chapter 2
## (dimmed, "Opens after Chapter 2", a click shakes it); a gold "New" floats by it until the first Guild visit.
func _build_signpost() -> void:
	var post: Node3D = props.get(SIGNPOST)
	if post == null: return
	var open := GameApp.guild_unlocked()
	signpost = world.hotspot(self, SIGNPOST, MissionUiLogic.SignpostTip if open else MissionUiLogic.signpost_locked_text(GameApp.catalog),
		func(): open_guild() if GameApp.guild_unlocked() else _shake_signpost(), open)
	move_child(signpost, world.get_index() + 1) # under the buttons
	if not open: world.dim(post, true)
	if open and MissionUiLogic.signpost_tag(SaveData.profile.guild_seen) != "":
		signpost_tag = TdMenu.pill("[b]%s[/b]" % MissionUiLogic.signpost_tag(false), Color(0.12, 0.09, 0.07, 0.9), TdTheme.color("gold"), 20, TdTheme.color("gold"))
		signpost_tag.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(signpost_tag)
		# in the station layer (with the buttons), under the popups, the tour bubble and the welcome card
		move_child(signpost_tag, popups.get_index())

## A refused click on the locked Signpost: a short shake.
func _shake_signpost() -> void:
	var post: Node3D = props.get(SIGNPOST)
	if post == null: return
	var x := post.position.x
	var tw := create_tween()
	for dx in [-0.12, 0.12, -0.07, 0.07, 0.0]: tw.tween_property(post, "position:x", x + dx, 0.05)

## Multiplayer: the co-op lobby (connects to the relay).
func open_multiplayer() -> TdPopup:
	end_tour()
	var p := CoopLobby.new()
	p.free_on_close = true
	popups.add_child(p)
	p.open()
	return p
