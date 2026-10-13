class_name TimedPresenter
extends IPresenter
## A presenter that runs for a fixed time and is ready at its impact moment (Presenters.cs TimedPresenter).
## Subclasses animate in _on_update(t: 0 → 1) and must leave the end state in _on_finish (Skip and Instant call
## finish() directly). Time is the Director's scaled delta, so durations follow the game speed.

var duration: float = 0.0
var ready_at: float = 0.0
var elapsed: float = 0.0
var finished: bool = false
var _holding: Array = []

func _init(p_duration: float = 0.0, p_ready_at: float = -1.0) -> void:
	duration = maxf(0.0, p_duration)
	ready_at = duration if p_ready_at < 0.0 else minf(p_ready_at, duration)

func is_ready() -> bool:
	return finished or elapsed >= ready_at

func is_done() -> bool:
	return finished

func begin() -> void:
	_on_begin()
	if duration <= 0.0: finish()

func tick(dt: float) -> void:
	if finished: return
	elapsed += dt
	if elapsed >= duration: finish()
	else: _on_update(elapsed / duration)

func finish() -> void:
	if finished: return
	finished = true
	_on_finish()
	for v in _holding:
		if is_instance_valid(v): v.animating -= 1
	_holding.clear()

## Marks a view as moved by this presenter until it finishes (frame syncs leave it alone).
func hold(v: EntityView) -> EntityView:
	if v != null and is_instance_valid(v):
		v.animating += 1
		_holding.append(v)
	return v

func _on_begin() -> void: pass
func _on_update(_t: float) -> void: pass
func _on_finish() -> void: pass
