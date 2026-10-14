class_name TdStationWorld
extends SubViewportContainer
## A "place" diorama with stations on a ring, built from a layout.json (the Camp's schema: board, ring, centre,
## slots, decor) — shared by the Camp (art/camp/layout.json) and the Guild (art/guild/layout.json). Full-rect 3D
## view in its own world: the ground (a map-kit BoardView of the board's size, unless the layout brings its own floor
## as decor), the station props on their slots, the centre piece (a station too when it has a `station` field), the
## decor, all playing their Idle loops; TdDiorama's light, and camp.gd's camera (fov 34, framed on the ring centre).
## Station buttons are placed by place_buttons(): ON THE FLOOR just in front of (below) their prop, whatever its
## row (UI/UX ruling 2026-10-14: never above a prop or on a back wall), never overlapping, with a short leader line
## up to the prop's foot. A prop can also be a hotspot (hover: highlight + tooltip, click: an action).
##   var w := TdStationWorld.new(); add_child(w); w.build(layout, func(p): return GameApp.prop_scene("guild", p), false)

const BOARD := Vector2(14, 10)
## Station buttons: the gap kept between them, and how far above its prop's top a button sits.
const BUTTON_GAP := 16.0
const BUTTON_LIFT := 28.0
## How far below a prop's foot its floor button starts.
const FLOOR_DROP := 6.0

## Buttons on the floor in front of their props (the Guild); off = back-row buttons above their props, front-row
## ones below (the Camp: its back-row props stand behind the campfire and the Workshop table, which floor buttons
## would cover).
var floor_buttons := true
var props := {}   # station id → Node3D
var front := {}   # station id → true when its button goes below the prop (row "front")
var board := BOARD
var vp: SubViewport
var cam: Camera3D
var root3d: Node3D

func _init() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE

## Builds the world. prop_loader(name) → PackedScene or null; map_ground: lay the map kit's ground under it (the
## Camp) — off when the layout's decor is a floor (the Guild).
func build(layout: Dictionary, prop_loader: Callable, map_ground := true) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	root3d = Node3D.new()
	vp.add_child(root3d)
	TdDiorama._add_light(root3d, TdTheme.color("wood.900"))
	var bt = layout.get("board", {}).get("tiles", [BOARD.x, BOARD.y])
	board = Vector2(float(bt[0]), float(bt[1]))
	if map_ground:
		var level := LevelAsset.new()
		var rows: Array[String] = []
		for y in int(board.y): rows.append(".".repeat(int(board.x)))
		level.terrain = rows
		var bv := BoardView.new()
		root3d.add_child(bv)
		var app := TdMenu.app()
		var kit: Array = app.lib.rules.tiles if app != null and app.lib.rules != null else []
		bv.build(BattleGrid.new(int(board.x), int(board.y)), level, kit, func(p): return app.model_scene(p))
	for slot in layout.get("slots", []):
		if slot.get("prop") == null or slot.get("station") == null: continue
		front[str(slot.station)] = str(slot.get("row", "back")) == "front"
		props[str(slot.station)] = add_prop(prop_loader, str(slot.prop), tile_of(slot.tile), float(slot.get("scale", 1.0)), float(slot.get("face_yaw", 0.0)))
	var centre: Dictionary = layout.get("centre", {})
	if not centre.is_empty():
		var c := add_prop(prop_loader, str(centre.prop), tile_of(centre.tile), float(centre.get("scale", 1.0)), float(centre.get("yaw", 0.0)))
		if centre.get("station") != null: # the centre piece is a station too (the Guild's Mission Board)
			props[str(centre.station)] = c
			front[str(centre.station)] = str(centre.get("row", "back")) == "front"
	for d in layout.get("decor", []): add_prop(prop_loader, str(d.prop), tile_of(d.tile), float(d.get("scale", 1.0)), float(d.get("yaw", 0.0)))
	cam = Camera3D.new()
	cam.fov = 34.0
	root3d.add_child(cam)
	cam.current = true
	# framed on the ring round the centre (not the whole board)
	var ring: Dictionary = layout.get("ring", {})
	var fire := tile_of(ring.get("centre", centre.get("tile", [board.x / 2.0 - 0.5, board.y / 2.0 - 0.5])))
	var cc := Vector3(fire.x, 0.0, -fire.y - 0.6)
	cam.position = cc + Vector3(0, 14.5, 17.0)
	cam.look_at(cc, Vector3.UP)

