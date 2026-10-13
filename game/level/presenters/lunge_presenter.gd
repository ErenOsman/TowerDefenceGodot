class_name LungePresenter
extends TimedPresenter
## A melee swing without an Attack clip: lunges toward the target; the hit lands at the lunge's peak (ready at
## 0.15 s), then steps back (0.3 s).

var view: EntityView
var home: Vector3
var peak: Vector3

func _init(caster: EntityView = null, target: EntityView = null) -> void:
	super(0.3, 0.15)
	view = hold(caster)
	if view == null: return
	home = caster.position
	var toward := (target.position - home) if target != null else Vector3.ZERO
	toward.y = 0.0
	peak = home + (toward.normalized() * minf(0.4, toward.length() * 0.5) if toward.length_squared() > 0.000001 else Vector3.ZERO)
	if target != null: caster.face_point(target.world_position)

func _on_update(t: float) -> void:
	if is_instance_valid(view): view.position = home.lerp(peak, 1.0 - absf(t * 2.0 - 1.0))

func _on_finish() -> void:
	if is_instance_valid(view): view.position = home
