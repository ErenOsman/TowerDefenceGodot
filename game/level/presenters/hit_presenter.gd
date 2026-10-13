class_name HitPresenter
extends TimedPresenter
## A colour flash, an optional shake, and something shown at the start (a number).

var view: EntityView
var color: Color
var shake: bool
var show: Callable
var _rest := Vector3.ZERO

func _init(p_view: EntityView = null, p_color: Color = Color.WHITE, p_duration: float = 0.25, p_shake: bool = false, p_show: Callable = Callable()) -> void:
	super(p_duration)
	view = p_view
	color = p_color
	shake = p_shake
	show = p_show

func _on_begin() -> void:
	if is_instance_valid(view) and view.body != null: _rest = view.body.position
	if show.is_valid(): show.call()

func _on_update(t: float) -> void:
	if not is_instance_valid(view): return
	view.flash(color, 1.0 - t)
	if shake and view.body != null: view.body.position = _rest + Vector3(sin(t * 60.0) * 0.06 * (1.0 - t), 0, 0)

func _on_finish() -> void:
	if not is_instance_valid(view): return
	view.flash(color, 0.0)
	if view.body != null and shake: view.body.position = _rest
