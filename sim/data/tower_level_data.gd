class_name TowerLevelData
extends RefCounted
## One step of a tower's (or a form's) level ladder (Upgrades — Design § Data, `levels` in Towers.json / Forms.json):
## the level it reaches, the tasks that level needs and the stat bonuses it gives.
## `{ "to": 2, "tasks": [ { "kind": "WinMission", "count": 1 } ], "bonuses": [ { "stat": "Power", "kind": "Flat", "amount": "2" } ] }`

## The level this step reaches (2 for the first step).
var to: int = 2
## Array of TowerTaskData.
var tasks: Array = []
## Array of LevelBonusData.
var bonuses: Array = []