## A layout.json, or `fallback` when it cannot be read.
static func load_layout(path: String, fallback: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and d.has("slots"): return d
	return fallback

static func tile_of(t) -> Vector2:
	return Vector2(float(t[0]), float(t[1])) if t is Array and t.size() >= 2 else Vector2.ZERO

## Places a prop (tile → Vector3(x, 0, -depth)), plays its Idle, records its top (meta "top"); null when missing.
func add_prop(prop_loader: Callable, prop: String, at: Vector2, scale_by: float, yaw: float) -> Node3D:
	var sc: PackedScene = prop_loader.call(prop) if prop_loader.is_valid() else null
	if sc == null: return null
	var m: Node3D = sc.instantiate()
	m.position = Vector3(at.x, 0.0, -at.y)
	m.scale = Vector3.ONE * scale_by
	m.rotation_degrees.y = yaw
	root3d.add_child(m)
	TdDiorama._idle(m)
	var top := 0.5
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y)
	m.set_meta("top", top)
	return m

## Adds a light to the world (e.g. the Guild's hearth glow).
func add_light(light: Light3D) -> void:
	root3d.add_child(light)

# ------------------------------------------------------------------ screen positions

## A prop's screen rectangle in canvas coordinates (its meshes' boxes projected).
func prop_rect(n: Node3D) -> Rect2:
	if n == null or cam == null or vp.size.x <= 0: return Rect2(size / 2.0, Vector2.ONE)
	var k := size / Vector2(vp.size)
	var r := Rect2()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = m.global_transform * m.get_aabb()
		for i in 8:
			var p := cam.unproject_position(box.get_endpoint(i)) * k
			if first: r = Rect2(p, Vector2.ZERO)
			else: r = r.expand(p)
			first = false
	return r

## A prop's foot (its position on the ground, a little in front) in canvas coordinates.
func screen_base(n: Node3D) -> Vector2:
	if n == null or cam == null: return Vector2.ZERO
	var p := cam.unproject_position(n.global_position + Vector3(0, 0, 0.5))
	return p * (size / Vector2(vp.size)) if vp.size.x > 0 else p

## A prop's top in canvas coordinates.
func screen_top(n: Node3D) -> Vector2:
	if n == null or cam == null: return Vector2.ZERO
	var p := cam.unproject_position(n.global_position + Vector3(0, float(n.get_meta("top", 1.0)) + 0.15, 0))
	return p * (size / Vector2(vp.size)) if vp.size.x > 0 else p

# ------------------------------------------------------------------ station buttons

## Places each station's button (ids in order; buttons: id → Control) on the floor just below its prop's foot, with
## a short leader line drawn on `host` under the button. Back-row and front-row buttons are laid out as two rows
## (each without overlaps, layout_buttons); a back-row button that would still hit a front-row one moves up beside
## its prop's foot no further than needed.
func place_buttons(host: Control, buttons: Dictionary, ids: Array) -> void:
	if not floor_buttons:
		_place_above(host, buttons, ids)
		return
	var groups := [[], []]
	for id in ids:
		var b: Control = buttons.get(id)
		if b == null or not b.visible or not props.has(id) or props[id] == null: continue
		var fr: bool = front.get(id, false)
		groups[1 if fr else 0].append({"b": b, "anchor": screen_base(props[id])})
	var placed := []
	for g in [groups[1], groups[0]]: # front row first: back-row buttons yield to it
		var rs := layout_buttons(g.map(func(i): return [Vector2(i.anchor.x, -i.anchor.y), i.b.size]), host.size.x, BUTTON_GAP, FLOOR_DROP)
		for k in rs.size():
			var r: Rect2 = Rect2(Vector2(rs[k].position.x, -rs[k].end.y), rs[k].size)
			for other in placed:
				if other.grow(BUTTON_GAP / 2.0).intersects(r.grow(BUTTON_GAP / 2.0)):
					r.position.y = other.position.y - r.size.y - BUTTON_GAP
			placed.append(r)
			_put(host, g[k].b, r, g[k].anchor)

