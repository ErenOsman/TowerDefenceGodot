extends Control
## The Blacksmith (Blacksmith — Design): a place like the Guild, opened from the Camp's Blacksmith station once
## Chapter 2 is cleared (SceneFlow.Blacksmith; the Camp slides out to the left as the Blacksmith comes in,
## SceneFlow.slide; "← Camp" and the door slide back the other way). A 3D diorama built from
## res://art/blacksmith/layout.json (TdStationWorld, the Guild's schema; props looked up in the layout's "kits"
## folders, so the Blender agent's smithy kit replaces the placeholder by a JSON change), "Blacksmith · Modify and
## upgrade towers", and a station button by each prop: Modify (primary: the Workshop picker → Modify view, exactly as
## the Camp's Workshop station opened it), Upgrade (the Upgrade screens: open_upgrade(); until UPGRADE_READY it is a
## disabled button with "Coming soon"), Towers (the hand editor). Camp has no station button (as the Guild): "← Camp"
## bottom-left and the door is a hotspot. The first visit shows the welcome card once (profile.blacksmith_seen),
## after the slide, then a short tour (the Princess's bubble at each station, as the Camp's). Esc: closes the top
## popup (TdPopup), the welcome card or the tour; on the bare Blacksmith it goes back to the Camp.
## PLACEHOLDER art (2026-10-16): the Camp's anvil table, the Camp's crates, the Guild's tower rack and door on the
## Guild's floor, with a warm ember light.

const SCREENS := "res://game/ui/screens/"
## Where the props stand (the Guild's schema; the F1 layout editor writes it back).
const LAYOUT := "res://art/blacksmith/layout.json"
const FALLBACK_LAYOUT := {
	"board": {"tiles": [14, 10]},
	"kits": ["blacksmith", "camp", "guild"],
	"ring": {"centre": [6.5, 4.5], "radius": [5.0, 4.5]},
	"centre": {"prop": null, "tile": [6.5, 4.5], "station": null},
	"slots": [
		{"slot": 0, "tile": [6.5, 7.9], "face_yaw": 0.0, "row": "front", "station": "Modify", "prop": "Tower Workshop", "scale": 3.2},
		{"slot": 1, "tile": [1.9, 5.4], "face_yaw": 0.0, "row": "back", "station": "Upgrade", "prop": "Supplies", "scale": 2.6},
		{"slot": 4, "tile": [11.3, 5.6], "face_yaw": 0.0, "row": "back", "station": "Towers", "prop": "Tower Rack", "scale": 2.6},
		{"slot": 5, "tile": [6.5, 0.3], "face_yaw": 0.0, "row": "front", "station": "Camp", "prop": "Guild Door", "scale": 2.8},
	],
	"decor": [{"prop": "Guild Floor", "tile": [6.5, 4.5], "scale": 1.0, "yaw": 0}],
}
## Prop folders when the layout names none.
const DEFAULT_KITS := ["blacksmith", "camp", "guild"]
## The forge's warm light (placeholder: by the anvil table).
const EMBERS := Vector3(6.5, 1.4, -8.2) # the smithy kit's coal bed (Blender agent, 2026-10-16)

const Title := "Blacksmith"
const Sub := "Modify and upgrade towers"
## The stations, in placement order: {id, label, sub, icon, action, primary}.
const STATIONS := [
	{"id": "Modify", "label": "Modify", "sub": "Tower forms", "icon": "icon_edit", "action": "open_modify", "primary": true},
	{"id": "Upgrade", "label": "Upgrade", "sub": "Tower levels", "icon": "icon_plus", "action": "open_upgrade"},
	{"id": "Towers", "label": "Towers", "sub": "Your hand and layouts", "icon": "icon_cards", "action": "open_towers"},
	{"id": "Camp", "label": "Camp", "sub": "Back to the Camp", "icon": "icon_back", "action": "back_to_camp"},
]
## The Upgrade station is live (the Upgrade screens' agent sets this true when open_upgrade() opens them); false:
## a disabled button with UPGRADE_SOON as its line and reason.
const UPGRADE_READY := true
const UPGRADE_SOON := "Coming soon"

