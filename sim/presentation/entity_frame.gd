class_name EntityFrame
extends RefCounted
## An entity as the view shows it after a beat.

var id: int = -1
var name: String = ""
var kind: int = 0
var life: int = 0
## Null when not on the board (else a Vector2i); pos is the death tile for a corpse.
var position: Variant = null
var pos: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.ZERO
var team: int = 0
var hp: int = 0
var max_hp: int = 0
var shield: int = 0
var has_hp: bool = false
var statuses: Array = []  # of StatusView
## Visible passives, with whether each is active now.
var passives: Array = []  # of PassiveView
## Abilities on cooldown: turns left by ability (AbilityDef → int).
var cooldowns: Dictionary = {}
## The tower ID for placed towers, else null.
var tower_id: Variant = null
