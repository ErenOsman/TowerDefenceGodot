extends Control
## The Guild (Missions & Guild — Design § The Guild; mockups screens-b/guild.html, guild-welcome.html): a second
## place like the Camp, opened from the Camp's Signpost once Chapter 2 is cleared (SceneFlow.Guild). A warm-tinted
## blurred diorama (TdGuildBackdrop, a placeholder until there is Guild art), "Guild · Missions and co-op", and a
## ring of 4 stations round a "Notice board" centre: Missions (primary: the mission board, then a mission's detail),
## Multiplayer (the co-op lobby, moved here from the Camp), Towers (the hand editor, the same hands and layouts as
## the Camp's) and Camp (back). The first visit shows the welcome card once (PlayerProfile.guild_seen).
## Back from a co-op match (Net.reopen_lobby) reopens the lobby. Texts: MissionUiLogic.

const SCREENS := "res://game/ui/screens/"
## The ring (1920×1080 reference, centred): station centres (the medallion's centre).
const RING := {"Missions": Vector2(960, 285), "Multiplayer": Vector2(542, 525), "Towers": Vector2(1378, 525), "Camp": Vector2(960, 775)}
const CENTRE := Vector2(960, 545)
const MEDAL := 124.0
const FRAME := Vector2(1920, 1080)

var backdrop: TdGuildBackdrop
var stations := {}   # id → GuildStation
var welcome_card: Control
var popups: Control
var board: TdPopup = null
var _lobby_pending := false
var _frame: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	backdrop = TdGuildBackdrop.new()
	add_child(backdrop)
	_frame = Control.new()
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(PRESET_CENTER)
	_frame.offset_left = -FRAME.x / 2.0; _frame.offset_right = FRAME.x / 2.0
	_frame.offset_top = -FRAME.y / 2.0; _frame.offset_bottom = FRAME.y / 2.0
	add_child(_frame)
	_build_title()
	_build_ring()
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
	var row := TdMenu.hbox(18)
	row.position = Vector2(40, 22)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.add_child(row)
	var title := TdMenu.label(MissionUiLogic.GuildTitle, "display", TdTheme.color("cream.100"), 56)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	row.add_child(title)
	var sub := TdMenu.label(MissionUiLogic.GuildSub, "body", TdTheme.color("cream.200"), 22)
	sub.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(sub)

func _build_ring() -> void:
	# the centre: the Notice board (decoration: the Guild's emblem)
	var centre := Control.new()
	centre.mouse_filter = MOUSE_FILTER_IGNORE
	centre.position = CENTRE - Vector2(110, 40)
	centre.size = Vector2(220, 110)
	_frame.add_child(centre)
	var emblem := TdDrops.token_texture("arcane-shard")
	var em := TdMenu.picture(emblem, Vector2(80, 80))
	em.position = Vector2(70, 0)
	em.modulate = Color(1, 1, 1, 0.85)
	centre.add_child(em)
	var nl := TdMenu.label("Notice board", "body", Color(TdTheme.color("cream.200"), 0.7), 20)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.position = Vector2(0, 84)
	nl.size = Vector2(220, 26)
	centre.add_child(nl)
	for st in MissionUiLogic.Stations:
		var s := GuildStation.new()
		s.setup(st.label, st.sub, st.icon, bool(st.get("primary", false)))
		var c: Vector2 = RING[st.id]
		s.position = c - Vector2(GuildStation.W / 2.0, MEDAL / 2.0)
		_frame.add_child(s)
		stations[st.id] = s
		s.clicked.connect(Callable(self, {"Missions": "open_missions", "Multiplayer": "open_multiplayer", "Towers": "open_towers", "Camp": "back_to_camp"}[st.id]))

## Redraws the station lines (the Missions count).
func refresh() -> void:
	var n := MissionUiLogic.to_play_count(GameApp.missions(), SaveData.progress, SaveData.missions, GameApp.catalog)
	if stations.has("Missions"): stations["Missions"].set_sub(MissionUiLogic.missions_station_sub(n))

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

# ------------------------------------------------------------------ a station

## A Guild station (guild.html .gst): a round wood medallion with a cream icon (primary: a cobalt ring), its name
## and a line under it; hover lifts and lights the ring; a click opens it.
class GuildStation extends Control:
	signal clicked

	const W := 420.0

	var primary := false
	var _hover := false
	var _medal: Control
	var _icon: TextureRect
	var _name: Label
	var _sub: Label

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		size = Vector2(W, 220)
		custom_minimum_size = size
		mouse_entered.connect(func(): _hover = true; _restyle())
		mouse_exited.connect(func(): _hover = false; _restyle())

	func setup(label: String, sub: String, icon_name: String, is_primary: bool) -> void:
		primary = is_primary
		_medal = Control.new()
		_medal.mouse_filter = MOUSE_FILTER_IGNORE
		_medal.size = Vector2(124, 124)
		_medal.position = Vector2((W - 124) / 2.0, 0)
		_medal.draw.connect(_draw_medal)
		add_child(_medal)
		_icon = TdDrops.icon(icon_name, 56, TdTheme.color("cream.100"))
		_icon.position = Vector2(34, 34)
		_medal.add_child(_icon)
		_name = TdMenu.label(label, "display", TdTheme.color("cream.100"), 32)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
		_name.add_theme_constant_override("shadow_offset_y", 2)
		_name.position = Vector2(0, 134)
		_name.size = Vector2(W, 40)
		add_child(_name)
		_sub = TdMenu.label(sub, "body", TdTheme.color("cream.200"), 20)
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.position = Vector2(0, 176)
		_sub.size = Vector2(W, 28)
		add_child(_sub)
		tooltip_text = label

	func set_sub(text: String) -> void:
		if _sub != null: _sub.text = text

	func _restyle() -> void:
		var tw := TdTheme.tween(_medal)
		tw.tween_property(_medal, "position:y", -6.0 if _hover else 0.0, TdTheme.motion("quick"))
		_medal.queue_redraw()

	func _draw_medal() -> void:
		var c := Vector2(62, 62)
		_medal.draw_circle(c + Vector2(0, 6), 62, Color(0, 0, 0, 0.35))
		var ring := TdTheme.color("accent.light") if primary else (TdTheme.color("gold") if _hover else Color("#120C09"))
		_medal.draw_circle(c, 62, ring)
		_medal.draw_circle(c, 62 - (5.0 if primary or _hover else 3.0), Color("#120C09"))
		_medal.draw_circle(c, 56, Color("#4A372B") if _hover else Color("#3A2B22"))
		_medal.draw_arc(c, 50, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.06), 6.0, true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
				and Rect2(Vector2.ZERO, size).has_point(event.position):
			clicked.emit()
