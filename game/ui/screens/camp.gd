extends Control
## The Camp (UI_Camp.cs; Camp & Chapters — Design): the home between levels once Chapter 1 is won. A 3D camp
## laid out from res://art/camp/layout.json (map-kit ground with its frame, the station props on a ring round the
## Campfire, all facing the camera; Tent and Supplies) with a station button over each prop: Chapters (the chapter picker, then a chapter's
## levels), Towers (the hand editor over every owned tower), Codex, Blacksmith (station id "Workshop", the smithy signpost (ex anvil
## table's slot: "Modify and upgrade towers"; slides to the Blacksmith place, SceneFlow.Blacksmith, which holds the
## Workshop; Blacksmith — Design), Guild (by the Signpost, "Missions and co-op": the Camp slides out to the left as the Guild comes in, SceneFlow.slide;
## a gold "New" on the button until the first Guild visit) and Main menu; no Multiplayer here (it lives in the Guild
## only). Eren 2026-10-15: the Blacksmith and Guild buttons are not shown at all before Chapter 2's last level is won
## (no locked state; the props stay). The first visit (PlayerProfile.camp_seen) shows a welcome card, then a tour:
## the Princess's speech bubble (TdTextBubble) points at each shown station in turn, the station highlighted; a click
## goes on, Skip ends it. After Chapter 2 the next visit points once at the Guild and the Blacksmith
## (PlayerProfile.guild_tour_seen, TOUR_OPEN). Map music comes from SceneFlow (AudioMgr.play_scene_music).

const SCREENS := "res://game/ui/screens/"
## Where the props stand: the Blender agent's camp layout (source of truth). Board 18×9 tiles, x left→right,
## depth front→back; Godot position = Vector3(x, 0, -depth); yaw = rotation_degrees.y.
const LAYOUT := "res://art/camp/layout.json"
## The stations, data-driven: adding one = an entry here + a slot with its name in layout.json.
## {id, label, icon, action (method name, "" for none), locked, sub (a second line), gate ("chapter2": not shown
## until Chapter 2's last level is won)}
const STATIONS := [
	{"id": "Towers", "label": "Towers", "icon": "icon_cards", "action": "open_towers", "locked": false},
	{"id": "Chapters", "label": "Chapters", "icon": "icon_castle", "action": "open_chapters", "locked": false, "primary": true},
	{"id": "Codex", "label": "Codex", "icon": "icon_codex", "action": "open_codex", "locked": false},
	# the Blacksmith (Blacksmith — Design): keeps the Workshop's station id and slot (layout.json, tests, tools)
	{"id": "Workshop", "label": "Blacksmith", "icon": "icon_edit", "action": "open_blacksmith", "locked": false, "gate": "blacksmith"},
	{"id": "Guild", "label": "Guild", "icon": "extra:flag", "action": "open_guild", "locked": false, "gate": "chapter2"},
]
## Used when layout.json cannot be read (same values as layout.json, the ring layout of 2026-10-13).
const FALLBACK_LAYOUT := {
	"board": {"tiles": [14, 10], "ground": "map kit (BoardView ground pieces + frame)"},
	"ring": {"centre": [6.5, 4.6], "radius": [5.2, 3.3], "slots": 7, "first_angle_deg": 90},
	"centre": {"prop": "Campfire", "tile": [6.5, 4.6], "scale": 3.0, "yaw": 0},
	"slots": [
		{"slot": 0, "tile": [6.5, 7.9], "face_yaw": 0.0, "row": "back", "station": "Chapters", "prop": "War Table", "scale": 3.2},
		{"slot": 1, "tile": [2.43, 6.66], "face_yaw": 0.0, "row": "back", "station": "Towers", "prop": "Miniature Shelf", "scale": 3.4},
		{"slot": 2, "tile": [1.43, 3.87], "face_yaw": 0.0, "row": "front", "station": "Workshop", "prop": "Signpost Smithy", "scale": 2.6},
		{"slot": 3, "tile": [4.24, 1.63], "face_yaw": 0.0, "row": "front", "station": null, "prop": null},
		{"slot": 4, "tile": [8.76, 1.63], "face_yaw": 0.0, "row": "front", "station": null, "prop": null},
		{"slot": 5, "tile": [11.57, 3.87], "face_yaw": 0.0, "row": "front", "station": "Guild", "prop": "Signpost", "scale": 2.6},
		{"slot": 6, "tile": [10.57, 6.66], "face_yaw": 0.0, "row": "back", "station": "Codex", "prop": "Codex Lectern", "scale": 3.2},
	],
	"decor": [{"prop": "Tent", "tile": [4.3, 1.8], "scale": 2.1, "yaw": 0}, {"prop": "Supplies", "tile": [12.2, 8.9], "scale": 2.6, "yaw": -15}],
}
const BOARD := Vector2(14, 10)
const TOUR := [
	["Chapters", "Chapters: pick a chapter, then a level. Side chapters appear here as you open them."],
	["Towers", "Towers: every tower you own. Choose which ones you bring in your hand."],
	["Codex", "Codex: every tower, enemy and status you have met, and tips."],
	["Workshop", "Blacksmith: modify your towers into new forms with tokens from missions, and upgrade them."],
	["Guild", "The Signpost: the way to the Guild. Missions there earn tokens, and co-op lives there too."],
]
## The mini tour once Chapter 2 is won (profile.guild_tour_seen): the two buttons that just appeared (Guild, Blacksmith).
const TOUR_OPEN := [
	["Guild", "The Signpost: the Guild is open. Missions there earn tokens, and co-op lives there too."],
	["Workshop", "The Blacksmith is open too: spend those tokens to modify your towers, and upgrade them."],
]
const TOUR_SPEAKER := "Princess"

