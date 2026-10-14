extends Control
## The Guild (Missions & Guild — Design § The Guild; mockups screens-b/guild.html, guild-welcome.html): a second
## place like the Camp, opened from the Camp's Signpost once Chapter 2 is cleared (SceneFlow.Guild). A 3D guild hall
## built from res://art/guild/layout.json exactly like the Camp (TdStationWorld: the Blender agent's Guild kit — floor,
## hall walls, the Mission Board in the centre, Coop Table, Tower Rack, Guild Door; Idle loops; camp.gd's camera and
## light, plus a warm hearth light), "Guild · Missions and co-op", and a station button over (or under) each prop:
## Missions (primary, under the Mission Board: the mission board, then a mission's detail), Multiplayer (the co-op
## lobby, moved here from the Camp) and Towers (the hand editor, the same hands and layouts as the Camp's), each on
## the floor in front of its prop; Camp has no station button: "← Camp" bottom-left (like the Camp's "← Main menu")
## and the Guild Door is a hotspot (hover highlight + "Back to the Camp", click goes back). The first visit shows the welcome card once (PlayerProfile.guild_seen). Back from a co-op
## match (Net.reopen_lobby) or the Camp's "Multiplayer → Guild" opens the lobby. Texts: MissionUiLogic.

const SCREENS := "res://game/ui/screens/"
## Where the props stand: the Blender agent's Guild layout (the Camp's schema; its centre is the Missions station).
const LAYOUT := "res://art/guild/layout.json"
const FALLBACK_LAYOUT := {
	"board": {"tiles": [14, 10]},
	"ring": {"centre": [6.5, 4.5], "radius": [5.4, 4.65], "slots": 5, "first_angle_deg": 90},
	"centre": {"prop": "Mission Board", "tile": [6.5, 4.5], "scale": 2.6, "yaw": 0, "station": "Missions", "row": "front"},
	"slots": [
		{"slot": 0, "tile": [6.5, 9.15], "face_yaw": 0.0, "row": "back", "station": "Camp", "prop": "Guild Door", "scale": 2.8},
		{"slot": 1, "tile": [1.36, 5.94], "face_yaw": 0.0, "row": "back", "station": "Multiplayer", "prop": "Coop Table", "scale": 3.0},
		{"slot": 4, "tile": [11.64, 5.94], "face_yaw": 0.0, "row": "back", "station": "Towers", "prop": "Tower Rack", "scale": 2.6},
	],
	"decor": [{"prop": "Guild Floor", "tile": [6.5, 4.5], "scale": 1.0, "yaw": 0}, {"prop": "Guild Hall", "tile": [6.5, 4.5], "scale": 1.0, "yaw": 0}],
}
## The hearth's warm light (Guild kit README: tile (3.1, 8.75), 0.5 high, range ~4, FFB24A).
const HEARTH := Vector3(3.1, 0.5, -8.75)
const ACTIONS := {"Missions": "open_missions", "Multiplayer": "open_multiplayer", "Towers": "open_towers", "Camp": "back_to_camp"}

var world: TdStationWorld
## The bottom-left "← Camp" button and the Guild Door's hotspot.
var camp_button: TdMenuButton
var door: Control
var stations := {}   # id → TdMenuButton
var welcome_card: Control
var popups: Control
var board: TdPopup = null
var _lobby_pending := false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	TdMenu.wood_background(self)
	world = TdStationWorld.new()
	add_child(world)
	world.build(TdStationWorld.load_layout(LAYOUT, FALLBACK_LAYOUT), func(p): return GameApp.prop_scene("guild", p), false)
	var hearth := OmniLight3D.new()
	hearth.light_color = Color("FFB24A")
	hearth.light_energy = 1.4
	hearth.omni_range = 4.0
	hearth.position = HEARTH
	world.add_light(hearth)
	_build_title()
	_build_stations()
	popups = Control.new()
	popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(popups)
	_build_welcome()
	if GameApp.catalog != null and GameApp.catalog.grant_starting_towers(SaveData.towers): SaveData.save()
	refresh()
	welcome_card.visible = not SaveData.profile.guild_seen
	# back from a co-op match, or the Camp's "Multiplayer → Guild": the lobby opens (after the welcome card)
	if has_node("/root/Net") and get_node("/root/Net").reopen_lobby:
		get_node("/root/Net").reopen_lobby = false
		_lobby_pending = true
	if welcome_card.visible:
		await get_tree().process_frame
		TdPanelTransition.open(welcome_card.get_meta("card"))
	elif _lobby_pending:
		_lobby_pending = false
		open_multiplayer.call_deferred()

func _build_title() -> void:
	# as the Camp's title
	var title := TdMenu.label(MissionUiLogic.GuildTitle, "display", TdTheme.color("cream.100"), 64)
	title.position = Vector2(58, 28)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	var sub := TdMenu.label(MissionUiLogic.GuildSub, "body", TdTheme.color("cream.200"), 24)
	sub.position = Vector2(62, 112)
	sub.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(sub)

