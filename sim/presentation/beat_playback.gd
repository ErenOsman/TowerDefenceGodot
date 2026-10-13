class_name BeatPlayback
extends RefCounted
## One beat as the Director plays it: its events, its action, the view frame after it.

var beat: int = 0
var action: ActionInfo = null
var events: Array = []  # of GameEvent
var frame: ViewFrame = null
