class_name ProjectilePresenter
extends TimedPresenter
## A shot flying to the target: the ability's projectile model (res://art/models: Arrow, Ballista Bolt, Cannon
## Shell, Fire Orb, Acid Flask, Spit Glob, Wisp Spark; it faces its flight, with its trail) or a placeholder
## sphere; straight (0.12 s per tile) or on an arc for lobbed shots (0.5 s). Ready on arrival.

var from: Vector3
var to: Vector3
var arc: float
var scene: PackedScene
var trail: String
var parent: Node
var _ball: Node3D = null

## speed: tiles per second (0 = the default pace).
func _init(p_parent: Node = null, p_from: Vector3 = Vector3.ZERO, p_to: Vector3 = Vector3.ZERO, p_arc: float = 0.0, p_scene: PackedScene = null, speed: float = 0.0, p_trail: String = "") -> void:
	var dist := p_from.distance_to(p_to)
	var d := maxf(0.08, dist / speed) if speed > 0.0 else (0.5 if p_arc > 0.0 else maxf(0.12, 0.12 * dist))
	super(d)
	parent = p_parent
	from = p_from
	to = p_to
	arc = p_arc
	scene = p_scene
	trail = p_trail

func _on_begin() -> void:
	if parent == null or not is_instance_valid(parent): return
	if scene != null:
		_ball = scene.instantiate()
	else:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		mi.mesh = sphere
		mi.material_override = BoardMaterials.lit(Color(1.0, 0.9, 0.4))
		_ball = mi
	parent.add_child(_ball)
	_ball.position = from # the board sits at the world origin
	if trail != "":
		var t := VfxKit.loop(trail)
		if t != null: _ball.add_child(t)
	_on_update(0.0)
	for c in _ball.get_children():
		if c.has_meta("loop"): VfxKit.start(c) # the trail starts once the shot is at the muzzle

func _on_update(t: float) -> void:
	if _ball == null or not is_instance_valid(_ball): return
	var p := from.lerp(to, t) + Vector3.UP * (arc * 4.0 * t * (1.0 - t))
	var step := p - _ball.position
	if t == 0.0:
		var t2 := 0.02
		step = from.lerp(to, t2) + Vector3.UP * (arc * 4.0 * t2 * (1.0 - t2)) - from
	if scene != null and step.length_squared() > 1e-8:
		var up := Vector3.UP if absf(step.normalized().y) < 0.99 else Vector3.FORWARD
		_ball.position = p
		_ball.basis = Basis.looking_at(step, up, true)
	else:
		_ball.position = p

func _on_finish() -> void:
	if _ball != null and is_instance_valid(_ball): _ball.queue_free()
	_ball = null
