extends Control
## The Camp (UI_Camp.cs; Camp & Chapters — Design): the home between levels once Chapter 1 is won. A 3D camp
## laid out from res://art/camp/layout.json (map-kit ground with its frame, the station props on a ring round the
## Campfire, all facing the camera; Tent and Supplies) with a station button over each prop: Chapters (the chapter picker, then a chapter's
## levels), Towers (the hand editor over every owned tower), Codex, Workshop (towers into their forms: workshop.gd; locked
## until Chapter 2 is cleared, MenuLogic.workshop_unlocked), and
## Main menu; Multiplayer (the co-op lobby). The first visit (PlayerProfile.camp_seen) shows a welcome card, then a tour: the
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
	{"id": "Multiplayer", "label": "Multiplayer", "icon": "icon_onboard", "action": "open_multiplayer", "locked": false},
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
		{"slot": 4, "tile": [8.76, 1.63], "face_yaw": 0.0, "row": "front", "station": null, "prop": null},
		{"slot": 5, "tile": [11.57, 3.87], "face_yaw": 0.0, "row": "front", "station": "Multiplayer", "prop": "Signal Post", "scale": 2.4},
		{"slot": 6, "tile": [10.57, 6.66], "face_yaw": 0.0, "row": "back", "station": "Codex", "prop": "Codex Lectern", "scale": 3.2},
	],
	"decor": [{"prop": "Tent", "tile": [0.9, 8.9], "scale": 2.6, "yaw": 15}, {"prop": "Supplies", "tile": [12.2, 8.9], "scale": 2.6, "yaw": -15}],
}
const BOARD := Vector2(14, 10)
## Station buttons: the gap kept between them, and how far above its prop's top a button sits.
const BUTTON_GAP := 16.0
const BUTTON_LIFT := 28.0
const TOUR := [
	["Chapters", "Chapters: pick a chapter, then a level. Side chapters appear here as you open them."],
	["Towers", "Towers: every tower you own. Choose which ones you bring in your hand."],
	["Codex", "Codex: every tower, enemy and status you have met, and tips."],
	["Workshop", "Workshop: changing your towers comes later."],
	["Multiplayer", "Multiplayer: play a level together with friends online, each with your own towers."],
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
	var layout := load_layout()
	# the ground: the map kit's ground pieces with its frame (BoardView over an empty map of the layout's size)
	var bt = layout.get("board", {}).get("tiles", [BOARD.x, BOARD.y])
	_board = Vector2(float(bt[0]), float(bt[1]))
	var level := LevelAsset.new()
	var rows: Array[String] = []
	for y in int(_board.y): rows.append(".".repeat(int(_board.x)))
	level.terrain = rows
	var board := BoardView.new()
	root.add_child(board)
	var kit: Array = GameApp.lib.rules.tiles if GameApp.lib.rules != null else []
	board.build(BattleGrid.new(int(_board.x), int(_board.y)), level, kit, func(p): return GameApp.model_scene(p))
	for slot in layout.get("slots", []):
		if slot.get("prop") == null or slot.get("station") == null: continue
		_front[str(slot.station)] = str(slot.get("row", "back")) == "front"
		props[str(slot.station)] = _prop(root, str(slot.prop), _tile(slot.tile), float(slot.get("scale", 1.0)), float(slot.get("face_yaw", 0.0)))
	var centre: Dictionary = layout.get("centre", {})
	if not centre.is_empty(): _prop(root, str(centre.prop), _tile(centre.tile), float(centre.get("scale", 1.0)), float(centre.get("yaw", 0.0)))
	for d in layout.get("decor", []): _prop(root, str(d.prop), _tile(d.tile), float(d.get("scale", 1.0)), float(d.get("yaw", 0.0)))
	_cam = Camera3D.new()
	_cam.fov = 34.0
	root.add_child(_cam)
	_cam.current = true
	# framed on the ring round the fire (not the whole board)
	var ring: Dictionary = layout.get("ring", {})
	var fire := _tile(ring.get("centre", centre.get("tile", [_board.x / 2.0 - 0.5, _board.y / 2.0 - 0.5])))
	var c := Vector3(fire.x, 0.0, -fire.y - 0.6)
	_cam.position = c + Vector3(0, 14.5, 17.0)
	_cam.look_at(c, Vector3.UP)

## The camp layout (layout.json), or the built-in copy when it cannot be read.
static func load_layout() -> Dictionary:
	if FileAccess.file_exists(LAYOUT):
		var d = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
		if d is Dictionary and d.has("slots"): return d
	return FALLBACK_LAYOUT

static func _tile(t) -> Vector2:
	return Vector2(float(t[0]), float(t[1])) if t is Array and t.size() >= 2 else Vector2.ZERO

func _prop(root: Node3D, prop: String, at: Vector2, scale_by: float, yaw: float) -> Node3D:
	var sc: PackedScene = GameApp.camp_scene(prop)
	if sc == null: return null
	var m: Node3D = sc.instantiate()
	m.position = Vector3(at.x, 0.0, -at.y)
	m.scale = Vector3.ONE * scale_by
	m.rotation_degrees.y = yaw
	root.add_child(m)
	TdDiorama._idle(m)
	var top := 0.5
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y)
	m.set_meta("top", top)
	return m

