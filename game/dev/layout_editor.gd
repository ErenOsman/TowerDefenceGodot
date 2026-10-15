class_name TdLayoutEditor
extends CanvasLayer
## Dev tool (Eren 2026-10-15, "keşke manuel yerlerini değiştirebilsem"): moves the props of a station diorama — the
## Camp or the Guild (any scene with a `world: TdStationWorld` and a `LAYOUT` constant) — and saves them back to its
## layout.json in the same schema. Turned on from the F1 dev panel ("Edit layout", Shortcuts tab), so it exists only
## where the dev panel does (debug builds, or `-- --dev`).
##   Left drag a prop: move it on the board plane, snapped to SNAP tiles (Shift: free).
##   Q / E: turn the selected prop by YAW_STEP degrees.  + / - (or the wheel over a prop): scale by SCALE_STEP.
##   Delete: remove the selected decor prop (stations, centre: no).  Ctrl+S: save.  Esc: stop editing.
## While it runs, a full-screen catcher takes every mouse event (no station button reacts); the scene keeps
## re-placing its station buttons each frame, so they follow the props live. Save writes res://art/<place>/layout.json
## (slots keep their slot ids, stations, rows and notes; only tile / face_yaw / yaw / scale change, deleted decor
## is dropped); where res:// is read-only (an exported build) it writes user://layout_<place>.json instead and copies
## the JSON to the clipboard.

signal finished

const SNAP := 0.25
const YAW_STEP := 15.0
const SCALE_STEP := 0.1

var scene: Control
var world: TdStationWorld
var layout_path := ""
var layout: Dictionary = {}
## The selected entry of world.entries ({node, kind, index, prop}), or {}.
var selected: Dictionary = {}
var dirty := false
var last_saved_path := ""
var _drag := false
var _grab := Vector2.ZERO
var _removed: Array = [] # decor indexes deleted since the last save
var _catcher: Control
var _title: Label
var _info: Label
var _status: Label

## Whether a scene can be edited: a Control with a TdStationWorld `world` and a LAYOUT path.
static func can_edit(s: Node) -> bool:
	if not (s is Control) or s.get_script() == null: return false
	return s.get("world") is TdStationWorld and s.get_script().get_script_constant_map().has("LAYOUT")

func _init() -> void:
	layer = 100 # over the scene and its popups, under the dev panel (120)
	process_mode = Node.PROCESS_MODE_ALWAYS

## Starts editing a scene (can_edit). Returns false when it cannot.
func start(s: Control) -> bool:
	if not can_edit(s): return false
	scene = s
	world = s.get("world")
	var consts: Dictionary = s.get_script().get_script_constant_map()
	layout_path = consts.LAYOUT
	layout = TdStationWorld.load_layout(layout_path, consts.get("FALLBACK_LAYOUT", {})).duplicate(true)
	_build()
	_refresh()
	return true

func place_name() -> String:
	return layout_path.get_base_dir().get_file().capitalize() # "Camp" / "Guild"

func _build() -> void:
	_catcher = Control.new()
	_catcher.theme = TdTheme.theme()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_mouse)
	add_child(_catcher)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.88)
	sb.border_color = TdTheme.color("gold")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 10; sb.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 18
	_catcher.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	_title = _line(col, 24, TdTheme.color("gold"))
	_info = _line(col, 22, TdTheme.color("cream.100"))
	_line(col, 18, TdTheme.color("cream.200")).text = "Drag: move (snap %s, Shift free) · Q/E turn %d° · +/- or wheel: scale · Del: remove decor · Ctrl+S: save · Esc: stop" % [Num.to_str(SNAP), int(YAW_STEP)]
	_status = _line(col, 18, TdTheme.color("teal"))
	_status.visible = false

