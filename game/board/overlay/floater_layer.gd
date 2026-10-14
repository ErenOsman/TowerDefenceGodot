class_name FloaterLayer
extends Control
## Floating numbers and words over the board (FloaterLayer.cs): pooled labels that pop in with a small overshoot,
## rise and fade. Several on one spot at once stack upwards instead of covering each other; one behind the camera
## is hidden. Unscaled time. Damage numbers are 48 px, words 40 px (UI rules: 44–56 for numbers), outlined.

const RISE := 40.0        # canvas pixels risen over a floater's life
const STACK_STEP := 34.0  # canvas pixels between floaters on one spot
const SAME_SPOT := 0.35   # world units: closer than this counts as one spot

var cam: Camera3D = null
var _live: Array = []     # Dictionary {label, world, age, life, lift}
var _pool: Array = []

func _init() -> void:
	name = "Floaters"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Words that rise from a point in the world and fade.
func float_text(world: Vector3, text: String, color: Color, life: float, font_size: int) -> void:
	var label: Label = _pool.pop_back() if _pool.size() > 0 else _new_label()
	label.visible = true
	move_child(label, get_child_count() - 1)
	label.text = text
	label.label_settings = OverlayStyle.world_label(font_size, color)
	label.reset_size()
	label.pivot_offset = label.size * Vector2(0.5, 1.0)
	var f := {"label": label, "world": world, "age": 0.0, "life": maxf(0.05, life), "lift": 0.0}
	for other in _live:
		if other.age < other.life * 0.5 and other.world.distance_squared_to(world) < SAME_SPOT * SAME_SPOT:
			f.lift = maxf(f.lift, other.lift + STACK_STEP)
	# neighbours too: two towers side by side both saying "Ready!" overlapped into "ReReady!" (QA 2026-10-14);
	# a floater whose box meets a young one's on screen goes up a step (its x stays over its own unit)
	if cam != null and cam.is_inside_tree() and not cam.is_position_behind(world):
		for k in 6:
			var hit := false
			for other in _live:
				if other.age < other.life * 0.5 and _box(other).grow(-2.0).intersects(_box(f)):
					f.lift += STACK_STEP
					hit = true
					break
			if not hit: break
	_live.append(f)
	_place(f)

## A floater's box on screen at its full size (no pop), where it is now in its rise.
func _box(f: Dictionary) -> Rect2:
	var w: Vector3 = f.world
	if cam.is_position_behind(w): return Rect2()
	var screen := cam.unproject_position(w)
	var under := cam.unproject_position(Vector3(w.x, 0.0, w.z))
	var zoom := WorldUi.readable(WorldUi.zoom(cam, Vector3(w.x, 0.0, w.z)))
	var sz: Vector2 = (f.label as Label).size * zoom
	var t := clampf(f.age / f.life, 0.0, 1.0)
	var bottom := Vector2(under.x, screen.y - (10.0 + f.lift + RISE * t) * zoom)
	return Rect2(bottom - Vector2(sz.x * 0.5, sz.y), sz)

## The texts floating now (tests and tools).
func live_texts() -> Array:
	var out := []
	for f in _live: out.append(f.label.text)
	return out

## Moves, pops and fades the floaters; finished ones go back to the pool.
func tick(dt: float) -> void:
	for i in range(_live.size() - 1, -1, -1):
		var f: Dictionary = _live[i]
		f.age += dt
		if f.age >= f.life:
			f.label.visible = false
			_live.remove_at(i)
			_pool.append(f.label)
			continue
		_place(f)

func _place(f: Dictionary) -> void:
	var label: Label = f.label
	var w: Vector3 = f.world
	if cam == null or not cam.is_inside_tree() or cam.is_position_behind(w):
		label.visible = false
		return
	label.visible = true
	# straight up from the unit on screen: x from the ground under the point, y from the point itself
	var screen := cam.unproject_position(w)
	var under := cam.unproject_position(Vector3(w.x, 0.0, w.z))
	screen.x = under.x
	var t := clampf(f.age / f.life, 0.0, 1.0)
	var pop := clampf(t / 0.18, 0.0, 1.0)
	var zoom := WorldUi.readable(WorldUi.zoom(cam, Vector3(w.x, 0.0, w.z)))
	var s := _ease_back(pop) * zoom
	label.scale = Vector2.ONE * maxf(0.01, s)
	label.position = screen - Vector2(label.size.x * 0.5, label.size.y) - Vector2(0, (10.0 + f.lift + RISE * t) * zoom)
	label.modulate.a = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)

static func _ease_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)

func _new_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l

## Ends every floater at once.
func clear_all() -> void:
	for f in _live:
		f.label.visible = false
		_pool.append(f.label)
	_live.clear()
