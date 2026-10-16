class_name TowerTaskData
extends RefCounted
## One task of a level step (Upgrades — Design § Data): a kind (TowerTaskKind), how many, the mission for
## WinMissionId, and an optional text replacing the one made from the kind and count.

var kind: int = TowerTaskKind.WinMission
var count: int = 1
## WinMissionId only: the mission to win.
var mission: MissionAsset = null
## "" = the text made from the kind and count (TowerTasks.describe).
var text: String = ""
## Pay only: the currency deposited, "gold" or a token id (TokenAsset.id) later. Every step has exactly one gold Pay
## task (AssetValidator.validate_ladder).
var currency: String = ""
