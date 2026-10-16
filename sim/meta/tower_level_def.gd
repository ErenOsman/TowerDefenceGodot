class_name TowerLevelDef
extends RefCounted
## One converted level step of a tower type's or a form's ladder (Upgrades — Design): the level it reaches, its
## tasks (TaskDef) and its bonuses (Modifier: target = the stat, kind Flat / PctAdd, amount a constant formula).
## Built by AssetConverter.tower_level. Godot-first.

var to: int = 2
## Array of TaskDef.
var tasks: Array = []
## Array of Modifier.
var bonuses: Array = []
