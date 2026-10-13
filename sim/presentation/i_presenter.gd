class_name IPresenter
extends RefCounted
## Plays one event. begin() starts it; tick() advances it; ready says the beat may go on (its impact
## moment — the rest is a tail that keeps playing); done says it is over; finish() snaps it to its end
## state at once and may be called at any moment (Skip and Instant rely only on it).
## Interface: implementers extend this and override begin/tick/finish and the is_ready/is_done getters
## (a subclass cannot redeclare the `ready`/`done` properties; they call these).

var ready: bool:
	get: return is_ready()
var done: bool:
	get: return is_done()

func begin() -> void:
	push_error("abstract")

func tick(_dt: float) -> void:
	push_error("abstract")

func is_ready() -> bool:
	push_error("abstract")
	return true

func is_done() -> bool:
	push_error("abstract")
	return true

func finish() -> void:
	push_error("abstract")
