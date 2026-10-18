class_name VfxKit
extends RefCounted
## The VFX kit (~/vfx: 43 effects, Unity Shuriken specs in effects.json, a copy here) approximated with
## CPUParticles3D (GL Compatibility; no GPU particles): one emitter per layer, textured billboards of the kit's
## paper cut-out sprites, colour and size over life from the spec's gradient and grow curve. Bursts free
## themselves; loops (status, trails) are returned for the caller to parent. Effects run on scaled time like the
## game (CPUParticles3D follows Engine.time_scale). Content names effects as "vfx/<name>"
## ("vfx/Hit Spark"; the old Unity "Assets/Art/VFX/Kit/Hit Spark.prefab" too); effect_name() maps either to "Hit Spark". What is not approximated:
## noise (turbulence), stretched billboards (drawn as plain billboards) and sorting fudges.

const SPEC := "res://game/level/vfx/effects.json"
const SPRITES := "res://game/level/vfx/sprites/%s.png"

static var _effects := {}       # name → Dictionary
static var _palette := {}
static var _loaded := false
static var _materials := {}     # "sprite|blend|orient" → material
static var _meshes := {}        # orient → QuadMesh
## Turn effects off (headless tests).
static var enabled := true

static func _load() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(SPEC): return
	var j = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	if not (j is Dictionary): return
	_palette = j.get("palette", {})
	for e in j.get("effects", []): _effects[e.name] = e

## The effect name of a content reference ("vfx/Hit Spark", or the old Unity prefab path
## "Assets/Art/VFX/Kit/Hit Spark.prefab" → "Hit Spark"); "" for none.
static func effect_name(ref) -> String:
	if ref == null: return ""
	var s := str(ref).strip_edges()
	if s == "": return ""
	return s.get_file().get_basename()

## Whether the kit has an effect by this name.
static func has_effect(n: String) -> bool:
	_load()
	return _effects.has(n)

## Every effect name (tests).
static func names() -> Array:
	_load()
	return _effects.keys()

## The fewest effects whose layers use every material variant of the kit (blend × orient): what the Boot pre-warm
## plays once so their shaders compile at Boot, not on the first hit.
static func warm_set() -> Array:
	_load()
	var seen := {}
	var out := []
	for n in _effects:
		var add := false
		for l in _effects[n].get("layers", []):
			var k := "%s|%s" % [str(l.get("blend", "alpha")), str(l.get("orient", "billboard"))]
			if not seen.has(k):
				seen[k] = true
				add = true
		if add: out.append(n)
	return out

## Every sprite texture the kit's layers use (res:// paths that exist): the Boot preloads them.
static func sprite_paths() -> Array[String]:
	_load()
	var out: Array[String] = []
	for n in _effects:
		for l in _effects[n].get("layers", []):
			var p := SPRITES % str(l.get("sprite", ""))
			if not out.has(p) and ResourceLoader.exists(p): out.append(p)
	return out

static func _color(n) -> Color:
	if n == null: return Color.WHITE
	var s := str(n)
	if _palette.has(s): return Color.html(str(_palette[s]))
	if s.begins_with("#"): return Color.html(s)
	if s.length() == 6 and s.is_valid_hex_number(): return Color.html(s)
	return Color.WHITE

## Spawns a burst effect at a world point under parent; it frees itself after lifetime seconds (game time).
## Returns the effect node, or null (no such effect, or effects off).
static func spawn(n: String, at: Vector3, parent: Node, lifetime: float = 2.0) -> Node3D:
	if parent == null or not parent.is_inside_tree(): return null
	var fx := build(n)
	if fx == null: return null
	parent.add_child(fx)
	fx.global_position = at
	start(fx) # only now, placed in the tree: world-space particles are born where the effect is
	var life := maxf(lifetime, float(fx.get_meta("duration", 1.0)))
	var timer := parent.get_tree().create_timer(life, false, false, false) # scaled time: freezes on pause
	# the timer outlives the level when it is left mid-effect: capture the id, not the node (a freed capture made
	# Godot print "Lambda capture at index 0 was freed" on every level exit within an effect's life; QA 2026-10-14)
	var fx_id := fx.get_instance_id()
	timer.timeout.connect(func():
		var node := instance_from_id(fx_id) as Node
		if node != null: node.queue_free())
	return fx

