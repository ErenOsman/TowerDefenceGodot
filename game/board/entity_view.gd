class_name EntityView
extends Node3D
## One entity on the board (EntityView.cs): the entity's model (EntityAsset.view → res://art/models/<Unit>.fbx)
## or a placeholder shape in its team colour. Presenters move, flash and animate it through these members only,
## so both look the same to them (Animation & Presentation — Design, Entity views). A model with an
## AnimationPlayer gets an EntityRig (rig); presenters play its clips and fall back to tweens for what it lacks.

const PLAYER_COLOR := Color(0.25, 0.5, 0.95)
const ENEMY_COLOR := Color(0.85, 0.25, 0.25)
const OBJECT_COLOR := Color(0.7, 0.7, 0.75)
const HAZARD_COLOR := Color(1.0, 0.45, 0.1)
const CORPSE_COLOR := Color(0.3, 0.3, 0.3)

## The gap between the body's highest point on screen and its HP bar, in canvas pixels at the default zoom.
const PLATE_GAP_PIXELS := 12.0

## Whether dead units leave a visible corpse; off: the body disappears once it has died (the simulation keeps
## corpses either way).
static var show_corpses: bool = false

## Outline points per model scene (found once per model).
static var _outline_cache := {}

var id: int = -1
var kind: int = 0
var display_name: String = ""
## Presenters currently moving this view; frame syncs leave it alone while above 0.
var animating: int = 0
## The shape or model; presenters move it relative to the root (lunges, hops, shakes).
var body: Node3D = null
## The model's rig; null for placeholders and models without clips.
var rig: EntityRig = null
var is_model: bool = false
var is_dead: bool = false
## A manual plate height above the model's centre in tiles (EntityAsset.plate_offset); 0 = automatic.
var plate_offset: float = 0.0

var height: float = 0.9
var _outline: PackedVector3Array = PackedVector3Array([Vector3.UP])
var _muzzle: Node3D = null
var _meshes: Array = []          # MeshInstance3D of the model (not its Hitbox)
var _flash_material: StandardMaterial3D = null
var _shape_material: StandardMaterial3D = null  # placeholder only
var _base_color: Color = PLAYER_COLOR
var _status_vfx := {}            # key → Node3D
var _team: int = -1

# ------------------------------------------------------------------ creation

## The entity's model when it has one (scene), else a placeholder. Added under parent.
static func create(parent: Node3D, f: EntityFrame, scene: PackedScene) -> EntityView:
	var view := EntityView.new()
	view.name = "%s #%d" % [f.name, f.id]
	view.id = f.id
	view.kind = f.kind
	view.display_name = f.name
	parent.add_child(view)
	if scene != null: view._build_model(scene)
	else: view._build_placeholder(f.kind)
	view.set_team(f)
	view.place(f.pos)
	view.face(f.facing)
	return view

