class_name AttackContext
extends RefCounted
## One Attack effect's shared data: frozen Power, the area gathered once, entities already hit.

var id: int = 0
var step: AttackStep
## EntityId (int).
var caster: int = -1
var aim: Aim
var power: float = 0.0
## Array of EntityId (int).
var targets: Array = []
## A set of EntityIds: Dictionary {id: true}.
var hit_units: Dictionary = {}
## A set: Dictionary {tag: true}.
var tags: Dictionary = {}
var step_context: StepContext
var ability: AbilityInstance