const WelcomeTitle := "The Blacksmith"
const WelcomeLead := "You cleared Chapter 2. The Blacksmith works on your [b]towers[/b]."
## [icon, bbcode] rows of the welcome card.
const WelcomeRows := [
	["edit", "[b]Modify[/b] turns a tower into one of its [b]forms[/b], with tokens from Guild missions."],
	["plus", "[b]Upgrade[/b] raises a tower's level. Coming soon."],
	["cards", "[b]Towers[/b]: your hand and layouts, the same as in the Camp."],
]
const WelcomeButton := "Got it"
## The first visit's tour, after the welcome card: [station id, line].
const TOUR := [
	["Modify", "Modify: turn a tower into one of its forms with tokens from Guild missions."],
	["Upgrade", "Upgrade: raise your towers' levels. Coming soon."],
	["Towers", "Towers: your hand and layouts, the same as in the Camp."],
]
const TOUR_SPEAKER := "Princess"

## Session-only stand-in for PlayerProfile.blacksmith_seen while the profile has no such field.
static var _seen_local := false

var world: TdStationWorld
## The bottom-left "← Camp" button and the door's hotspot.
var camp_button: TdMenuButton
var door: Control
var stations := {}   # id → TdMenuButton
var welcome_card: Control
var popups: Control
var bubble: TdTextBubble
var tour_step := -1
var _highlighted: TdButton

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	TdMenu.wood_background(self)
	world = TdStationWorld.new()
	add_child(world)
	var layout := TdStationWorld.load_layout(LAYOUT, FALLBACK_LAYOUT)
	var kits: Array = layout.get("kits", DEFAULT_KITS)
	world.build(layout, func(p): return prop_scene(kits, p), false)
	var embers := OmniLight3D.new()
	embers.light_color = Color("FF9A3C")
	embers.light_energy = 0.9
	embers.omni_range = 4.5
	embers.position = EMBERS
	world.add_light(embers)
	_build_title()
	_build_stations()
	popups = Control.new()
	popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(popups)
	_build_bubble()
	_build_welcome()
	if GameApp.catalog != null and GameApp.catalog.grant_starting_towers(SaveData.towers): SaveData.save()
	# opened by the Camp's slide (SceneFlow.slide): the welcome card waits until the Blacksmith is in place
	if SceneFlow.is_sliding:
		await SceneFlow.slide_finished
		if not is_inside_tree(): return
	welcome_card.visible = not seen()
	if welcome_card.visible:
		await get_tree().process_frame
		TdPanelTransition.open(welcome_card.get_meta("card"))

## A prop's scene: res://art/<kit>/<prop>.fbx for the first kit that has it, else the map-kit tile; null if none.
static func prop_scene(kits: Array, prop: String) -> PackedScene:
	for k in kits:
		if ResourceLoader.exists("res://art/%s/%s.fbx" % [k, prop]): return GameApp.prop_scene(str(k), prop)
	return GameApp.prop_scene(str(kits[0]) if not kits.is_empty() else "blacksmith", prop)

## Whether the Blacksmith is open: GameApp.blacksmith_unlocked() once it exists, else the Guild's rule (both
## Chapter 2's last level, Blacksmith — Design § Unlock).
static func unlocked() -> bool:
	if GameApp.has_method("blacksmith_unlocked"): return bool(GameApp.call("blacksmith_unlocked"))
	return GameApp.guild_unlocked()

## The welcome card was seen (PlayerProfile.blacksmith_seen, or the session flag while the profile lacks it).
static func seen() -> bool:
	var p = SaveData.profile
	if p != null and "blacksmith_seen" in p: return bool(p.get("blacksmith_seen"))
	return _seen_local

static func _mark_seen() -> void:
	var p = SaveData.profile
	if p != null and "blacksmith_seen" in p:
		if not bool(p.get("blacksmith_seen")):
			p.set("blacksmith_seen", true)
			SaveData.save()
	else:
		_seen_local = true