func _build_placeholder(k: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Placeholder"
	var radius := 0.275
	match k:
		EntityKind.Object_:
			var box := BoxMesh.new()
			box.size = Vector3(0.7, 0.7, 0.7)
			mi.mesh = box
			height = 0.7
			radius = 0.35
			mi.position = Vector3.UP * 0.35
		EntityKind.Hazard:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.45
			cyl.bottom_radius = 0.45
			cyl.height = 0.02
			mi.mesh = cyl
			height = 0.02
			radius = 0.45
			mi.position = Vector3.UP * 0.01
		_:
			var cap := CapsuleMesh.new()
			cap.radius = 0.275
			cap.height = 0.9
			mi.mesh = cap
			height = 0.9
			mi.position = Vector3.UP * 0.45
	_shape_material = StandardMaterial3D.new()
	_shape_material.roughness = 0.8
	mi.material_override = _shape_material
	add_child(mi)
	body = mi
	_meshes = [mi]
	_outline = _ring(Vector3.UP * height, radius)

func _build_model(scene: PackedScene) -> void:
	is_model = true
	var model: Node3D = scene.instantiate()
	add_child(model)
	body = model
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player != null and player.get_animation_list().size() > 0: rig = EntityRig.new(player)
	var hitbox: Node3D = null
	for n in _all_children(model):
		if n is MeshInstance3D:
			if String(n.name).to_lower() == "hitbox":
				hitbox = n
				n.visible = false
			else: _meshes.append(n)
		elif String(n.name) == "Muzzle" and n is Node3D:
			_muzzle = n   # the deepest one wins (a bone attachment holding a Muzzle node)
	var key := scene.resource_path
	if _outline_cache.has(key):
		_outline = _outline_cache[key]
	else:
		_outline = _find_outline(hitbox)
		if key != "": _outline_cache[key] = _outline
	height = 0.3
	for p in _outline: height = maxf(height, p.y)

static func _all_children(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out

const OUTLINE_SLOPES := [40.0, 55.0, 70.0] # camera slopes covered (degrees below the horizon at the unit)

## The model's outline as the bar sees it, in this view's local space: a Hitbox's top corners when it has one, else
## the highest mesh point and, for 8 directions and three camera slopes, the point rising highest on screen.
func _find_outline(hitbox: Node3D) -> PackedVector3Array:
	if not is_inside_tree(): return _ring(Vector3.UP * height, 0.25)
	var to_local := global_transform.affine_inverse()
	if hitbox != null and hitbox is MeshInstance3D:
		var box: AABB = hitbox.get_aabb()
		var corners := PackedVector3Array()
		var world := AABB()
		for i in 8:
			var c: Vector3 = to_local * (hitbox.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)))
			world = AABB(c, Vector3.ZERO) if i == 0 else world.expand(c)
		for k in 4:
			corners.append(Vector3(world.position.x if (k & 1) == 0 else world.end.x, world.end.y, world.position.z if (k & 2) == 0 else world.end.z))
		return corners
	var points := PackedVector3Array()
	for mi in _meshes:
		var mesh: Mesh = mi.mesh
		if mesh == null: continue
		var xf: Transform3D = to_local * mi.global_transform
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var step := maxi(1, verts.size() / 800)
			var i := 0
			while i < verts.size():
				points.append(xf * verts[i])
				i += step
	if points.is_empty(): return _ring(Vector3.UP * height, 0.2)
	var kept := {}
	var top := points[0]
	for v in points:
		if v.y > top.y: top = v
	kept[top] = true
	for d in 8:
		var angle := d * PI / 4.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		for slope in OUTLINE_SLOPES:
			var up := cos(deg_to_rad(slope))
			var back := sin(deg_to_rad(slope))
			var best := points[0]
			var best_score := -INF
			for v in points:
				var score := v.y * up + (v.x * dir.x + v.z * dir.z) * back
				if score > best_score:
					best_score = score
					best = v
			kept[best] = true
	return PackedVector3Array(kept.keys())

static func _ring(top: Vector3, radius: float) -> PackedVector3Array:
	var ring := PackedVector3Array([top])
	for k in 8: ring.append(top + Vector3(cos(k * PI / 4.0), 0.0, sin(k * PI / 4.0)) * radius)
	return ring

# ------------------------------------------------------------------ positions for the overlay and presenters

## Where it stands in the world (its position under the board's origin when not in a tree, e.g. in tests).
var world_position: Vector3:
	get: return global_position if is_inside_tree() else position

## A point just over the head in the world (floating text starts here).
var head_position: Vector3:
	get: return world_position + Vector3.UP * (height + 0.35)

## Where its projectiles start: the model's "Muzzle" node when it has one, else two thirds of the way up.
var muzzle_position: Vector3:
	get: return _muzzle.global_position if _muzzle != null and _muzzle.is_inside_tree() else world_position + Vector3.UP * maxf(0.6, height * 0.65)

