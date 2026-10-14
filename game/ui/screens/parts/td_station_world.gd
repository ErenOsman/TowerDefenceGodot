class_name TdStationWorld
extends SubViewportContainer
## A "place" diorama with stations on a ring, built from a layout.json (the Camp's schema: board, ring, centre,
## slots, decor) — shared by the Camp (art/camp/layout.json) and the Guild (art/guild/layout.json). Full-rect 3D
## view in its own world: the ground (a map-kit BoardView of the board's size, unless the layout brings its own floor
## as decor), the station props on their slots, the centre piece (a station too when it has a `station` field), the
## decor, all playing their Idle loops; TdDiorama's light, and camp.gd's camera (fov 34, framed on the ring centre).
## Station buttons are placed by place_buttons(): in front of the prop, else beside it, else above it — the first
## spot that covers no prop and no other button (UI/UX ruling 2026-10-14: props never move for buttons). A prop can also be a hotspot (hover: highlight + tooltip, click: an action).
##   var w := TdStationWorld.new(); add_child(w); w.build(layout, func(p): return GameApp.prop_scene("guild", p), false)

const BOARD := Vector2(14, 10)
## Station buttons: the gap kept between them, and how far above its prop's top a button sits.
const BUTTON_GAP := 16.0
const BUTTON_LIFT := 28.0
## How far below a prop's foot its floor button starts.
const FLOOR_DROP := 6.0

var props := {}   # station id → Node3D
var _all: Array = []   # every prop placed (stations, centre, decor): what buttons keep clear of
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
	# keeps animating, but only while visible and not under a full-screen window (_process)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
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
	if not centre.is_empty() and centre.get("prop") != null: # a centre may be empty (the Guild's rug)
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

## The props' Idle loops keep playing; the 3D view is not drawn while a full-screen window (Workshop, Hand,
## Codex, Settings… over the 88 % scrim) covers it (TdDiorama.animate_unless_covered; browser smoke test 2026-10-14).
func _process(_delta: float) -> void:
	if vp != null: TdDiorama.animate_unless_covered(vp, self)

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
	_all.append(m)
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

## Places each station's button (ids in order; buttons: id → Control) by the shared rule (UI/UX ruling 2026-10-14:
## props never move for buttons). For each station, in order, the first candidate that overlaps no prop and no
## button already placed (touching another prop counts) and stays inside the board's screen rect (if none is clean,
## "above" may still touch decor — props that are no station — but no station prop): (1) on the floor in front of (below) its prop; (2) beside it on the
## floor, left or right, the side facing more free space first; (3) above the prop. Nothing fits: the candidate that
## covers the least.
## A short leader line joins the button to its prop when there is a gap.
func place_buttons(host: Control, buttons: Dictionary, ids: Array) -> void:
	var placed := []
	var screen := Rect2(Vector2(BUTTON_GAP, BUTTON_GAP), host.size - Vector2(BUTTON_GAP, BUTTON_GAP) * 2.0)
	# inside the board's left, right and front edges (a button above a back-row prop may rise past its back edge)
	var area := screen
	var br := board_rect()
	if br.has_area():
		var top := screen.position.y
		var x0 := maxf(screen.position.x, br.position.x)
		var x1 := minf(screen.end.x, br.end.x)
		area = Rect2(Vector2(x0, top), Vector2(x1 - x0, minf(screen.end.y, br.end.y) - top))
	for id in ids:
		var b: Control = buttons.get(id)
		if b == null or not b.visible or not props.has(id) or props[id] == null: continue
		var obstacles := obstacle_rects(host.size, props[id]) # the OTHER props
		var station_obstacles := obstacle_rects(host.size, props[id], true) # the other STATION props only
		var cands := candidates(prop_rect(props[id]), b.size, obstacles)
		var pick: Dictionary = {}
		var own := prop_rect(props[id])
		for c in cands:
			if area.encloses(c.rect) and is_free(c.rect, obstacles, placed) and reads_as_own(c.rect, own, obstacles):
				pick = c
				break
		# nothing clean: "above" may touch decor (non-station props), never another station's prop or a button
		if pick.is_empty():
			var above: Dictionary = cands[cands.size() - 1]
			if area.encloses(above.rect) and is_free(above.rect, station_obstacles, placed): pick = above
		if pick.is_empty(): # nothing is free: the candidate covering the least (buttons count heavily, a spot nearer
			# to another prop than to its own counts more than a small touch)
			var best := 1e18
			for c in cands:
				var cost := overlap(c.rect, obstacles, placed) + (0.0 if area.encloses(c.rect) else 1e9) \
					+ (0.0 if reads_as_own(c.rect, own, obstacles) else 1e6) # labelling a neighbour is worse than a touch
				if cost < best:
					best = cost
					pick = c
		placed.append(pick.rect)
		_put(host, b, pick.rect, pick.anchor)

## The board's screen rect (its four ground corners projected; tile centres at whole numbers, so ±0.5): buttons stay
## inside it.
func board_rect() -> Rect2:
	if cam == null or vp == null or vp.size.x <= 0: return Rect2()
	var k := size / Vector2(vp.size)
	var r := Rect2()
	var first := true
	for c in [Vector3(-0.5, 0, 0.5), Vector3(board.x - 0.5, 0, 0.5), Vector3(-0.5, 0, -board.y + 0.5), Vector3(board.x - 0.5, 0, -board.y + 0.5)]:
		var p := cam.unproject_position(c) * k
		if first: r = Rect2(p, Vector2.ZERO)
		else: r = r.expand(p)
		first = false
	return r

