class_name TeleportPresenter
extends TimedPresenter
## A teleport: shrinks away, moves at half time, grows back (0.3 s).

var view: EntityView
var to: Vector3
var _moved := false

func _init(p_view: EntityView = null, p_to: Vector2i = Vector2i.ZERO) -> void:
	super(0.3)
	view = hold(p_view)
	to = GridSpace.to_world(p_to)

func _on_update(t: float) -> void:
	if not is_instance_valid(view): return
	if not _moved and t >= 0.5:
		view.position = to
		_moved = true
	view.scale = Vector3.ONE * maxf(0.05, absf(t - 0.5) * 2.0)

func _on_finish() -> void:
	if not is_instance_valid(view): return
	view.position = to
	view.scale = Vector3.ONE