var buttons := {}       # station id → TdMenuButton
var props := {}         # station id → Node3D
var _front := {}        # station id → true when its slot is on the front of the ring (button below the prop)
var _board := BOARD
var tour_step := -1
## The tour running (TOUR or TOUR_OPEN).
var tour: Array = TOUR
var bubble: TdTextBubble
var welcome_card: Control
var popups: Control
## The Backpack button (top-right; Backpack — Design).
var backpack_button: TdBackpackButton

var world: TdStationWorld
## The Guild button's gold "New" (until the first Guild visit), or null.
var guild_tag: Control
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
	# back from the Guild (SceneFlow.slide): cards and tours wait until the Camp is in place
	if SceneFlow.is_sliding:
		await SceneFlow.slide_finished
		if not is_inside_tree(): return
	welcome_card.visible = not SaveData.profile.camp_seen
	if welcome_card.visible:
		await get_tree().process_frame
		TdPanelTransition.open(welcome_card.get_child(0))
	elif open_tour_due():
		await get_tree().process_frame # the buttons placed first
		await get_tree().process_frame
		start_open_tour()
	# (back from a co-op match the game returns to the Guild, which reopens the lobby; nothing to do here)

## Whether a station is shown: "chapter2" (Guild) only once Chapter 2's last level is won; "blacksmith" once the
## Blacksmith is open (the same level unless the catalog says otherwise).
static func station_shown(st: Dictionary) -> bool:
	match st.get("gate", ""):
		"chapter2": return chapter2_won()
		"blacksmith": return blacksmith_open()
	return true

## The Blacksmith is open (GameApp.blacksmith_unlocked() once it exists, else Chapter 2 won).
static func blacksmith_open() -> bool:
	if GameApp.has_method("blacksmith_unlocked"): return bool(GameApp.call("blacksmith_unlocked"))
	return chapter2_won()

static func chapter2_won() -> bool:
	return MenuLogic.workshop_unlocked(GameApp.catalog, SaveData.progress) or GameApp.guild_unlocked()

## The post-Chapter-2 mini tour is due: Chapter 2 won, the first tour done, not shown yet, the Guild not visited.
func open_tour_due() -> bool:
	return chapter2_won() and SaveData.profile.camp_seen and not SaveData.profile.guild_tour_seen and not SaveData.profile.guild_seen

