class_name LevelLaunch
extends RefCounted
## The level the game scene should play, set by level select before loading the scene. With no
## request, the game scene keeps its own level (playing it straight from the editor).
## Godot-first addition: `mission_id`, the mission the level is played as ("" = a chapter level; Missions & Guild —
## Design): the level then spends a play, takes the first rested towers and gives the mission's drops.

static var level: LevelAsset = null
static var mission_id: String = ""

static func has_request() -> bool:
	return level != null

## Asks for a level; p_mission_id = the mission it is played as ("" for a plain level: any earlier mission is dropped).
static func request(p_level: LevelAsset, p_mission_id: String = "") -> void:
	level = p_level
	mission_id = p_mission_id if p_level != null else ""

static func clear() -> void:
	level = null
	mission_id = ""
