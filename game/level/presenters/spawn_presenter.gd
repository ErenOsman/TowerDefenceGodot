class_name SpawnPresenter
extends TimedPresenter
## Spawn or resurrection: the view appears (created if needed) and pops in (0.3 s), with the kit's spawn effect.

var view: EntityView

func _init(views: EntityViews = null, frame: EntityFrame = null, at: Vector2i = Vector2i.ZERO, fx: Callable = Callable()) -> void:
	super(0.3)
	if frame == null or views == null: return
	view = hold(views.ensure(frame))
	view.show_alive()
	view.set_team(frame)
	view.place(at)
	view.face(frame.facing)
	view.scale = Vector3.ONE * 0.05
	if fx.is_valid(): fx.call(PresentationTimings.get_timings().spawn_vfx, GridSpace.to_world(at, 0.4))

func _on_update(t: float) -> void:
	if is_instance_valid(view): view.scale = Vector3.ONE * lerpf(0.05, 1.0, smoothstep(0.0, 1.0, t))

func _on_finish() -> void:
	if is_instance_valid(view): view.scale = Vector3.ONE
