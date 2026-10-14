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
