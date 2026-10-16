class_name OwnedTower
extends RefCounted
## A tower the player owns: its own ID, its type, and the name the player gave it.

var id: String = ""
## The TowerType ID (TowerAsset.Id).
var type: String = ""
## Empty = the type's name.
var custom_name: String = ""
## Workshop: the current form ID; empty = the type's default form.
var form: String = ""
## Workshop: the form IDs unlocked on this tower (never the default), in unlock order.
var forms: Array = []
## Upgrades — Design: the tower's level in its default form (1 until upgraded; levels exist from the Blacksmith unlock).
var level: int = 1
## Upgrades: the level of each unlocked form, {form id: level}; a form missing here is level 1.
var form_levels: Dictionary = {}
## Upgrades: task progress of the steps being worked on, {step key: [count per task]}; step key = TowerLevels.step_key
## ("2" = the default form's step to level 2, "archer-fire:2" = that form's). Upgrading drops the step's entry.
var task_progress: Dictionary = {}
