class_name BoardCamera
extends Camera3D
## The player's camera over the board (BoardCamera.cs; Animation & Presentation — Design, Camera): pan with
## WASD / arrows (KeyBinds), a middle-drag or a left-drag past a few pixels (the Drag with Mouse setting), screen
## edge scrolling (off by default), zoom with the wheel (clamped), rotate in 90° steps (Q / E). The focus stays
## over the board. Runs on unscaled time, so it works at any game speed and while paused. Follow the action moves
## it only through glide(). The board is framed and centred in the free area the HUD leaves (top bar and hand
## tray) by an off-centre (frustum) projection; picking (project_ray_*) uses the same projection.

@export var pan_speed: float = 8.0
## Pixels from the screen edge that scroll the camera (0 = off, the default).
@export var edge_size: float = 0.0
@export var zoom_step: float = 0.12
## Pitch above the ground, in degrees: the low, miniature-like angle of the Unity Welcome diorama (user, 2026-10-13;
## Unity's gameplay camera used 50).
@export var pitch: float = 50.0
@export var smoothing: float = 10.0
@export var glide_speed: float = 3.0
## What the HUD covers, in canvas pixels (the 1920×1080 reference): left, right, top, bottom. The board is fitted
## and centred in what is left: the top bar (96), the bottom row (tray + action bar, 168; +140 when they need two
## rows). Left and right are 0 by default: the board is centred on the whole width and the right bar may cover its
## edge (Eren, 2026-10-11). The HUD sets them with set_hud_insets.
@export var hud_insets: Vector4 = Vector4(0.0, 0.0, 96.0, 168.0)
## Vertical field of view (degrees).
@export var view_fov: float = 50.0

const DRAG_THRESHOLD := 8.0   # reference pixels a press must move to become a drag
const SHAKE_TIME := 0.3
const MODEL_HEIGHT := 0.8     # room above the far row for the models
const GUTTER := 20.0          # canvas pixels kept free between the board and the HUD

## Key polling: an object with held(action) and pressed(action) (the level's key adapter); null = no keys.
var keys = null
## The Drag with Mouse setting.
var drag_to_pan: bool = true
## Returns true when the pointer is over the HUD (input there is not the board's). Default: the viewport's
## hovered control.
var over_ui: Callable = Callable()

var bounds := Rect2()         # board area in world x / −z (x, y = tile coordinates)
var focus := Vector3.ZERO
var focus_target := Vector3.ZERO
var distance := 10.0
var distance_target := 10.0
var min_distance := 3.0
var max_distance := 20.0
var yaw := 0.0                # degrees, Godot sense (counter-clockwise from above)
var yaw_target := 0.0
var gliding := false
var _free_pan := false        # the player panned: their focus is kept until a glide

var _drag_anchor = null       # Vector3 or null
var _drag_button := MOUSE_BUTTON_NONE
var _left_press = null        # Vector2 or null
var _left_dragging := false
var _shake := 0.0
var _shake_left := 0.0
var _wheel := 0.0
var _last_ticks := 0
var _was_left := false
var _was_middle := false
var _initialized := false

## The current (or just released) left press moved the map: it is not a click.
var left_dragged: bool:
	get: return _left_dragging

## Sets up the camera over a board (width × height tiles) and frames all of it.
func init(width: int, height: int) -> void:
	bounds = Rect2(-0.5, -0.5, width, height)
	focus = Vector3((width - 1) / 2.0, 0.0, -(height - 1) / 2.0)
	focus_target = focus
	yaw = 0.0
	yaw_target = 0.0
	fov = view_fov
	near = 0.1
	far = 200.0
	var fit := fit_distance()
	distance = fit
	distance_target = fit
	min_distance = 3.0
	max_distance = fit # the fit is the widest view: the wheel never zooms out past it
	_initialized = true
	_last_ticks = Time.get_ticks_usec()
	apply()
	# board UI is drawn at its designed size at this framing, whatever the board's size (WorldUi)
	_measure_reference_tile()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(refit): vp.size_changed.connect(refit)

