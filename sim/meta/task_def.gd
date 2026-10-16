class_name TaskDef
extends RefCounted
## One converted level task (Upgrades — Design): kind (TowerTaskKind), count, the mission id (WinMissionId) and its
## name for texts, and the optional own text. Godot-first.

var kind: int = TowerTaskKind.WinMission
var count: int = 1
## WinMissionId: the mission's id ("" otherwise).
var mission: String = ""
## WinMissionId: the mission's display name (for describe()).
var mission_name: String = ""
## "" = TowerTasks.describe makes it from the kind and count.
var text: String = ""
## Pay: what is deposited, "gold" (TowerTasks.Gold) or a token id ("" for other kinds).
var currency: String = ""
