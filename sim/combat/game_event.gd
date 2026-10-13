class_name GameEvent
extends RefCounted
## An immutable fact the logic writes. The event log is the only output of the logic.

var id: int = 0

## The event that caused the effect which wrote this one; -1 for commands.
var cause: int = -1

var type: int = GameEventType.AbilityDeclared
var source: int = -1
var target: int = -1

## Facts for formulas and conditions (Damage, FinalDamage, Hit, IsCrit…): String → float.
var facts: Dictionary = {}

## A Dictionary used as a set ({tag: true}).
var tags: Dictionary = {}

## Ability, status or effect name, depending on the event. String or null.
var detail = null

var from: Vector2i = Vector2i.ZERO
var to: Vector2i = Vector2i.ZERO
## Array of EntityId ints, or null.
var targets = null
var ability: AbilityInstance = null
var attack_id: int = 0
var depth: int = 0

## The action this event belongs to (EventLog.actions); presentation plays one action at a time.
var action: int = -1

## The beat: events of one queue item (or one checkpoint) share it and play together.
var beat: int = 0

func fact(p_name: String) -> bool:
	return facts.has(p_name) and Num.is_true(facts[p_name])
