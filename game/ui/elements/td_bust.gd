class_name TdBust
extends RefCounted
## Visual-novel busts rendered from a unit model (UI Design Rules, Dialogue: a bust about 560 tall on the dialogue
## box's edge; Eren 2026-10-15: the Princess is never drawn on the board, she is this bust). The model is posed in
## its Idle, framed head and shoulders to the waist, turned ~25° toward the text (screen right; the box mirrors it
## on the right edge), rendered ONCE into a transparent SubViewport (the whole figure, then the bust cut from the drawn pixels) and kept for the session. A soft drop shadow
## (the bust's silhouette, blurred) is made from any portrait texture for the box to draw under it.
##   bust(model, host) → Texture2D or null (null while rendering — pending(model) — or when the model is missing /
##   the build has no renderer: the caller falls back to the portrait image); shadow_of(texture) → Texture2D.

const PRINCESS := "res://art/models/Princess.fbx"
## The full-figure render size (px); the bust cut from it is kept at most BUST_PX tall (~1.3× the 560 px shown at 1080).
const SIZE := Vector2i(1024, 1280)
const BUST_PX := 720
## Head and shoulders to the waist: the part of the drawn figure kept (from the top; the chibi head is half of it).
const SHOWN := 0.8
const YAW_DEG := 25.0

static var _done := {}      # model path → Texture2D (null: failed, use the fallback)
static var _pending := {}   # model path → true while its render runs
static var _shadows := {}   # texture instance id → shadow texture

## The model's bust if rendered this session; the first call starts the render (a SubViewport under the scene tree
## root, freed after) and returns null until it is ready a few frames later.
static func bust(model: String, host: Node) -> Texture2D:
	if _done.has(model): return _done[model]
	if not _pending.has(model) and host != null and host.is_inside_tree():
		_pending[model] = true
		_render(model, host.get_tree())
	return null

static func pending(model: String) -> bool:
	return _pending.has(model)

static func _render(model: String, tree: SceneTree) -> void:
	var scene: PackedScene = load(model) if ResourceLoader.exists(model) else null
	if scene == null or DisplayServer.get_name() == "headless":
		_finish(model, null)
		return
	var vp := SubViewport.new()
	vp.name = "BustRender"
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.97, 0.94)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.75
	key.light_color = Color(1.0, 0.98, 0.94)
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.2
	fill.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	vp.add_child(fill)
	var unit: Node3D = scene.instantiate()
	unit.rotation_degrees.y = YAW_DEG # the model's front is +Z (toward the camera); + turns it to screen right
	vp.add_child(unit)
	var player: AnimationPlayer = unit.find_child("AnimationPlayer", true, false)
	if player != null:
		for a in player.get_animation_list():
			if String(a).ends_with("Idle"):
				player.play(a)
				player.seek(0.0, true)
				player.pause()
				break
	var cam := Camera3D.new()
	cam.fov = 16.0
	vp.add_child(cam)
	tree.root.add_child.call_deferred(vp)
	await tree.process_frame
	await tree.process_frame
	# the whole figure first (the mesh bounds of a skinned FBX are only a guess: back off until nothing touches the
	# image's edge), then the bust is cut from the pixels actually drawn
	var box := _bounds(unit)
	var mid := box.get_center()
	var h := box.size.y * 1.3
	var img: Image = null
	for attempt in 4:
		var dist := h * 0.5 / tan(deg_to_rad(cam.fov * 0.5))
		cam.position = mid + Vector3(0.0, h * 0.08, dist)
		cam.look_at(mid, Vector3.UP)
		for i in 3: await RenderingServer.frame_post_draw
		img = vp.get_texture().get_image() if is_instance_valid(vp) else null
		if img == null or img.is_empty(): break
		var used := img.get_used_rect()
		if used.size.y >= 8 and used.position.y > 2 and used.end.y < img.get_height() - 2 and used.position.x > 2 and used.end.x < img.get_width() - 2: break
		h *= 1.8
	if is_instance_valid(vp): vp.queue_free()
	if img == null or img.is_empty() or img.get_used_rect().size.y < 8:
		_finish(model, null)
		return
	img.convert(Image.FORMAT_RGBA8)
	_finish(model, ImageTexture.create_from_image(_crop_bust(img)))

## Head and shoulders to the waist from a full-figure render: the top SHOWN of the drawn figure, a little air over
## the head, the width kept at 0.8 of the height round the figure's middle (transparent where it runs past).
static func _crop_bust(img: Image) -> Image:
	var used := img.get_used_rect()
	var bh := int(used.size.y * SHOWN)
	var pad := int(bh * 0.04)
	var ch := bh + pad
	var cw := int(ch * 0.8)
	var cx := used.position.x + used.size.x / 2
	var out := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(cx - cw / 2, used.position.y, cw, bh), Vector2i(0, pad))
	if ch > BUST_PX: out.resize(int(BUST_PX * 0.8), BUST_PX, Image.INTERPOLATE_LANCZOS)
	out.generate_mipmaps()
	return out

static func _finish(model: String, tex: Texture2D) -> void:
	_done[model] = tex
	_pending.erase(model)

## The model's bounds (its meshes, model space after its own turn ignored: the AABB of every mesh in world space).
static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out if not first else AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1.6, 1))

## A soft shadow of a portrait: its silhouette in black, blurred (cached per texture). null when it has no image.
static func shadow_of(tex: Texture2D) -> Texture2D:
	if tex == null: return null
	var id := tex.get_instance_id()
	if _shadows.has(id): return _shadows[id]
	var img := tex.get_image()
	var out: Texture2D = null
	if img != null and not img.is_empty():
		img = img.duplicate()
		if img.is_compressed(): img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		img.adjust_bcs(0.0, 1.0, 1.0) # black, the alpha kept
		img.resize(maxi(1, w / 10), maxi(1, h / 10), Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_CUBIC)
		out = ImageTexture.create_from_image(img)
	_shadows[id] = out
	return out