## Turns the view a quarter (dir −1 or +1). The zoom and the pan stay as they are (user, 2026-10-14: rotating
## must not change the zoom); only the limits follow the new angle: the zoom-out limit becomes the fit for it (a
## long board seen lengthwise needs a different distance), a zoom beyond it is pulled in to it, and the focus is
## clamped to the pan limits. The reference tile (board UI size) stays: plates keep their size across a turn.
## The limit is the same fit the level starts with, against the free area the HUD leaves (top bar, tray, End turn:
## the insets plus the gutter), so a tall board turned 90° zooms out until all of it shows above the tray. A view
## that ends up AT that limit is the limit's frame (2026-10-15): a free pan is brought back to the board's centre
## there, else the turned board would sit half under the HUD with no zoom-out left to bring it back.
func rotate_step(dir: int) -> void:
	yaw_target += 90.0 * signf(dir)
	var fit := fit_distance()
	max_distance = fit
	distance_target = rotated_distance(distance_target, min_distance, fit)
	if distance_target >= fit - 0.0001: _free_pan = false
	focus_target = clamp_focus(focus_target)

## The zoom distance after a turn: untouched, unless it is beyond the new zoom-out limit (the fit for the new
## angle), then that limit.
static func rotated_distance(current: float, min_d: float, new_fit: float) -> float:
	return clampf(current, minf(min_d, new_fit), new_fit)

## Frames the board again for the viewport's size now (the window was resized, the editor's embedded game view
## changed): the fit, the zoom limit and the reference tile follow; the zoom keeps its ratio to the fit.
func refit() -> void:
	if not _initialized: return
	var ratio := distance_target / maxf(0.01, max_distance)
	var fit := fit_distance()
	max_distance = fit
	distance_target = clampf(fit * ratio, min_distance, max_distance)
	distance = distance_target
	apply()
	_measure_reference_tile()

## The board's centre on the ground.
func board_centre() -> Vector3:
	return Vector3(bounds.get_center().x, 0.0, -bounds.get_center().y)

## WorldUi.reference_tile = a tile's on-screen width at the level's default framing (the board centred, unturned,
## at the fit), as Unity measures it once in BoardCamera.Init; never at the current zoom or angle (measured at a
## zoomed-in view, the plates shrank back to their designed size while zoomed in).
func _measure_reference_tile() -> void:
	if not is_inside_tree(): return
	var keep_focus := focus
	var keep_distance := distance
	var keep_yaw := yaw
	var keep_shake := _shake_left
	focus = board_centre()
	yaw = 0.0
	distance = fit_distance(0.0)
	_shake_left = 0.0
	apply()
	WorldUi.reference_tile = WorldUi.tile_width(self, focus)
	focus = keep_focus
	distance = keep_distance
	yaw = keep_yaw
	_shake_left = keep_shake
	apply()

## Glides to centre the point (follow the action, select and show); the player's input cancels it.
func glide(point: Vector3) -> void:
	# a point far outside the board (a view at the origin, a bad frame) would send the camera to a board corner
	# (Eren 2026-10-17: a click sent the screen to the top-left); such a glide is ignored
	if bounds.has_area() and not bounds.grow(2.0).has_point(Vector2(point.x, -point.z)):
		push_warning("[BoardCamera] glide to %s ignored: outside the board" % point)
		return
	_free_pan = false
	focus_target = clamp_focus(Vector3(point.x, 0.0, point.z))
	gliding = true

## Glides to the middle of several world points (nothing for none).
func glide_to(points: Array) -> void:
	if points.is_empty(): return
	var sum := Vector3.ZERO
	for p in points: sum += p
	glide(sum / points.size())

## A short shake (0 = none, 1 = strong), e.g. at an ability's impact. Stronger shakes override weaker ones.
func shake(amount: float) -> void:
	if amount <= 0.0: return
	_shake = maxf(_shake * clampf(_shake_left / SHAKE_TIME, 0.0, 1.0), clampf(amount, 0.0, 1.0))
	_shake_left = SHAKE_TIME