## One Camp-style station button per station (icon, name, the line under it), placed by the world each frame.
func _build_stations() -> void:
	for st in MissionUiLogic.Stations:
		var b := TdMenuButton.new()
		b.style = TdButton.Style.MENU_PRIMARY if st.get("primary", false) else TdButton.Style.MENU_WOOD
		var sub: String = st.sub if st.sub != "" else MissionUiLogic.missions_station_sub(0)
		var w := maxf(236.0, 90.0 + TdTheme.font("nunito_bold").get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
		b.custom_minimum_size = Vector2(w, 72)
		b.size = b.custom_minimum_size
		b.text = st.label
		b.sub = st.sub
		b.icon = TdDrops.icon_texture(st.icon)
		b.selectable = true
		b.left_pad = 20
		b.font_size = 26
		add_child(b)
		stations[st.id] = b
		b.clicked.connect(Callable(self, ACTIONS[st.id]))
		if not world.props.has(st.id) or world.props[st.id] == null: b.visible = false
	# Camp: no station button over the door (UI/UX ruling): "← Camp" bottom-left like the Camp's "← Main menu", and
	# the Guild Door itself is a hotspot (hover: highlight + "Back to the Camp", click: back)
	stations["Camp"].visible = false
	var back := TdMenuButton.new()
	back.style = TdButton.Style.MENU_WOOD
	back.custom_minimum_size = Vector2(290, 64)
	back.size = back.custom_minimum_size
	back.text = "Camp"
	back.icon = TdTheme.texture("icon_back")
	back.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	back.offset_left = 60; back.offset_top = -110; back.offset_right = 350; back.offset_bottom = -46
	back.clicked.connect(back_to_camp)
	add_child(back)
	camp_button = back
	door = world.hotspot(self, "Camp", "Back to the Camp", back_to_camp)
	move_child(door, world.get_index() + 1) # under the buttons
	resized.connect(_place_buttons)
	_place_buttons.call_deferred()

func _place_buttons() -> void:
	world.place_buttons(self, stations, MissionUiLogic.Stations.map(func(st): return st.id))
	world.place_hotspots()

func _process(_delta: float) -> void:
	_place_buttons() # the 3D view's size settles late (as the Camp)

## Redraws the station lines (the Missions count).
func refresh() -> void:
	var n := MissionUiLogic.to_play_count(GameApp.missions(), SaveData.progress, SaveData.missions, GameApp.catalog)
	if stations.has("Missions"): stations["Missions"].sub = MissionUiLogic.missions_station_sub(n)

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
	var p := TdMenu.panel(TdPanel.Kind.MENU, 0)
	p.custom_minimum_size = Vector2(820, 0)
	center.add_child(p)
	welcome_card.set_meta("card", p)
	var m := MarginContainer.new()
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 38)
	for side in ["top", "bottom"]: m.add_theme_constant_override("margin_" + side, 30)
	p.add_child(m)
	var col := TdMenu.vbox(16)
	m.add_child(col)
	col.add_child(TdMenu.label(MissionUiLogic.WelcomeTitle, "plaque_title", TdTheme.color("cream.100"), 48))
	var lead := TdMenu.rich(MissionUiLogic.WelcomeLead, "body", TdTheme.color("cream.200"), 23)
	lead.custom_minimum_size = Vector2(740, 0)
	col.add_child(lead)
	for row in MissionUiLogic.WelcomeRows:
		var h := TdMenu.hbox(14)
		col.add_child(h)
		var ic: Control
		if row[0] == "token":
			ic = TdMenu.picture(TdDrops.token_texture("fire-arrow"), Vector2(32, 32))
			ic.size_flags_vertical = SIZE_SHRINK_CENTER
		else:
			ic = TdDrops.icon(row[0], 30, TdTheme.color("gold"))
		ic.custom_minimum_size = Vector2(32, 32)
		h.add_child(ic)
		var t := TdMenu.rich(row[1], "body", TdTheme.color("cream.200"), 21)
		t.custom_minimum_size = Vector2(680, 0)
		t.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(t)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(btn_row)
	var ok := TdMenu.button(TdButton.Style.PRIMARY, MissionUiLogic.WelcomeButton, Vector2(220, 62))
	ok.font_size = 28
	ok.clicked.connect(close_welcome)
	btn_row.add_child(ok)
	welcome_card.visible = false

## The welcome card is closed: never shown again.
func close_welcome() -> void:
	welcome_card.visible = false
	if not SaveData.profile.guild_seen:
		SaveData.profile.guild_seen = true
		SaveData.save()
	if _lobby_pending:
		_lobby_pending = false
		open_multiplayer()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if welcome_card.visible and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE):
		close_welcome()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ stations

## Missions: the mission board (a popup over the Guild); its detail and Find a room come from it.
func open_missions() -> TdPopup:
	var b: TdPopup = MissionBoardScreen.new()
	b.free_on_close = true
	popups.add_child(b)
	b.find_room.connect(open_multiplayer)
	b.closed.connect(func(): if is_instance_valid(self): refresh())
	b.open()
	board = b
	return b

## Multiplayer: the co-op lobby; with a mission, its Create room opens with that mission picked.
func open_multiplayer(mission_id := "") -> TdPopup:
	var p := CoopLobby.new()
	p.free_on_close = true
	p.preselect_mission = mission_id
	popups.add_child(p)
	p.closed.connect(func(): if is_instance_valid(self): refresh())
	p.open()
	return p

## Towers: the hand editor (tired towers dimmed).
func open_towers() -> TdPopup:
	var p: TdPopup = load(SCREENS + "hand_editor.tscn").instantiate()
	p.free_on_close = true
	popups.add_child(p)
	p.open()
	return p

## Camp: back to the Camp.
func back_to_camp() -> void:
	SaveData.save()
	SceneFlow.go(SceneFlow.Camp)
