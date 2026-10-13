class_name OwnedTower
extends RefCounted
## A tower the player owns: its own ID, its type, and the name the player gave it.

var id: String = ""
## The TowerType ID (TowerAsset.Id).
var type: String = ""
## Empty = the type's name.
var custom_name: String = ""
