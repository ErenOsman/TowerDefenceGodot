class_name AnimatePresenter
extends IPresenter
## Plays one clip of a model through its rig (Presenters.cs AnimatePresenter). Ready at the clip's impact (its
## impact key, or the rig's fallback fraction); then the optional follow-up (a projectile) starts and the beat goes
## on when that is ready too. Done when the clip and the follow-up are over; the clip's tail keeps playing while
## the next beat runs. finish() (Skip, Instant) fires the impact, finishes the follow-up and snaps the model to
## rest — or runs on_end instead (Die: the corpse pose).

var view: EntityView
var trigger: String
var face_target: EntityView
var on_begin: Callable
var on_impact: Callable
var then: Callable        # → IPresenter or null
var on_end: Callable
var elapsed := 0.0
var length := 0.5
var impact_at := 0.25
var impacted := false
var finished := false
var next: IPresenter = null

func _init(p_view: EntityView = null, p_trigger: String = "", p_face_target: EntityView = null, p_on_begin: Callable = Callable(),
		p_on_impact: Callable = Callable(), p_then: Callable = Callable(), p_on_end: Callable = Callable()) -> void:
	view = p_view
	trigger = p_trigger
	face_target = p_face_target
	on_begin = p_on_begin
	on_impact = p_on_impact
	then = p_then
	on_end = p_on_end

func is_ready() -> bool:
	return finished or (impacted and (next == null or next.ready))

func is_done() -> bool:
	return finished

func begin() -> void:
	if not is_instance_valid(view):
		finish()
		return
	view.animating += 1
	if face_target != null and is_instance_valid(face_target): view.face_point(face_target.world_position)
	if on_begin.is_valid(): on_begin.call()
	var rig := view.rig
	length = rig.clip_length(trigger, 0.5)
	impact_at = minf(rig.impact_time(trigger), length)
	rig.play(trigger, _impact)

func tick(dt: float) -> void:
	if finished: return
	elapsed += dt
	if not impacted and elapsed >= impact_at:
		if is_instance_valid(view) and view.rig != null: view.rig.release_impact()
		_impact()
	if next != null: next.tick(dt)
	if elapsed >= length and impacted and (next == null or next.done): _end(false)

func finish() -> void:
	if finished: return
	_impact()
	if next != null: next.finish()
	_end(true)

func _impact() -> void:
	if impacted: return
	impacted = true
	if on_impact.is_valid(): on_impact.call()
	next = then.call() if then.is_valid() else null
	if next != null: next.begin()

func _end(snap: bool) -> void:
	finished = true
	if not is_instance_valid(view): return
	view.animating -= 1
	if on_end.is_valid(): on_end.call()
	elif snap and view.rig != null: view.rig.to_rest()