func _build_title() -> void:
	var title := TdMenu.label(Title, "display", TdTheme.color("cream.100"), 64)
	title.position = Vector2(58, 28)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	var sub := TdMenu.label(Sub, "body", TdTheme.color("cream.200"), 24)
	sub.position = Vector2(62, 112)
	sub.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(sub)

## One Camp-style station button per station (icon, name, the line under it), placed by the world each frame.
func _build_stations() -> void:
	for st in STATIONS:
		var b := TdMenuButton.new()
		b.style = TdButton.Style.MENU_PRIMARY if st.get("primary", false) else TdButton.Style.MENU_WOOD
		var sub: String = st.sub
		var live: bool = st.id != "Upgrade" or UPGRADE_READY
		if not live: sub = UPGRADE_SOON
		var w := maxf(236.0, 90.0 + TdTheme.font("nunito_bold").get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
		b.custom_minimum_size = Vector2(w, 72)
		b.size = b.custom_minimum_size
		b.text = st.label
		b.sub = sub
		b.icon = TdTheme.texture(st.icon)
		b.selectable = true
		b.left_pad = 20
		b.font_size = 26
		add_child(b)
		stations[st.id] = b
		if live: b.clicked.connect(Callable(self, st.action))
		else: b.set_interactable(false, UPGRADE_SOON)
		if not world.props.has(st.id) or world.props[st.id] == null: b.visible = false
	# Camp: no station button over the door (as the Guild): "← Camp" bottom-left, and the door is a hotspot
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
	world.place_buttons(self, stations, STATIONS.map(func(st): return st.id))
	world.place_hotspots()

func _process(_delta: float) -> void:
	_place_buttons() # the 3D view's size settles late (as the Camp)

# ------------------------------------------------------------------ welcome card and tour

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
	col.add_child(TdMenu.label(WelcomeTitle, "plaque_title", TdTheme.color("cream.100"), 48))
	var lead := TdMenu.rich(WelcomeLead, "body", TdTheme.color("cream.200"), 23)
	lead.custom_minimum_size = Vector2(740, 0)
	col.add_child(lead)
	for row in WelcomeRows:
		var h := TdMenu.hbox(14)
		col.add_child(h)
		var ic := TdDrops.icon(row[0], 30, TdTheme.color("gold"))
		ic.custom_minimum_size = Vector2(32, 32)
		h.add_child(ic)
		var t := TdMenu.rich(row[1], "body", TdTheme.color("cream.200"), 21)
		t.custom_minimum_size = Vector2(680, 0)
		t.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(t)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(btn_row)
	var ok := TdMenu.button(TdButton.Style.PRIMARY, WelcomeButton, Vector2(220, 62))
	ok.font_size = 28
	ok.clicked.connect(close_welcome)
	btn_row.add_child(ok)
	welcome_card.visible = false

## The welcome card is closed: never shown again; the tour starts.
func close_welcome() -> void:
	welcome_card.visible = false
	_mark_seen()
	show_tour_step(0)

func _build_bubble() -> void:
	bubble = TdTextBubble.new()
	bubble.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bubble)
	bubble.letters_per_second = 60.0
	bubble.hide_bubble()
	var plate := StyleBoxFlat.new() # the speaker's plate in teal, as the Camp's tour
	plate.bg_color = TdTheme.color("teal")
	plate.set_corner_radius_all(10)
	bubble._plate.add_theme_stylebox_override("panel", plate)
	bubble._name.add_theme_color_override("font_color", TdTheme.color("ink"))
	bubble.clicked.connect(func(): show_tour_step(tour_step + 1))
	bubble.skip_clicked.connect(end_tour)

