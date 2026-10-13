class_name StepContext
extends RefCounted
## Everything a step needs to expand into effects.

var state: GameState
var ability: AbilityInstance
var attack: AttackContext

## The caster, or the reaction's/replacement's owner. (C# Self; `self` is a GDScript keyword.)
var self_: Entity

## Source of the effects (the owner, a status's applier, or the Environment). An EntityId (int).
var effect_source: int = 0

## The chain target in an attack, the event's target in a reaction.
var target: Entity

## The triggering event, for reactions; its facts become variables.
var event: GameEvent

var aim: Aim
## A set: Dictionary {tag: true}.
var tags: Dictionary = {}
var cause: int = -1
var depth: int = 0

## Extra variables for the effects, besides the event's facts (e.g. StatusStacks in a status's reaction). null = none.
var vars = null

func resolve(t: int) -> Entity:
	match t:
		StepTarget.Self: return self_
		StepTarget.EventSource: return state.get_entity(event.source) if event != null else target
		StepTarget.EventTarget: return state.get_entity(event.target) if event != null else target
		_: return target

## A shallow copy (C# MemberwiseClone: the tags set and vars are shared) with another target.
func with_target(p_target: Entity) -> StepContext:
	var c := StepContext.new()
	c.state = state
	c.ability = ability
	c.attack = attack
	c.self_ = self_
	c.effect_source = effect_source
	c.target = p_target
	c.event = event
	c.aim = aim
	c.tags = tags
	c.cause = cause
	c.depth = depth
	c.vars = vars
	return c

## Common effect fields: source, ability, cause, tags, depth, event facts, attack.
func init(effect: Effect, extra_tags = null) -> Effect:
	effect.source = effect_source
	effect.ability = ability
	effect.attack = attack
	effect.cause = cause
	effect.depth = depth
	effect.tags = Tags.union(tags, extra_tags)
	if event != null: effect.event_facts = event.facts.duplicate()
	if vars != null:
		if effect.event_facts == null: effect.event_facts = {}
		for k in vars: effect.event_facts[k] = vars[k]
	effect.step_context = self
	return effect