## Whether a world point is on screen, with a margin (fraction of the screen).
func in_view(world: Vector3, margin: float = 0.08) -> bool:
	if is_position_behind(world): return false
	var s := unproject_position(world)
	var size := _view_size()
	return s.x > margin * size.x and s.x < (1.0 - margin) * size.x and s.y > margin * size.y and s.y < (1.0 - margin) * size.y

## The zoom where a world point stands (1 at the default framing), for the overlay.
func zoom_factor(at: Vector3 = Vector3.INF) -> float:
	return WorldUi.zoom(self, focus if at == Vector3.INF else at)

## What the HUD covers at the bottom, in reference pixels: the board is framed and centred above it.
var bottom_inset: float:
	get: return hud_insets.w
	set(v): set_hud_insets(hud_insets.z, v, hud_insets.y)

## Sets what the HUD covers (canvas pixels: top bar, bottom row, right bar) and frames the board again in what is
## left: the default framing and the zoom-out limit follow at once (the current zoom keeps its ratio to the fit).
func set_hud_insets(top: float, bottom: float, right: float) -> void:
	var v := Vector4(hud_insets.x, maxf(0.0, right), maxf(0.0, top), maxf(0.0, bottom))
	if v == hud_insets: return
	hud_insets = v
	if not _initialized: return
	var ratio := distance_target / maxf(0.01, max_distance)
	var fit := fit_distance()
	max_distance = fit
	distance_target = clampf(fit * ratio, min_distance, max_distance)
	distance = distance_target
	apply()
	_measure_reference_tile()

## The part of the screen the HUD leaves free, as fractions (x from the left, y from the TOP), Rect2.
func free_area() -> Rect2:
	var size := _view_size()
	var left := hud_insets.x / maxf(1.0, size.x)
	var right := hud_insets.y / maxf(1.0, size.x)
	var top := hud_insets.z / maxf(1.0, size.y)
	var bottom := hud_insets.w / maxf(1.0, size.y)
	# a gutter round the free area, so the board never touches the HUD's edges
	var gx := GUTTER / maxf(1.0, size.x)
	var gy := GUTTER / maxf(1.0, size.y)
	left += gx
	right += gx
	top += gy
	bottom += gy
	return Rect2(left, top, clampf(1.0 - left - right, 0.2, 1.0), clampf(1.0 - top - bottom, 0.2, 1.0))

## The centre of the free area in canvas pixels, for hints and banners that sit over the board.
func free_centre() -> Vector2:
	var f := free_area()
	var size := _view_size()
	return Vector2(f.get_center().x * size.x, f.get_center().y * size.y)

## The focus limits. Moves the game makes (glides: selection, aiming, follow the action) keep the board whole —
## clamp_strict; the player's own pans (drag with the left or middle button, keys, edge scroll) may move the focus
## up to the board's edge — clamp_to_board. A glide returns to the strict rule.
##
## clamp_strict keeps the focus where the board is never cropped at the default framing: at (or beyond) the fit distance the
## focus stays on the board's centre; zoomed in, it may move away from the centre in proportion to the zoom, up to
## the board's edges at the closest zoom. Selection, aiming and follow-the-action glides go through it too, so
## they pan only as far as the zoom allows (UI/UX review: the board is never cropped by a glide).
func clamp_focus(p: Vector3) -> Vector3:
	if _free_pan: return clamp_to_board(p)
	return clamp_strict(p)

## The player's own pans (drag, keys, edge scroll), at any zoom: the focus — the free area's centre — may go as far
## as the board's edge, so the board can be dragged until its far edge reaches the centre of the free area (at least
## half of it stays in view on each axis), never further (user decision 2026-10-13).
func clamp_to_board(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), 0.0, clampf(p.z, -bounds.end.y, -bounds.position.y))

func clamp_strict(p: Vector3) -> Vector3:
	var centre := Vector3(bounds.get_center().x, 0.0, -bounds.get_center().y)
	var fit := max_distance
	var t := clampf((fit - distance_target) / maxf(0.01, fit - min_distance), 0.0, 1.0)
	var half := Vector3(bounds.size.x * 0.5, 0.0, bounds.size.y * 0.5) * t
	return Vector3(clampf(p.x, centre.x - half.x, centre.x + half.x), 0.0, clampf(p.z, centre.z - half.z, centre.z + half.z))