## The rects of the props other than `own` that buttons must not touch: their projected bounds (only the top is
## trimmed a little: the boxes are loose there), without ground-sized pieces (a floor or hall wider than half the
## screen). A spot is rejected when it TOUCHES one of them (UI/UX ruling: a button on its own prop beats a spot
## touching another prop).
func obstacle_rects(screen_size: Vector2, own: Node3D = null, stations_only := false) -> Array:
	var out := []
	var station_nodes := props.values()
	for n in _all:
		if not is_instance_valid(n) or n == own: continue
		if stations_only and not station_nodes.has(n): continue
		var r := prop_rect(n)
		if r.size.x > screen_size.x * 0.5: continue
		out.append(r.grow_individual(-r.size.x * 0.04, -r.size.y * 0.08, -r.size.x * 0.04, 0.0))
	return out

## The candidate rects for a button of size sz at a prop's screen rect pr, in the rule's order: front (centred,
## just below the prop), the two sides on the floor (the side with more room first), above. {rect, anchor}
func candidates(pr: Rect2, sz: Vector2, obstacles: Array) -> Array:
	var foot := Vector2(pr.get_center().x, pr.end.y)
	var floor_y := pr.end.y - sz.y # beside: the button's bottom on the prop's foot line
	var left := {"rect": Rect2(Vector2(pr.position.x - BUTTON_GAP - sz.x, floor_y), sz), "anchor": Vector2(pr.position.x, pr.end.y - sz.y / 2.0)}
	var right := {"rect": Rect2(Vector2(pr.end.x + BUTTON_GAP, floor_y), sz), "anchor": Vector2(pr.end.x, pr.end.y - sz.y / 2.0)}
	var sides := [left, right] if _room(left.rect, obstacles) >= _room(right.rect, obstacles) else [right, left]
	return [{"rect": Rect2(Vector2(foot.x - sz.x / 2.0, pr.end.y + FLOOR_DROP), sz), "anchor": foot}] + sides + \
		[{"rect": Rect2(Vector2(foot.x - sz.x / 2.0, pr.position.y - BUTTON_LIFT - sz.y), sz), "anchor": Vector2(foot.x, pr.position.y)}]

## How free a rect's surroundings are: the distance to the nearest obstacle (more = freer).
static func _room(r: Rect2, obstacles: Array) -> float:
	var best := 1e9
	for o in obstacles:
		if o.intersects(r): return 0.0
		best = minf(best, o.get_center().distance_to(r.get_center()))
	return best

## A button reads as its own prop's: its centre is nearer to that prop than to any other prop (a "beside" spot in
## the gap between two props would label the neighbour).
static func reads_as_own(r: Rect2, own: Rect2, obstacles: Array) -> bool:
	var d := _dist(r.get_center(), own)
	for o in obstacles:
		if _dist(r.get_center(), o) < d: return false
	return true

static func _dist(p: Vector2, r: Rect2) -> float:
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))

## How much a rect covers: the overlap area with the obstacles, plus 50× that with placed buttons.
static func overlap(r: Rect2, obstacles: Array, placed: Array) -> float:
	var a := 0.0
	for o in obstacles: a += r.intersection(o).get_area()
	for p in placed: a += 50.0 * r.intersection(p.grow(BUTTON_GAP / 2.0)).get_area()
	return a

## A rect touches no other prop and overlaps no placed button (with the button gap).
static func is_free(r: Rect2, obstacles: Array, placed: Array) -> bool:
	for o in obstacles:
		if o.grow(4.0).intersects(r): return false # touching counts
	for p in placed:
		if p.grow(BUTTON_GAP / 2.0).intersects(r): return false
	return true

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
	var from := Vector2(clampf(a.x, r.position.x, r.end.x), clampf(a.y, r.position.y, r.end.y)) # the rect's nearest point
	line.visible = from.distance_to(a) > 10.0
	line.points = PackedVector2Array([from, a])

# ------------------------------------------------------------------ prop hotspots

## Makes a prop clickable: an invisible Control on `host` following the prop's screen rect; hovering highlights the
## prop (a warm glow over its meshes) and shows `tip`; a click calls on_click. Returns the Control.
func hotspot(host: Control, station_id: String, tip: String, on_click: Callable, glow := true) -> Control:
	var n: Node3D = props.get(station_id)
	var c := Control.new()
	c.mouse_filter = MOUSE_FILTER_STOP if n != null else MOUSE_FILTER_IGNORE
	c.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	host.add_child(c)
	if glow: # no glow on a locked prop (it stays dimmed)
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

static var _dim: ShaderMaterial = null

## Darkens a prop (a locked station, e.g. the Camp's Signpost before Chapter 2).
func dim(n: Node3D, on: bool) -> void:
	if n == null: return
	if _dim == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_mul;\nvoid fragment() { ALBEDO = vec3(0.5, 0.5, 0.52); }\n"
		_dim = ShaderMaterial.new()
		_dim.shader = sh
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = _dim if on else null

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
