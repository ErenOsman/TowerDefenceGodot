class_name AbilityInstance
extends RefCounted
## One use of an ability: caster, aim, frozen variables, per-target results, scoped modifiers.

var id: int = 0
## AbilityDef.
var def = null
## C# default(EntityId) = 0.
var caster: int = 0
var aim: Aim = null
## A Dictionary used as a set, or null (C# HashSet<string>, unset by default).
var tags = null
## String → float.
var frozen: Dictionary = {}
## EntityId int → Dictionary (String → float).
var results: Dictionary = {}
## Array of ScopedModifier.
var scoped: Array = []
## Array of PendingReaction.
var deferred: Array = []
## A Dictionary used as a set.
var fired: Dictionary = {}

## rollPer: Attack results, keyed by rule and attack (String → bool).
var attack_rolls: Dictionary = {}
