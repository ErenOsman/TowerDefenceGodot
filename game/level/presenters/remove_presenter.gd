class_name RemovePresenter
extends TimedPresenter
## A removal (sold, back to the hand, a corpse cleared): shrinks away (0.2 s), then the view goes.

var views: EntityViews
var view: EntityView

func _init(p_views: EntityViews = null, p_view: EntityView = null) -> void:
	super(0.2)
	views = p_views
	view = hold(p_view)

func _on_update(t: float) -> void:
	if is_instance_valid(view): view.scale = Vector3.ONE * (1.0 - t)

func _on_finish() -> void:
	if is_instance_valid(view) and views != null: views.remove(view.id)
