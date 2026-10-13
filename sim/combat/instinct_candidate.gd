class_name InstinctCandidate
extends RefCounted
## A candidate an instinct ranks: an aim and the unit it targets (null for an empty tile or a route).
## A readonly struct in C#: treat it as immutable.

var aim: Aim
var target: Entity

func _init(p_aim: Aim = null, p_target: Entity = null) -> void:
	aim = p_aim
	target = p_target
