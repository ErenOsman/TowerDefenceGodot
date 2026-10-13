class_name TdDiorama
extends Control
## The menus' 3D backdrop (hud-menu-spec §4/§5, the Unity build's main menu / Welcome / loading): a level's board
## (BoardView from the map kit, with its bases) rendered small in its own world, blurred and darkened by a shader
## (depth of field), and — sharp, in front — miniatures (unit models on their plinths) in a transparent layer.
## The last blurred board drawn is kept (snapshot) so the loading screen can show it without building a board.
##   var d := TdDiorama.new(); d.level = TdMenu.app().catalog.find_level("chapter1-1"); add_child(d)
##   d.add_mini("Assets/Art/Models/Archer/Archer Blender.prefab", Vector2(1100, 980), 250.0, 20.0)

const BLUR_SHADER := """
shader_type canvas_item;
uniform float blur = 2.0;
uniform float dim : hint_range(0.0, 1.0) = 0.45;
uniform vec4 tint : source_color = vec4(0.09, 0.067, 0.05, 1.0);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	vec4 c = texture(TEXTURE, UV) * 0.2;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.1;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.1;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.1;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.1;
	c += texture(TEXTURE, UV + px) * 0.1;
	c += texture(TEXTURE, UV - px) * 0.1;
	c += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.1;
	c += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.1;
	COLOR = vec4(mix(c.rgb, tint.rgb, dim), 1.0);
}
"""

## The last board drawn (unblurred, small), for screens that show the backdrop without building it.
static var snapshot: Texture2D = null

## The level whose board is shown (null: the catalog's first level).
var level: LevelAsset = null
## Blur radius in texels of the small render, and how much it is darkened toward wood.900.
var blur := 1.6
var dim := 0.55
## The board render's size divisor (3: a third of the screen; cheap and soft).
var shrink := 3
## Where the board's centre sits on screen (0.5, 0.5 = centred) and how much of the width it fills.
var focus := Vector2(0.5, 0.52)
var fill := 0.95
## Camera pitch (degrees below the horizon).
var pitch := 52.0
## Off: no board is built; the snapshot (or nothing) is shown.
var build_board := true

var _board_box: SubViewportContainer
var _board_vp: SubViewport
var _board_cam: Camera3D
var _snap_rect: TextureRect
var _minis_box: SubViewportContainer
var _minis_vp: SubViewport
var _minis_cam: Camera3D
var _minis_root: Node3D
var _minis: Array = []       # {node, screen, height, yaw}
var _frames := 0
var _grid_size := Vector2i(10, 6)

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	mat.shader = sh
	mat.set_shader_parameter("blur", blur)
	mat.set_shader_parameter("dim", dim)
	mat.set_shader_parameter("tint", TdTheme.color("wood.900"))
	if build_board:
		_board_box = SubViewportContainer.new()
		_board_box.stretch = true
		_board_box.stretch_shrink = shrink
		_board_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_board_box.mouse_filter = MOUSE_FILTER_IGNORE
		_board_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_board_box.material = mat
		add_child(_board_box)
		_board_vp = SubViewport.new()
		_board_vp.own_world_3d = true
		_board_vp.msaa_3d = Viewport.MSAA_DISABLED
		_board_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_board_box.add_child(_board_vp)
		_build_board_world()
	else:
		_snap_rect = TextureRect.new()
		_snap_rect.texture = snapshot
		_snap_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_snap_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_snap_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_snap_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_snap_rect.material = mat
		_snap_rect.mouse_filter = MOUSE_FILTER_IGNORE
		_snap_rect.visible = snapshot != null
		add_child(_snap_rect)
	resized.connect(_layout)

## Whether there is a snapshot to show (build_board off).
static func has_snapshot() -> bool:
	return snapshot != null

func _build_board_world() -> void:
	var lv := level
	if lv == null and TdMenu.app().catalog != null:
		var e: Array = TdMenu.app().catalog.entries()
		if not e.is_empty(): lv = e[0][0].level
	var root := Node3D.new()
	_board_vp.add_child(root)
	_add_light(root, Color(0.13, 0.11, 0.1))
	_board_cam = Camera3D.new()
	_board_cam.fov = 40.0
	root.add_child(_board_cam)
	_board_cam.current = true
	if lv == null: return
	var def: LevelDef = TdMenu.app().convert.level(lv)
	if def == null: return
	var grid := def.build_grid()
	_grid_size = Vector2i(grid.width, grid.height)
	var board := BoardView.new()
	root.add_child(board)
	var kit: Array = TdMenu.app().lib.rules.tiles if TdMenu.app().lib.rules != null else []
	board.build(grid, lv, kit, func(p): return TdMenu.app().model_scene(p))
	for b in lv.bases:
		if b == null or b.entity == null: continue
		var sc: PackedScene = TdMenu.app().model_scene(b.entity.view)
		if sc == null: continue
		var m: Node3D = sc.instantiate()
		m.position = GridSpace.to_world(b.tile)
		root.add_child(m)
		_idle(m)
	_place_board_camera()