# ------------------------------------------------------------------ frame

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _wheel += 1.0 * maxf(1.0, event.factor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _wheel -= 1.0 * maxf(1.0, event.factor)

func _process(_delta: float) -> void:
	if not _initialized: return
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _last_ticks) / 1000000.0, 0.0, 0.1)
	_last_ticks = now
	step(dt)

## One frame of input and smoothing (dt unscaled seconds).
func step(dt: float) -> void:
	var ui := _over_ui()
	var vp := get_viewport()
	var mouse := vp.get_mouse_position() if vp != null else Vector2.ZERO
	var size := _view_size()
	var in_window := mouse.x >= 0 and mouse.y >= 0 and mouse.x <= size.x and mouse.y <= size.y

	# pan: keys and screen edges, relative to the camera's yaw
	var move := Vector2.ZERO
	if keys != null:
		if keys.held("CameraUp"): move.y += 1
		if keys.held("CameraDown"): move.y -= 1
		if keys.held("CameraRight"): move.x += 1
		if keys.held("CameraLeft"): move.x -= 1
	if edge_size > 0 and in_window and _drag_anchor == null:
		if mouse.x < edge_size: move.x -= 1
		if mouse.x > size.x - edge_size: move.x += 1
		if mouse.y < edge_size: move.y += 1
		if mouse.y > size.y - edge_size: move.y -= 1
	if move != Vector2.ZERO:
		gliding = false
		_free_pan = true
		var b := Basis(Vector3.UP, deg_to_rad(yaw_target))
		var right := b * Vector3.RIGHT
		var forward := b * Vector3.FORWARD
		var delta := (right * move.x + forward * move.y).normalized() * pan_speed * (distance / 10.0) * dt
		focus_target = clamp_focus(focus_target + delta)

	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var middle := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	# middle-drag: the ground point under the pointer stays under it
	if middle and not _was_middle and not ui:
		_drag_anchor = GridSpace.ground_under(self, mouse)
		_drag_button = MOUSE_BUTTON_MIDDLE
	# left-drag (the setting): a press on the board that moves past the threshold drags the map
	if left and not _was_left:
		_left_dragging = false
		_left_press = null if ui else mouse
	if _left_press != null and not _left_dragging and drag_to_pan and left and _drag_anchor == null \
			and (mouse - _left_press).length() > DRAG_THRESHOLD * size.y / 1080.0:
		var pressed_ground = GridSpace.ground_under(self, _left_press)
		if pressed_ground != null:
			_left_dragging = true
			_drag_anchor = pressed_ground
			_drag_button = MOUSE_BUTTON_LEFT
	if not left: _left_press = null # left_dragged stays true until the next press, so the level skips this release
	if _drag_anchor != null and not Input.is_mouse_button_pressed(_drag_button): _drag_anchor = null
	if _drag_anchor != null:
		var now_ground = GridSpace.ground_under(self, mouse)
		# a step of more than 4 tiles in one frame is a ray grazing the horizon (the pointer near the screen's edge or
		# over the HUD), never a hand movement: dropped instead of throwing the board to a corner
		if now_ground != null and (_drag_anchor - now_ground).length() > 4.0: now_ground = null
		if now_ground != null:
			gliding = false
			_free_pan = true
			focus = clamp_focus(focus + (_drag_anchor - now_ground))
			focus_target = focus
			apply()
	_was_left = left
	_was_middle = middle

	# zoom and rotation
	if _wheel != 0.0 and not ui and in_window:
		var before := distance_target
		distance_target = clampf(distance_target * (1.0 - _wheel * zoom_step), min_distance, max_distance)
		# zooming out after a free pan brings the board back: the focus moves toward the strict limit in step with
		# the zoom, reaching it at the zoom-out limit (QA 2026-10-14: the fit showed half the board off screen after
		# a pan to the edge). Drags and keys still reach the board's edge at any zoom (user decision 2026-10-13).
		if _free_pan and distance_target > before + 0.0001:
			var k_out := clampf((distance_target - before) / maxf(0.0001, max_distance - before), 0.0, 1.0)
			focus_target = focus_target.lerp(clamp_strict(focus_target), k_out)
			if distance_target >= max_distance - 0.0001: _free_pan = false
		# already at the limit (e.g. a turn clamped the zoom to it): zooming out still brings a panned board back
		elif _free_pan and _wheel < 0.0 and distance_target >= max_distance - 0.0001:
			_free_pan = false
			focus_target = clamp_strict(focus_target)
	_wheel = 0.0
	if keys != null:
		if keys.pressed("RotateLeft"): rotate_step(-1)
		if keys.pressed("RotateRight"): rotate_step(1)

	focus_target = clamp_focus(focus_target) # zooming out pulls the focus back so the board stays whole
	var k := 1.0 - exp(-smoothing * dt)
	focus = focus.lerp(focus_target, 1.0 - exp(-glide_speed * dt) if gliding else k)
	if gliding and focus.distance_squared_to(focus_target) < 0.0004: gliding = false
	distance = lerpf(distance, distance_target, k)
	yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), deg_to_rad(yaw_target), k))
	_shake_left = maxf(0.0, _shake_left - dt)
	apply()

