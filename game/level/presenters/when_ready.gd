class_name WhenReady
extends IPresenter
## Runs an action the first time the inner presenter is ready (an impact effect when a projectile arrives).

var inner: IPresenter
var _at_ready: Callable
var _fired := false

func _init(p_inner: IPresenter = null, p_at_ready: Callable = Callable()) -> void:
	inner = p_inner
	_at_ready = p_at_ready

func is_ready() -> bool: return inner.ready
func is_done() -> bool: return inner.done
func begin() -> void:
	inner.begin()
	_check()
func tick(dt: float) -> void:
	inner.tick(dt)
	_check()
func finish() -> void:
	inner.finish()
	_check()

func _check() -> void:
	if _fired or not inner.ready: return
	_fired = true
	if _at_ready.is_valid(): _at_ready.call()