static func _add_light(root: Node3D, bg: Color, transparent := false) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = not transparent
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	root.add_child(sun)

## Plays a model's Idle clip (looping) when it has one.
static func _idle(model: Node) -> void:
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player == null: return
	for n in player.get_animation_list():
		if String(n).ends_with("|Idle"):
			var a := player.get_animation(n)
			if a != null: a.loop_mode = Animation.LOOP_LINEAR
			player.play(n)
			return

func _place_board_camera() -> void:
	if _board_cam == null: return
	var c := Vector3((_grid_size.x - 1) / 2.0, 0.0, -(_grid_size.y - 1) / 2.0)
	var aspect := size.x / maxf(size.y, 1.0) if size.y > 0 else 16.0 / 9.0
	var hfov := 2.0 * atan(tan(deg_to_rad(_board_cam.fov) * 0.5) * aspect)
	var width := float(_grid_size.x) + 1.0
	var dist := (width / fill) * 0.5 / tan(hfov * 0.5) + float(_grid_size.y) * 0.25
	var p := deg_to_rad(pitch)
	_board_cam.position = c + Vector3(0, sin(p), cos(p)) * dist
	_board_cam.look_at(c, Vector3.UP)
	# shift the board on screen: a camera offset of the focus away from the centre
	var view_h := 2.0 * dist * tan(deg_to_rad(_board_cam.fov) * 0.5)
	_board_cam.h_offset = -(focus.x - 0.5) * view_h * aspect
	_board_cam.v_offset = (focus.y - 0.5) * view_h

# ------------------------------------------------------------------ miniatures

## Adds a miniature (a unit model on its plinth) standing with its feet at a screen point (reference px), about
## `height` px tall, turned `yaw` degrees (0 faces the viewer). A negative x or y counts from the right / bottom edge.
func add_mini(view_path: String, screen: Vector2, height: float, yaw := 0.0) -> void:
	var sc: PackedScene = TdMenu.app().model_scene(view_path)
	if sc == null: return
	if _minis_vp == null: _build_minis()
	var m: Node3D = sc.instantiate()
	_minis_root.add_child(m)
	_idle(m)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).to_lower() == "hitbox": n.visible = false
	_minis.append({"node": m, "screen": screen, "height": height, "yaw": yaw})
	_layout()

func _build_minis() -> void:
	_minis_box = SubViewportContainer.new()
	_minis_box.stretch = true
	_minis_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_minis_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_minis_box)
	_minis_vp = SubViewport.new()
	_minis_vp.own_world_3d = true
	_minis_vp.transparent_bg = true
	_minis_vp.msaa_3d = Viewport.MSAA_2X
	_minis_box.add_child(_minis_vp)
	_minis_root = Node3D.new()
	_minis_vp.add_child(_minis_root)
	_add_light(_minis_root, Color(0, 0, 0, 0), true)
	_minis_cam = Camera3D.new()
	_minis_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_minis_cam.size = 10.0
	_minis_cam.rotation_degrees = Vector3(-14.0, 0, 0)
	_minis_cam.position = Vector3(0, 0, 0)
	_minis_cam.far = 60.0
	_minis_root.add_child(_minis_cam)
	_minis_cam.current = true

func _layout() -> void:
	_place_board_camera()
	if _minis_cam == null or size.y <= 0: return
	# ortho: size = world units over the viewport's height; 1 reference px = size / height units
	var units_per_px := _minis_cam.size / size.y
	for d in _minis:
		var m: Node3D = d.node
		var s: float = d.height * units_per_px / 0.95 # a unit model with its plinth is about 0.95 units tall
		m.scale = Vector3.ONE * s
		m.rotation_degrees = Vector3(0, d.yaw, 0)
		var pt: Vector2 = d.screen
		if pt.x < 0.0: pt.x += size.x # negative x: from the right edge
		if pt.y < 0.0: pt.y += size.y
		# where the feet go: on the camera ray through the screen point (orthographic: depth does not move it)
		m.position = _minis_cam.project_ray_origin(pt) + _minis_cam.project_ray_normal(pt) * 20.0

func _process(_delta: float) -> void:
	# keep a small copy of the board once it has drawn (for the loading screen)
	if _board_vp == null or _frames > 12: return
	_frames += 1
	if _frames == 12:
		var img := _board_vp.get_texture().get_image()
		if img != null and not img.is_empty(): snapshot = ImageTexture.create_from_image(img)
