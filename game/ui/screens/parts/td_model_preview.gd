class_name TdModelPreview
extends SubViewportContainer
## A unit's model turning slowly in a UI frame (CodexModelPreview.cs): its own small world (a SubViewport with its
## own World3D, a key and a fill light, a flat ambient), the model playing Idle, swaying around a three-quarter
## front view on unscaled time (so it moves over a paused game too); drag left / right to turn it.
##   var p := TdModelPreview.new(); p.custom_minimum_size = Vector2(275, 300); add_child(p); p.show_model(scene)

## The model faces this camera at yaw 0: 30 degrees shows a 3/4 front view. It sways ±SWAY degrees around its
## facing (so the front stays in view) instead of spinning all the way round; a drag turns it freely.
const START_YAW := 30.0
const SWAY := 40.0

@export var spin_speed := 12.0
@export var drag_speed := 0.5
@export var camera_pitch := 18.0
@export var field_of_view := 30.0

var _vp: SubViewport
var _root: Node3D
var _pivot: Node3D
var _cam: Camera3D
var _model: Node3D
var _yaw := START_YAW
var _t := 0.0
var _dragging := false
var _height := 1.0

func _init() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_DRAG

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.64)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = 0.9
	key.rotation_degrees = Vector3(-35, -30, 0)
	_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, 140, 0)
	_root.add_child(fill)
	_pivot = Node3D.new()
	_root.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = field_of_view
	_root.add_child(_cam)
	_cam.current = true
	resized.connect(_frame)

## Shows a model scene (null: nothing).
func show_model(scene: PackedScene) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if scene == null: return
	_model = scene.instantiate()
	_pivot.add_child(_model)
	TdDiorama._idle(_model)
	_height = 1.0
	var aabb := AABB()
	var first := true
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if String(mi.name).to_lower() == "hitbox":
			mi.visible = false
			continue
		var box: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if not first: _height = clampf(aabb.end.y, 0.5, 4.0)
	_yaw = START_YAW
	_t = 0.0
	_frame()

func clear() -> void:
	show_model(null)

func _frame() -> void:
	if _cam == null: return
	var aspect := size.x / maxf(size.y, 1.0)
	var h := _height * 1.25
	var vfov := deg_to_rad(field_of_view)
	var dist := (h * 0.5) / tan(vfov * 0.5)
	if aspect < 1.0: dist /= maxf(aspect, 0.5)
	var target := Vector3(0, _height * 0.46, 0)
	var p := deg_to_rad(camera_pitch)
	_cam.position = target + Vector3(0, sin(p), cos(p)) * dist
	_cam.look_at(target, Vector3.UP)

func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree(): return
	if not _dragging: _t += TdTheme.unscaled(delta) * spin_speed / 40.0
	_pivot.rotation_degrees.y = _yaw + SWAY * sin(_t)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * drag_speed
		accept_event()
