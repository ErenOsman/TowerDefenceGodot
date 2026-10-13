class_name SimplePresenter
extends TimedPresenter
## Runs an action at begin and is done after a delay (floating words, banners).

var _begin: Callable

func _init(p_duration: float = 0.0, p_begin: Callable = Callable()) -> void:
	super(p_duration)
	_begin = p_begin

func _on_begin() -> void:
	if _begin.is_valid(): _begin.call()
