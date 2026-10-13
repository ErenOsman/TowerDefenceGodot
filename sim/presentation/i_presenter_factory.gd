class_name IPresenterFactory
extends RefCounted
## Creates the presenter for one event of a beat, or null when the event is not shown.
## Interface: implementers extend this and override create().

func create(_e: GameEvent, _beat: BeatPlayback) -> IPresenter:
	push_error("abstract")
	return null