func _line(parent: Control, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	parent.add_child(l)
	return l

func _process(_dt: float) -> void:
	if scene == null or not is_instance_valid(scene) or not scene.is_inside_tree() or world == null or not is_instance_valid(world):
		stop() # the scene changed under it

## Stops editing (unsaved changes stay in the scene only until it is left).
func stop() -> void:
	if is_queued_for_deletion(): return
	select({})
	finished.emit()
	queue_free()

# ------------------------------------------------------------------ picking and moving

## The tile under a canvas point (the board plane y = 0), or null when the ray misses it.
func tile_at(pos: Vector2) -> Variant:
	if world == null or world.cam == null or world.vp == null or world.size.x <= 0.0: return null
	var local := world.get_global_transform_with_canvas().affine_inverse() * pos
	var p := local * Vector2(world.vp.size) / world.size
	var o := world.cam.project_ray_origin(p)
	var d := world.cam.project_ray_normal(p)
	if absf(d.y) < 1e-5: return null
	var t := -o.y / d.y
	if t < 0.0: return null
	var hit := o + d * t
	return Vector2(hit.x, -hit.z)

## The prop under a canvas point: the smallest projected box containing it (ground-sized pieces — a floor, a hall —
## are never picked). {} when none.
func pick_at(pos: Vector2) -> Dictionary:
	var best := {}
	var best_area := INF
	for e in world.entries:
		if not is_instance_valid(e.node) or e.node.is_queued_for_deletion(): continue
		var r := world.prop_rect(e.node)
		if r.size.x > world.size.x * 0.5: continue
		if r.has_point(pos) and r.get_area() < best_area:
			best = e
			best_area = r.get_area()
	return best

func select(e: Dictionary) -> void:
	if not selected.is_empty() and is_instance_valid(selected.node): world.highlight(selected.node, false)
	selected = e
	if not selected.is_empty(): world.highlight(selected.node, true)
	_refresh()

static func prop_tile(n: Node3D) -> Vector2:
	return Vector2(n.position.x, -n.position.z)

## Moves the selected prop so its tile is `t` (snapped to SNAP unless free).
func move_selected(t: Vector2, free := false) -> void:
	if selected.is_empty(): return
	if not free: t = t.snapped(Vector2(SNAP, SNAP))
	var n: Node3D = selected.node
	n.position = Vector3(t.x, n.position.y, -t.y)
	_changed()

func rotate_selected(deg: float) -> void:
	if selected.is_empty(): return
	var n: Node3D = selected.node
	n.rotation_degrees.y = wrapf(snappedf(n.rotation_degrees.y + deg, 0.1), -180.0, 180.0)
	_changed()

func scale_selected(by: float) -> void:
	if selected.is_empty(): return
	var n: Node3D = selected.node
	var s := maxf(0.1, snappedf(n.scale.x + by, 0.01))
	n.set_meta("top", float(n.get_meta("top", 1.0)) * s / maxf(0.01, n.scale.x))
	n.scale = Vector3.ONE * s
	_changed()

## Deletes the selected prop when it is decor (stations and the centre stay: their buttons and actions need them).
func delete_selected() -> bool:
	if selected.is_empty(): return false
	if selected.kind != "decor":
		_say("Only decor can be removed (%s is a %s)." % [selected.prop, "station" if selected.kind == "slot" else "centre piece"])
		return false
	var e := selected
	select({})
	_removed.append(e.index)
	world.entries.erase(e)
	world.remove_prop(e.node)
	_changed()
	return true

func _changed() -> void:
	dirty = true
	_refresh()

func _on_mouse(ev: InputEvent) -> void:
	var pos: Vector2 = _catcher.get_global_transform_with_canvas() * ev.position if ev is InputEventMouse else Vector2.ZERO
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var e := pick_at(pos)
				select(e)
				var t = tile_at(pos)
				_drag = not e.is_empty() and t != null
				if _drag: _grab = t - prop_tile(e.node)
			else:
				_drag = false
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var e := pick_at(pos)
			if not e.is_empty() and e != selected: select(e)
			scale_selected(SCALE_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -SCALE_STEP)
	elif ev is InputEventMouseMotion and _drag:
		var t = tile_at(pos)
		if t != null: move_selected(t - _grab, Input.is_key_pressed(KEY_SHIFT) or (ev as InputEventMouseMotion).shift_pressed)
	_catcher.accept_event()

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or get_tree().paused: return # paused: the dev panel is open
	var k: InputEventKey = ev
	var used := true
	match k.keycode:
		KEY_Q: rotate_selected(YAW_STEP)
		KEY_E: rotate_selected(-YAW_STEP)
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: scale_selected(SCALE_STEP)
		KEY_MINUS, KEY_KP_SUBTRACT: scale_selected(-SCALE_STEP)
		KEY_DELETE: delete_selected()
		KEY_S:
			if k.ctrl_pressed or k.meta_pressed:
				if not k.echo: save()
			else: used = false
		KEY_ESCAPE:
			if not k.echo: stop()
		_: used = false
	if used: get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ saving

## The layout with the props where they stand now (the same schema: only tile / face_yaw / yaw / scale change;
## removed decor dropped). Whole numbers are written as ints.
func current_layout() -> Dictionary:
	var out := layout.duplicate(true)
	for e in world.entries:
		if not is_instance_valid(e.node): continue
		var n: Node3D = e.node
		var tile := [snappedf(n.position.x, 0.01), snappedf(-n.position.z, 0.01)]
		var yaw := snappedf(n.rotation_degrees.y, 0.1)
		var sc := snappedf(n.scale.x, 0.01)
		var d = null
		match e.kind:
			"slot": d = out.slots[e.index]
			"centre": d = out.centre
			"decor": d = out.decor[e.index]
		if d == null: continue
		d["tile"] = tile
		d["face_yaw" if e.kind == "slot" else "yaw"] = yaw
		d["scale"] = sc
	var gone := _removed.duplicate()
	gone.sort()
	gone.reverse()
	for i in gone: out.decor.remove_at(i)
	return _ints(out)

static func _ints(v):
	if v is float and v == floorf(v) and absf(v) < 1e9: return int(v)
	if v is Array: return v.map(func(x): return _ints(x))
	if v is Dictionary:
		var d := {}
		for k in v: d[k] = _ints(v[k])
		return d
	return v

## Writes the layout (res:// when writable, else user://layout_<place>.json + the clipboard). Returns the path or "".
func save() -> String:
	var out := current_layout()
	var text := JSON.stringify(out, " ", false) + "\n"
	var path := layout_path
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		path = "user://layout_%s.json" % place_name().to_lower()
		f = FileAccess.open(path, FileAccess.WRITE)
		DisplayServer.clipboard_set(text)
	if f == null:
		_say("Not saved: %s" % error_string(FileAccess.get_open_error()))
		return ""
	f.store_string(text)
	f.close()
	# the decor indexes shift past the removed ones
	for e in world.entries:
		if e.kind == "decor": e.index -= _removed.filter(func(i): return i < e.index).size()
	_removed.clear()
	layout = out
	dirty = false
	last_saved_path = path
	_say("Saved %s%s" % [ProjectSettings.globalize_path(path) if path.begins_with("user://") else path,
		" (res:// is read-only here; JSON copied to the clipboard)" if path.begins_with("user://") else ""])
	print("[LayoutEditor] saved ", path)
	return path

func _say(t: String) -> void:
	if _status != null:
		_status.text = t
		_status.visible = t != ""
	_refresh()

func _refresh() -> void:
	if _title == null: return
	_title.text = "Layout editor · %s%s" % [place_name(), " *" if dirty else ""]
	if selected.is_empty() or not is_instance_valid(selected.node):
		_info.text = "Click a prop to select it."
		return
	var n: Node3D = selected.node
	var t := prop_tile(n)
	var what: String = {"slot": "station " + _station_of(selected), "centre": "centre", "decor": "decor"}.get(selected.kind, "")
	_info.text = "%s (%s) · tile [%s, %s] · yaw %s° · scale %s" % [selected.prop, what, Num.to_str(snappedf(t.x, 0.01)),
		Num.to_str(snappedf(t.y, 0.01)), Num.to_str(snappedf(n.rotation_degrees.y, 0.1)), Num.to_str(snappedf(n.scale.x, 0.01))]

func _station_of(e: Dictionary) -> String:
	if e.kind == "slot" and e.index < layout.get("slots", []).size():
		var s: Dictionary = layout.slots[e.index]
		return "%s, slot %d" % [str(s.get("station")), int(s.get("slot", -1))]
	return ""