## A loop effect (status, trail) for the caller to parent; null when the kit has none by that name. It does not
## emit yet: call start(fx) once it is in the tree and placed.
static func loop(n: String) -> Node3D:
	return build(n)

## Starts an effect's emitters (after it has been added to the tree and placed): each layer restarts, a delayed
## burst after its delay (game time).
static func start(fx: Node3D) -> void:
	if fx == null or not fx.is_inside_tree(): return
	for p in fx.get_children():
		if not (p is CPUParticles3D): continue
		var delay := float(p.get_meta("delay", 0.0))
		if delay > 0.0:
			var t := fx.get_tree().create_timer(delay, false, false, false)
			var p_id := p.get_instance_id()
			t.timeout.connect(func():
				var layer := instance_from_id(p_id) as CPUParticles3D
				if layer != null: layer.restart())
		else:
			p.restart()

## The effect's node: one CPUParticles3D per layer under a Node3D. Null when unknown or effects are off.
static func build(n: String) -> Node3D:
	if not enabled or n == "": return null
	_load()
	if not _effects.has(n): return null
	var e: Dictionary = _effects[n]
	var root := Node3D.new()
	root.name = n
	var is_loop: bool = e.get("kind", "burst") != "burst"
	var longest := 0.0
	for l in e.get("layers", []):
		var p := _layer(l, is_loop)
		root.add_child(p)
		longest = maxf(longest, float(l.get("delay", 0.0)) + float(l.life[1]))
	root.set_meta("duration", longest + 0.1)
	root.set_meta("loop", is_loop)
	return root

static func _layer(l: Dictionary, is_loop: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = str(l.sprite)
	var off: Array = l.get("offset", [0, 0, 0])
	p.position = Vector3(off[0], off[1], -float(off[2]))
	var count = l.get("count")
	var burst: bool = count != null and count[1] > 0
	var life: Array = l.life
	p.lifetime = maxf(0.05, float(life[1]))
	p.lifetime_randomness = clampf(1.0 - float(life[0]) / maxf(0.001, float(life[1])), 0.0, 1.0)
	if burst:
		p.amount = maxi(1, randi_range(int(count[0]), int(count[1])))
		p.one_shot = true
		p.explosiveness = 1.0
	else:
		p.amount = maxi(1, ceili(float(l.get("rate", 1.0)) * float(life[1])) + 1)
		p.one_shot = false
		p.explosiveness = 0.0
	p.local_coords = bool(l.get("local", false))
	var speed: Array = l.speed
	p.initial_velocity_min = float(speed[0])
	p.initial_velocity_max = float(speed[1])
	var size: Array = l.size
	p.scale_amount_min = float(size[0])
	p.scale_amount_max = float(size[1])
	var rot: Array = l.get("rot", [0, 0])
	p.angle_min = float(rot[0])
	p.angle_max = float(rot[1])
	var spin: Array = l.get("spin", [0, 0])
	p.angular_velocity_min = float(spin[0])
	p.angular_velocity_max = float(spin[1])
	p.gravity = Vector3(0, -9.81 * float(l.get("gravity", 0.0)), 0)
	var drag := float(l.get("drag", 0.0))
	if drag > 0.0:
		var avg := (float(speed[0]) + float(speed[1])) * 0.5
		p.damping_min = drag * avg * 0.5
		p.damping_max = drag * avg * 0.7
	_shape(p, l.get("shape", {"type": "point"}))
	# colour and alpha over life
	var g := Gradient.new()
	var c0 := _color(l.color[0])
	var c1 := _color(l.color[1])
	var alpha_keys: Array
	match str(l.get("alpha", "cut")):
		"fade": alpha_keys = [[0.0, 1.0], [1.0, 0.0]]
		"flash": alpha_keys = [[0.0, 1.0], [0.3, 1.0], [1.0, 0.0]]
		"inout": alpha_keys = [[0.0, 0.0], [0.2, 1.0], [0.7, 1.0], [1.0, 0.0]]
		_: alpha_keys = [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]]
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for k in alpha_keys:
		offsets.append(k[0])
		var c := c0.lerp(c1, k[0])
		c.a = k[1]
		colors.append(c)
	g.offsets = offsets
	g.colors = colors
	p.color_ramp = g
	if l.get("color2") != null:
		var gi := Gradient.new()
		gi.offsets = PackedFloat32Array([0.0, 1.0])
		gi.colors = PackedColorArray([Color.WHITE, _color(l.color2)])
		p.color_initial_ramp = gi
	p.scale_amount_curve = _size_curve(str(l.get("grow", "shrink")), float(l.get("stretch", 0.0)))
	var orient := str(l.get("orient", "billboard"))
	var add := str(l.get("blend", "alpha")) == "add"
	p.mesh = _mesh(orient)
	p.material_override = _material(str(l.sprite), add, orient)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# never emitting until start(): a world-space emitter that starts before its effect is placed spawns its first
	# particles at the world origin
	p.emitting = false
	var delay := float(l.get("delay", 0.0))
	if delay > 0.0 and burst: p.set_meta("delay", delay)
	return p

