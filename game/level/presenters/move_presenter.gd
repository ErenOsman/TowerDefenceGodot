class_name MovePresenter
extends TimedPresenter
## A slide from tile to tile (walk 0.18 s, push/pull 0.12 s) or a hop on an arc (jump 0.35 s); the model plays
## its Walk clip meanwhile.

var view: EntityView
var from: Vector3
var to: Vector3
var arc: float

func _init(p_view: EntityView = null, p_from: Vector2i = Vector2i.ZERO, p_to: Vector2i = Vector2i.ZERO, p_duration: float = 0.18, p_arc: float = 0.0, p_face: bool = true) -> void:
	super(p_duration)
	view = hold(p_view)
	from = GridSpace.to_world(p_from)
	to = GridSpace.to_world(p_to)
	arc = p_arc
	if p_face and view != null: view.face(Dirs.between(p_from, p_to))

func _on_begin() -> void:
	if is_instance_valid(view) and view.rig != null: view.rig.set_moving(true)

func _on_update(t: float) -> void:
	if is_instance_valid(view): view.position = from.lerp(to, t) + Vector3.UP * (arc * 4.0 * t * (1.0 - t))

func _on_finish() -> void:
	if not is_instance_valid(view): return
	view.position = to
	if view.rig != null: view.rig.set_moving(false)
