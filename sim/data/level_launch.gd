class_name LevelLaunch
extends RefCounted
## The level the game scene should play, set by level select before loading the scene. With no
## request, the game scene keeps its own level (playing it straight from the editor).

static var level: LevelAsset = null

static func has_request() -> bool:
	return level != null

static func request(p_level: LevelAsset) -> void:
	level = p_level

static func clear() -> void:
	level = null