static func _shape(p: CPUParticles3D, sh: Dictionary) -> void:
	var t := str(sh.get("type", "point"))
	p.direction = Vector3.UP
	p.spread = 0.0
	match t:
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = maxf(0.001, float(sh.get("radius", 0.15)))
			p.spread = 180.0
		"hemisphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = maxf(0.001, float(sh.get("radius", 0.15)))
			p.spread = 90.0
		"cone":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = maxf(0.001, float(sh.get("radius", 0.05)))
			p.spread = float(sh.get("angle", 30.0))
			var d := str(sh.get("dir", "up"))
			p.direction = Vector3.DOWN if d == "down" else (Vector3.BACK if d == "forward" else Vector3.UP)
		"circle":
			var r := maxf(0.001, float(sh.get("radius", 0.3)))
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = r
			p.emission_ring_inner_radius = r if not bool(sh.get("up", false)) else 0.0
			p.emission_ring_height = 0.0
			if bool(sh.get("up", false)):
				p.direction = Vector3.UP
				p.spread = 0.0
			else:
				p.direction = Vector3.RIGHT
				p.spread = 180.0
				p.flatness = 1.0
		"box":
			var b: Array = sh.get("size", [0.3, 0.3, 0.3])
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(float(b[0]), float(b[1]), float(b[2])) * 0.5
			p.spread = 10.0
		_:
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT

static func _size_curve(grow: String, stretch: float) -> Curve:
	var c := Curve.new()
	match grow:
		"shrink":
			c.add_point(Vector2(0, 1)); c.add_point(Vector2(0.5, 0.85)); c.add_point(Vector2(1, 0))
		"pop":
			c.max_value = 1.2
			c.add_point(Vector2(0, 0.2)); c.add_point(Vector2(0.15, 1.15)); c.add_point(Vector2(0.35, 1.0)); c.add_point(Vector2(0.8, 1.0)); c.add_point(Vector2(1, 0.6))
		"grow":
			c.add_point(Vector2(0, 0.4)); c.add_point(Vector2(1, 1))
		"wobble":
			c.max_value = 1.2
			c.add_point(Vector2(0, 0.6)); c.add_point(Vector2(0.3, 1.1)); c.add_point(Vector2(0.7, 1.0)); c.add_point(Vector2(1, 0))
		"ringout":
			# the ring grows from its start size to 5× (or stretch×), easing out
			var to := stretch if stretch > 0.0 else 5.0
			c.max_value = to
			c.add_point(Vector2(0, 1.0)); c.add_point(Vector2(0.3, 1.0 + (to - 1.0) * 0.7)); c.add_point(Vector2(1, to))
		_:
			c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, 1))
	return c

static func _mesh(orient: String) -> Mesh:
	if _meshes.has(orient): return _meshes[orient]
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	if orient == "horizontal": q.orientation = PlaneMesh.FACE_Y
	_meshes[orient] = q
	return q

static func _material(sprite: String, add: bool, orient: String) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [sprite, add, orient]
	if _materials.has(key): return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	var path := SPRITES % sprite
	if ResourceLoader.exists(path): m.albedo_texture = load(path)
	match orient:
		"horizontal": m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		"vertical": m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		_: m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	_materials[key] = m
	return m