## A prop's screen rectangle in canvas coordinates (its meshes' boxes projected).
func _prop_rect(n: Node3D) -> Rect2:
	if n == null or _cam == null or _vp.size.x <= 0: return Rect2(size / 2.0, Vector2.ONE)
	var k := size / Vector2(_vp.size)
	var r := Rect2()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = m.global_transform * m.get_aabb()
		for i in 8:
			var p := _cam.unproject_position(box.get_endpoint(i)) * k
			if first: r = Rect2(p, Vector2.ZERO)
			else: r = r.expand(p)
			first = false
	return r

## A prop's foot (its position on the ground, a little in front) in canvas coordinates.
func _screen_base(n: Node3D) -> Vector2:
	if n == null or _cam == null: return Vector2.ZERO
	var p := _cam.unproject_position(n.global_position + Vector3(0, 0, 0.5))
	return p * (size / Vector2(_vp.size)) if _vp.size.x > 0 else p

## A prop's top in canvas coordinates (where its station button goes).
func _screen_of(n: Node3D) -> Vector2:
	if n == null or _cam == null: return Vector2.ZERO
	var p := _cam.unproject_position(n.global_position + Vector3(0, float(n.get_meta("top", 1.0)) + 0.15, 0))
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
	for st in STATIONS:
		var b := TdMenuButton.new()
		b.style = TdButton.Style.MENU_PRIMARY if st.get("primary", false) else TdButton.Style.MENU_WOOD
		b.custom_minimum_size = Vector2(236, 72 if st.locked else 60)
		b.size = b.custom_minimum_size
		b.text = st.label
		b.icon = TdTheme.texture(st.icon)
		b.selectable = true
		b.left_pad = 20
		b.font_size = 26
		add_child(b)
		buttons[st.id] = b
		var locked_line := "Coming later" if st.locked else ""
		if st.get("gate", "") == "workshop" and not MenuLogic.workshop_unlocked(GameApp.catalog, SaveData.progress):
			locked_line = MenuLogic.workshop_locked_text(GameApp.catalog) # "Opens after Chapter 2"
		if locked_line != "":
			b.custom_minimum_size = Vector2(maxf(236.0, 90.0 + TdTheme.font("nunito_bold").get_string_size(locked_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x), 72)
			b.size = b.custom_minimum_size
			b.sub = locked_line
			b.set_interactable(false, locked_line)
		elif st.action != "":
			b.clicked.connect(Callable(self, st.action))
		if not props.has(st.id): b.visible = false # no slot for it in the layout yet
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
	resized.connect(_place_buttons)
	_place_buttons.call_deferred()

## Each station's button sits above its prop with a leader line down to it (re-placed every frame: the 3D view's
## size settles late). Buttons never overlap: laid out left to right along the row, pushed apart to keep BUTTON_GAP;
## a button that would still collide moves to a second row above.
func _place_buttons() -> void:
	var items := []
	for st in STATIONS:
		var b: TdButton = buttons[st.id]
		if not b.visible or not props.has(st.id): continue
		var front: bool = _front.get(st.id, false)
		items.append({"b": b, "front": front, "anchor": _screen_base(props[st.id]) if front else _screen_of(props[st.id])})
	# back-row buttons above their props, front-row ones below (mirrored: the same layout with y flipped)
	var back := items.filter(func(i): return not i.front)
	var front_items := items.filter(func(i): return i.front)
	var rb := layout_buttons(back.map(func(i): return [i.anchor, i.b.size]), size.x, BUTTON_GAP, BUTTON_LIFT)
	var rf := layout_buttons(front_items.map(func(i): return [Vector2(i.anchor.x, -i.anchor.y), i.b.size]), size.x, BUTTON_GAP, BUTTON_LIFT)
	for k in rf.size(): rf[k] = Rect2(Vector2(rf[k].position.x, -rf[k].end.y), rf[k].size)
	items = back + front_items
	var rects := rb + rf
	for k in items.size():
		var b: TdButton = items[k].b
		var r: Rect2 = rects[k]
		b.position = r.position
		var line: Line2D = b.get_meta("leader") if b.has_meta("leader") else null
		if line == null:
			line = Line2D.new()
			line.width = 3.0
			line.default_color = Color(TdTheme.color("cream.100"), 0.7)
			add_child(line)
			move_child(line, b.get_index())
			b.set_meta("leader", line)
		var a: Vector2 = items[k].anchor
		var from := Vector2(r.get_center().x, r.position.y if items[k].front else r.end.y)
		line.points = PackedVector2Array([from, a])

## Places buttons (each [anchor point, size]) centred above their anchors, `lift` px up, without overlaps: sorted by
## x and pushed right to keep `gap`; the row is then shifted back inside [gap, width - gap]; a button that still
## collides goes to a second row above. Returns a Rect2 per input, in input order. (Static: tested.)
static func layout_buttons(items: Array, width: float, gap: float, lift: float) -> Array:
	var order := range(items.size())
	order.sort_custom(func(a, b): return items[a][0].x < items[b][0].x)
	var rects := []
	rects.resize(items.size())
	var row_y := 1e9
	for i in order: row_y = minf(row_y, items[i][0].y - lift - items[i][1].y)
	var xs := []
	var prev_end := -1e9
	for i in order:
		var w: float = items[i][1].x
		var x := maxf(items[i][0].x - w / 2.0, prev_end + gap)
		xs.append(x)
		prev_end = x + w
	# shift the whole row back inside the screen
	if not xs.is_empty():
		var over: float = prev_end - (width - gap)
		var under: float = gap - xs[0]
		var shift := -over if over > 0.0 else (under if under > 0.0 else 0.0)
		for k in xs.size(): xs[k] += shift
	for k in order.size():
		var i: int = order[k]
		var sz: Vector2 = items[i][1]
		var y := minf(items[i][0].y - lift - sz.y, row_y + 40.0) # roughly one row, following the anchors a little
		var r := Rect2(Vector2(xs[k], y), sz)
		# still colliding with an earlier button (after the shift): up to the second row
		for j in range(k):
			var other: Rect2 = rects[order[j]]
			if other.grow(gap / 2.0).intersects(r.grow(gap / 2.0)):
				r.position.y = other.position.y - sz.y - gap
		rects[i] = r
	return rects

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
		if b == null or not b.visible:
			index += 1
			continue
		tour_step = index
		_highlighted = b
		b.selected = true
		bubble.show_line(TOUR_SPEAKER, TOUR[index][1], true, GameApp.portrait_texture("Princess"))
		bubble.set_hint("Tour · %d/%d" % [index + 1, TOUR.size()], "Click or [b]%s[/b]" % KeyBinds.first(KeyBinds.Skip))
		# beside the station's prop (right of it, or left for props on the right half), under the station row: the
		# bubble's area is cut to that side, so it covers neither the prop it describes nor another station
		var pr := _prop_rect(props.get(TOUR[index][0]))
		var row_bottom := b.get_global_rect().end.y
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

## Multiplayer: the co-op lobby (connects to the relay).
func open_multiplayer() -> TdPopup:
	end_tour()
	var p := CoopLobby.new()
	p.free_on_close = true
	popups.add_child(p)
	p.open()
	return p