## The Camp's placement: back-row buttons above their props' tops, front-row ones below their feet.
func _place_above(host: Control, buttons: Dictionary, ids: Array) -> void:
	var items := []
	for id in ids:
		var b: Control = buttons.get(id)
		if b == null or not b.visible or not props.has(id) or props[id] == null: continue
		var fr: bool = front.get(id, false)
		items.append({"b": b, "front": fr, "anchor": screen_base(props[id]) if fr else screen_top(props[id])})
	var back := items.filter(func(i): return not i.front)
	var front_items := items.filter(func(i): return i.front)
	var rb := layout_buttons(back.map(func(i): return [i.anchor, i.b.size]), host.size.x, BUTTON_GAP, BUTTON_LIFT)
	var rf := layout_buttons(front_items.map(func(i): return [Vector2(i.anchor.x, -i.anchor.y), i.b.size]), host.size.x, BUTTON_GAP, BUTTON_LIFT)
	for k in rf.size(): rf[k] = Rect2(Vector2(rf[k].position.x, -rf[k].end.y), rf[k].size)
	items = back + front_items
	var rects := rb + rf
	for k in items.size(): _put(host, items[k].b, rects[k], items[k].anchor)

func _put(host: Control, b: Control, r: Rect2, a: Vector2) -> void:
	b.position = r.position
	var line: Line2D = b.get_meta("leader") if b.has_meta("leader") else null
	if line == null:
		line = Line2D.new()
		line.width = 3.0
		line.default_color = Color(TdTheme.color("cream.100"), 0.7)
		host.add_child(line)
		host.move_child(line, b.get_index())
		b.set_meta("leader", line)
	var from := Vector2(r.get_center().x, r.position.y if a.y <= r.position.y else r.end.y)
	line.visible = from.distance_to(a) > 10.0
	line.points = PackedVector2Array([from, a])

# ------------------------------------------------------------------ prop hotspots

## Makes a prop clickable: an invisible Control on `host` following the prop's screen rect; hovering highlights the
## prop (a warm glow over its meshes) and shows `tip`; a click calls on_click. Returns the Control.
func hotspot(host: Control, station_id: String, tip: String, on_click: Callable) -> Control:
	var n: Node3D = props.get(station_id)
	var c := Control.new()
	c.mouse_filter = MOUSE_FILTER_STOP if n != null else MOUSE_FILTER_IGNORE
	c.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	host.add_child(c)
	c.mouse_entered.connect(func(): highlight(n, true))
	c.mouse_exited.connect(func(): highlight(n, false))
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed: on_click.call())
	TdTooltipTrigger.attach(c, "", tip)
	c.set_meta("prop", n)
	_hotspots.append(c)
	return c

var _hotspots: Array = []
static var _glow: ShaderMaterial = null

## Lays every hotspot over its prop (call each frame, like place_buttons).
func place_hotspots() -> void:
	for c in _hotspots:
		var n: Node3D = c.get_meta("prop")
		if n == null: continue
		var r := prop_rect(n)
		c.position = r.position
		c.size = r.size

## A warm additive glow over a prop's meshes (hover).
func highlight(n: Node3D, on: bool) -> void:
	if n == null: return
	if _glow == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add;\nvoid fragment() { ALBEDO = vec3(0.28, 0.2, 0.06); }\n"
		_glow = ShaderMaterial.new()
		_glow.shader = sh
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = _glow if on else null
	n.set_meta("highlighted", on)

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
		for j in range(k):
			var other: Rect2 = rects[order[j]]
			if other.grow(gap / 2.0).intersects(r.grow(gap / 2.0)):
				r.position.y = other.position.y - sz.y - gap
		rects[i] = r
	return rects
