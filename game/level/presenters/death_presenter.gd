class_name DeathPresenter
extends TimedPresenter
## A death without a Die clip: squashes (0.4 s), then the corpse (hidden unless corpses show) and the death effect.

var view: EntityView
var fx: Callable

func _init(p_view: EntityView = null, p_fx: Callable = Callable()) -> void:
	super(0.4)
	view = hold(p_view)
	fx = p_fx

func _on_update(t: float) -> void:
	if is_instance_valid(view): view.scale = Vector3(1.0, lerpf(1.0, 0.25, t), 1.0)

func _on_finish() -> void:
	if not is_instance_valid(view): return # removed meanwhile
	view.scale = Vector3.ONE
	view.show_corpse()
	if fx.is_valid(): fx.call(PresentationTimings.get_timings().death_vfx, view.world_position + Vector3.UP * 0.4)