## Places the camera from focus, distance, pitch and yaw, and centres the view in the free area.
func apply() -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0))
	var jolt := Vector3.ZERO
	if _shake_left > 0.0:
		jolt = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (_shake * 0.25 * _shake_left / SHAKE_TIME)
	global_transform = Transform3D(b, focus + b.z * distance + jolt)
	# the off-centre projection: the focus lands in the middle of the free area
	projection = Camera3D.PROJECTION_FRUSTUM
	var h := 2.0 * near * tan(deg_to_rad(fov) * 0.5)
	size = h
	var free := free_area()
	var centre_from_bottom := 1.0 - free.get_center().y
	# the near plane spans offset ± h/2: an axis point shows at 0.5 − offset/h of the view from the bottom (left)
	frustum_offset = Vector2((0.5 - free.get_center().x) * h * _aspect(), (0.5 - centre_from_bottom) * h)

## The closest distance at which the whole board (its corners on the ground and a model's height above them) fits
## in the free area at the current pitch and yaw (at_yaw: another yaw, degrees), with the board centred: the
## widest view, whatever the pan is now (measured from the focus, a panned view got a farther zoom-out limit).
func fit_distance(at_yaw: float = INF) -> float:
	var free := free_area()
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var half_w := tan_v * _aspect() * free.size.x
	var half_h := tan_v * free.size.y
	# at the angle the view is turning to (a rotate step sets the limit before the turn has played)
	var y := yaw_target if at_yaw == INF else at_yaw
	var inv := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(y), 0.0)).inverse()
	var centre := board_centre()
	var corners: Array[Vector3] = []
	for i in 8:
		var cx := bounds.position.x if (i & 1) == 0 else bounds.end.x
		var cz := -bounds.position.y if (i & 2) == 0 else -bounds.end.y
		corners.append(Vector3(cx, 0.0 if (i & 4) == 0 else MODEL_HEIGHT, cz) - centre)
	var fits := func(d: float) -> bool:
		for c in corners:
			var v: Vector3 = inv * c + Vector3(0, 0, -d) # camera space, looking down −z
			if -v.z <= 0.01 or absf(v.x / -v.z) > half_w or absf(v.y / -v.z) > half_h: return false
		return true
	var lo := 1.0
	var hi := 1.0
	while not fits.call(hi) and hi < 1000.0: hi *= 2.0
	for i in 30:
		var mid := (lo + hi) * 0.5
		if fits.call(mid): hi = mid
		else: lo = mid
	return hi * 1.03

func _aspect() -> float:
	var s := _view_size()
	return s.x / maxf(1.0, s.y)

func _view_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)

func _over_ui() -> bool:
	if over_ui.is_valid(): return over_ui.call()
	var vp := get_viewport()
	return vp != null and vp.gui_get_hovered_control() != null