## Shows a tour step (hidden stations skipped): the bubble beside the station's prop, the station highlighted
## (the Camp's placement: right of the prop, or left for props on the right; under it for a prop in the middle).
func show_tour_step(index: int) -> void:
	if _highlighted != null: _highlighted.selected = false
	_highlighted = null
	var shown := []
	for i in TOUR.size():
		var sb: TdButton = stations.get(TOUR[i][0])
		if sb != null and sb.visible: shown.append(i)
	while index < TOUR.size():
		var b: TdButton = stations.get(TOUR[index][0])
		if b == null or not b.visible:
			index += 1
			continue
		tour_step = index
		_highlighted = b
		b.selected = true
		bubble.show_line(TOUR_SPEAKER, TOUR[index][1], true, GameApp.portrait_texture("Princess"))
		bubble.set_hint("Tour · %d/%d" % [shown.find(index) + 1, shown.size()], "Click or [b]%s[/b]" % KeyBinds.first(KeyBinds.Skip))
		var pr := world.prop_rect(world.props.get(TOUR[index][0]))
		var br := b.get_global_rect().merge(pr)
		var right_side := pr.get_center().x < size.x * 0.6
		var centre := absf(pr.get_center().x - size.x / 2.0) < size.x * 0.12
		var tip: Vector2
		if centre:
			# a station in the middle: the bubble opens under it (prop and button), over the open floor
			bubble.offset_left = 0.0
			bubble.offset_right = 0.0
			bubble.offset_top = br.end.y - 30.0
			tip = Vector2(pr.get_center().x, br.end.y - 4.0)
		else:
			bubble.offset_top = br.position.y - 30.0
			bubble.offset_left = br.end.x + 8.0 if right_side else 0.0
			bubble.offset_right = 0.0 if right_side else -(size.x - br.position.x + 8.0)
			tip = Vector2(br.end.x - 6.0 if right_side else br.position.x + 6.0, pr.get_center().y)
		bubble.point_at(tip)
		return
	end_tour()

func end_tour() -> void:
	tour_step = -1
	bubble.offset_left = 0.0
	bubble.offset_right = 0.0
	bubble.offset_top = 0.0
	if _highlighted != null: _highlighted.selected = false
	_highlighted = null
	bubble.hide_bubble()

## Esc: the welcome card closes (Enter / Space too), then the tour ends (Skip key: next line), then the bare
## Blacksmith goes back to the Camp. Popups take their own Esc first (TdPopup: the top one closes).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if SceneFlow.is_loading: return
	if welcome_card.visible:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			close_welcome()
			get_viewport().set_input_as_handled()
		return
	if not TdPopup.open_popups.is_empty(): return
	if tour_step >= 0:
		if event.keycode == KEY_ESCAPE:
			end_tour()
			get_viewport().set_input_as_handled()
		elif KeyBinds.combo_from_event(event) != null and KeyBinds.combo_from_event(event).equals(KeyBinds.get_bind(KeyBinds.Skip, 0)):
			if bubble.is_fully_shown(): show_tour_step(tour_step + 1)
			else: bubble.reveal_all()
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_to_camp()

# ------------------------------------------------------------------ stations (public API)

## Opens a popup by its scene name (game/ui/screens/<scene>.tscn) over the Blacksmith; returns it.
func open_popup(scene: String) -> TdPopup:
	end_tour()
	var p: TdPopup = load(SCREENS + scene + ".tscn").instantiate()
	p.free_on_close = true
	popups.add_child(p)
	p.open()
	return p

## Modify: the Workshop picker, then a tower's forms (Workshop — Design), exactly as the Camp's Workshop opened it.
func open_modify() -> TdPopup:
	return open_popup("workshop")

## Same as open_modify() (the old Camp name, for dev tools).
func open_workshop() -> TdPopup:
	return open_modify()

## Upgrade: the Upgrade picker → Upgrade view (Upgrades — Design). STUB until the Upgrade screens land: it ends the
## tour and returns null. The station button calls this only when UPGRADE_READY is true. Fill it like open_modify():
## open the picker popup in `popups` and return it.
func open_upgrade() -> TdPopup:
	end_tour()
	return open_popup("upgrade")

## Towers: the hand editor (tired towers dimmed), the same hands and layouts as the Camp's.
func open_towers() -> TdPopup:
	return open_popup("hand_editor")

## Camp: back to the Camp, sliding the other way (the Blacksmith out to the right, the Camp in from the left).
func back_to_camp() -> void:
	if SceneFlow.is_loading: return
	end_tour()
	SaveData.save()
	SceneFlow.slide(SceneFlow.Camp, 1)
