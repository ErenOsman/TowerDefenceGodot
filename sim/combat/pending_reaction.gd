class_name PendingReaction
extends RefCounted
## A reaction collected while its event was written; checked and rolled at the checkpoint.

## Self for the reaction: the entity the rule applies to (an aura's receiver, not its owner).
var owner: Entity = null
var def: ReactionDef = null
var event: GameEvent = null

## Source of the response effects: the owner, a status's applier, or the Environment. C# default(EntityId) = 0.
var effect_source: int = 0

## Identifies the rule for limits: receiver + source + rule index.
var rule_key: String = ""

## The status instance the rule comes from, if any: its stacks are the StatusStacks variable.
var status: StatusInstance = null

## Variables a reaction reads besides its event's facts.
func vars() -> Dictionary:
	return {"StatusStacks": float(status.stacks) if status != null else 0.0}
