class_name Effect
extends RefCounted
## The unit the resolver runs: checked, possibly replaced, then applied.
## C# virtual properties Kind and Name are properties here whose getters call the overridable
## _kind() / _name() (GDScript cannot override a property).

## Never None: the Environment entity (0) for traps, tiles and GameRules. An EntityId (int).
var source: int = 0

## The ability this effect belongs to; null for status ticks, terrain and plain reactions.
var ability: AbilityInstance

var attack: AttackContext

## The event that produced it; -1 for commands.
var cause: int = -1

## A set: Dictionary {tag: true}.
var tags: Dictionary = {}
var depth: int = 0
var cancelled: bool = false
var redirected: bool = false

## The entity the effect acts on; None (-1) for effects without one.
var target_id: int = -1

## Facts of the triggering event, readable by response formulas (e.g. FinalDamage for Thorns). null = none.
var event_facts = null

var step_context: StepContext
## internal in C#.
var chain: Chain

## Self for this effect's formulas: the step's owner (caster, or a rule's owner), else the source.
func self_of(s: GameState) -> Entity:
	if step_context != null and step_context.self_ != null: return step_context.self_
	return s.get_entity(source)

## EffectKind.
var kind: int:
	get: return _kind()

var name: String:
	get: return _name()

func _kind() -> int:
	push_error("abstract")
	return EffectKind.Other

func _name() -> String:
	return String(get_script().get_global_name()).replace("Effect", "")

## False = the effect fizzles. By default the target must be alive.
func is_valid(s: GameState) -> bool:
	if target_id < 0: return true
	var t: Entity = s.get_entity(target_id)
	return t != null and (t.alive or t.is_environment)

func apply(_ctx: ResolveContext) -> void:
	push_error("abstract")

# ---------------------------------------------------------------- port helpers (C# HashSet / LINQ)

## Adds a key to a set that is either a Dictionary {k: true} or an Array.
static func set_add(set, k) -> void:
	if set is Dictionary: set[k] = true
	elif not set.has(k): set.append(k)

## Floors a slot output and returns an int (Rounding.Apply(v, r).FloorToInt()).
static func floor_int(v: float, r: int = Round.Floor) -> int:
	return Num.floor_to_int(Rounding.apply(v, r))