## Where the overlay draws the HP bar and markers, in canvas pixels (x, y; z > 0 when in front of the camera):
## x on the model's centre as seen on screen, y PLATE_GAP_PIXELS (scaled with the zoom) above the body's highest
## point on screen. A manual plate offset instead raises it that many tiles over the centre, measured straight up.
func plate_screen_position(cam: Camera3D) -> Vector3:
	if cam == null or not cam.is_inside_tree() or not is_inside_tree(): return Vector3(0, 0, -1)
	var centre := global_position + Vector3.UP * (height * 0.5)
	if cam.is_position_behind(centre): return Vector3(0, 0, -1)
	var at := cam.unproject_position(centre)
	if plate_offset > 0.0:
		var above := cam.unproject_position(centre + Vector3.UP * plate_offset)
		return Vector3(at.x, at.y - absf(above.y - at.y), 1.0)
	var highest := at.y
	var xf := global_transform
	for p in _outline:
		var w := xf * p
		if cam.is_position_behind(w): continue
		highest = minf(highest, cam.unproject_position(w).y)
	var gap := PLATE_GAP_PIXELS * WorldUi.readable(WorldUi.zoom(cam, global_position))
	return Vector3(at.x, highest - gap, 1.0)

# ------------------------------------------------------------------ what presenters and syncs call

## Team colour for placeholders; models keep their own colours.
func set_team(f: EntityFrame) -> void:
	_team = f.team
	if f.kind == EntityKind.Hazard: _base_color = HAZARD_COLOR
	elif f.kind == EntityKind.Object_: _base_color = OBJECT_COLOR
	elif f.team == Teams.Player: _base_color = PLAYER_COLOR
	else: _base_color = ENEMY_COLOR
	if not is_model and not is_dead: _tint(_base_color)

func place(p: Vector2i) -> void:
	position = GridSpace.to_world(p)

func face(d: Vector2i) -> void:
	if d != Vector2i.ZERO: rotation.y = GridSpace.facing_yaw(d)

## Turns toward a world point on the ground plane (nothing when it stands on it).
func face_point(point: Vector3) -> void:
	var yaw = GridSpace.look_yaw(world_position, point)
	if yaw != null: rotation.y = yaw

## Blends toward a flash colour (t = 1: full flash, 0: the normal look).
func flash(c: Color, t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	if not is_model:
		_tint(_base_color.lerp(c, t))
		return
	if t <= 0.001:
		for mi in _meshes:
			if is_instance_valid(mi): mi.material_overlay = null
		return
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(c.r, c.g, c.b, t * 0.7)
	for mi in _meshes:
		if is_instance_valid(mi): mi.material_overlay = _flash_material

## The corpse, left on its tile for corpse-targeting abilities: a model's Die pose, or grey and flat; hidden
## unless show_corpses.
func show_corpse() -> void:
	if is_dead: return
	is_dead = true
	set_status_vfx({}, Callable())
	if not show_corpses:
		if body != null: body.visible = false
		return
	if rig != null and rig.show_dead(): return
	scale = Vector3(1.0, 0.25, 1.0)
	if not is_model: _tint(CORPSE_COLOR)

## Back from a corpse (resurrection), or making sure a living view looks alive.
func show_alive() -> void:
	if not is_dead: return
	is_dead = false
	if body != null: body.visible = true
	scale = Vector3.ONE
	if rig != null: rig.to_rest()
	if not is_model: _tint(_base_color)

## Keeps one effect per status that has a loop VFX: new ones start, ended ones stop. wanted: key → effect name;
## make_loop(name) → Node3D (or null). An empty wanted clears them.
func set_status_vfx(wanted: Dictionary, make_loop: Callable) -> void:
	for k in _status_vfx.keys():
		if not wanted.has(k):
			if is_instance_valid(_status_vfx[k]): _status_vfx[k].queue_free()
			_status_vfx.erase(k)
	if not make_loop.is_valid(): return
	for k in wanted:
		if _status_vfx.has(k): continue
		var loop: Node3D = make_loop.call(wanted[k])
		if loop == null: continue
		# the kit's status loops are built around the middle of a unit about 0.8 tall: scaled to this unit's height
		# (not below 0.6) and rooted at 0.4 × that scale, so ground rings stay on the ground
		var s := clampf(height / 0.8, 0.6, 1.6)
		add_child(loop)
		loop.position = Vector3.UP * (0.4 * s)
		loop.scale = Vector3.ONE * s
		VfxKit.start(loop) # placed at the feet first, then emitting
		_status_vfx[k] = loop

## The status loops showing (tests).
var status_vfx_count: int:
	get: return _status_vfx.size()

func _tint(c: Color) -> void:
	if _shape_material != null: _shape_material.albedo_color = c