## Points once at the Guild and the Workshop (TOUR_OPEN); never again (profile.guild_tour_seen).
func start_open_tour() -> void:
	SaveData.profile.guild_tour_seen = true
	SaveData.save()
	tour = TOUR_OPEN
	show_tour_step(0)

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
	# no subtitle and no lines under the station buttons: nothing is explained on an everyday screen (Eren 2026-10-17)
	for st in STATIONS:
		var b := TdMenuButton.new()
		b.style = TdButton.Style.MENU_PRIMARY if st.get("primary", false) else TdButton.Style.MENU_WOOD
		var sub: String = st.get("sub", "")
		var w := 236.0
		if sub != "": w = maxf(w, 90.0 + TdTheme.font("nunito_bold").get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
		b.custom_minimum_size = Vector2(w, 72 if st.locked or sub != "" else 60)
		b.size = b.custom_minimum_size
		b.text = st.label
		b.sub = sub
		b.icon = TdDrops.icon_texture(st.icon.trim_prefix("extra:")) if st.icon.begins_with("extra:") else TdTheme.texture(st.icon)
		b.selectable = true
		b.left_pad = 20
		b.font_size = 26
		add_child(b)
		buttons[st.id] = b
		b.visible = station_shown(st) # Blacksmith and Guild: not shown at all before Chapter 2 (Eren 2026-10-15)
		var locked_line := "Coming later" if st.locked else ""
		var action: String = st.action
		if locked_line != "":
			# locked (UI review 2026-10-14): a lock icon, "Opens after Chapter 2", the Disabled look
			b.custom_minimum_size = Vector2(maxf(236.0, 90.0 + TdTheme.font("nunito_bold").get_string_size(locked_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x), 72)
			b.size = b.custom_minimum_size
			b.icon = TdTheme.texture("icon_lock")
			b.sub = locked_line
			b.set_interactable(false, locked_line)
		elif action != "":
			b.clicked.connect(Callable(self, action))
		if not props.has(st.id) or props[st.id] == null: b.visible = false # no slot for it in the layout yet
		if not b.visible and b.has_meta("leader"): b.get_meta("leader").visible = false
	# the Guild button's "New" until the first Guild visit (a small gold tag on its top-right corner)
	var gb: TdMenuButton = buttons.get("Guild")
	if gb != null and gb.visible and MissionUiLogic.signpost_tag(SaveData.profile.guild_seen) != "":
		guild_tag = TdMenu.pill("[b]%s[/b]" % MissionUiLogic.signpost_tag(false), Color(0.12, 0.09, 0.07, 0.92), TdTheme.color("gold"), 18, TdTheme.color("gold"))
		guild_tag.mouse_filter = MOUSE_FILTER_IGNORE
		gb.add_child(guild_tag)
		guild_tag.position = Vector2(gb.size.x - 34.0, -14.0)
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
	# the Backpack button (Backpack — Design): top-right, under the popups
	backpack_button = TdBackpackButton.place_top_right(self, popups)
	move_child(backpack_button, popups.get_index())
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
	resized.connect(_place_buttons)
	_place_buttons.call_deferred()

## Each station's button sits above its prop with a leader line down to it (re-placed every frame: the 3D view's
## size settles late); TdStationWorld.place_buttons keeps them apart.
func _place_buttons() -> void:
	if world == null: return
	world.place_buttons(self, buttons, STATIONS.map(func(st): return st.id))

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
		# a first visit after Chapter 2 already shows the Guild and Blacksmith: no mini tour later
		if chapter2_won(): SaveData.profile.guild_tour_seen = true
		SaveData.save()
	tour = TOUR
	show_tour_step(0)

## Shows a tour step (stations missing are skipped): the bubble at the station, the station highlighted.
func show_tour_step(index: int) -> void:
	if _highlighted != null: _highlighted.selected = false
	_highlighted = null
	# the steps shown (stations hidden or missing are skipped and not counted)
	var shown := []
	for i in tour.size():
		var sb: TdButton = buttons.get(tour[i][0])
		if sb != null and sb.visible: shown.append(i)
	while index < tour.size():
		var b: TdButton = buttons.get(tour[index][0])
		if b == null or not b.visible:
			index += 1
			continue
		tour_step = index
		_highlighted = b
		b.selected = true
		bubble.show_line(TOUR_SPEAKER, tour[index][1], true, GameApp.portrait_texture("Princess"))
		bubble.set_hint("Tour · %d/%d" % [shown.find(index) + 1, shown.size()], "Click or [b]%s[/b]" % KeyBinds.first(KeyBinds.Skip))
		# beside the station's prop (right of it, or left for props on the right half), under the station row: the
		# bubble's area is cut to that side, so it covers neither the prop it describes nor another station
		var pr := _prop_rect(props.get(tour[index][0]))
		var row_bottom := b.get_global_rect().end.y
		var right_side := pr.get_center().x < size.x * 0.6
		var centre := absf(pr.get_center().x - size.x / 2.0) < size.x * 0.12
		var front: bool = _front.get(tour[index][0], false)
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

## The Workshop picker straight from the Camp (dev tools and shots; players reach it through the Blacksmith's Modify).
func open_workshop() -> TdPopup:
	return open_popup("workshop")

## Blacksmith (the smithy signpost's station): the Camp slides out to the right as the Blacksmith comes in from the left.
func open_blacksmith() -> void:
	end_tour()
	SaveData.save()
	SceneFlow.slide(SceneFlow.Blacksmith, -1) # the Blacksmith lies to the LEFT of the Camp (Eren 2026-10-16); the Guild to the right

## Guild (the button by the Signpost): the Camp slides out to the left as the Guild comes in from the right.
func open_guild() -> void:
	end_tour()
	SaveData.save()
	SceneFlow.slide(SceneFlow.Guild, 1)

## Multiplayer lives in the Guild (Eren 2026-10-15); this opens the lobby from the Camp for dev tools only.
func open_multiplayer() -> TdPopup:
	end_tour()
	var p := CoopLobby.new()
	p.free_on_close = true
	popups.add_child(p)
	p.open()
	return p
