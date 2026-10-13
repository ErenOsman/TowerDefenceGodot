class_name AbilityDef
extends RefCounted
## An ability: tags, costs, gates and a list of steps. Plain data; the asset layer fills the same fields.

## The stable ID rules refer to (the asset's id; the asset name when it has none).
var name: String = ""

## The name players see; empty = name.
## display_name: assigning stores the raw field (_display_name); reading gives the C# DisplayName (name when empty).
var _display_name: String = ""
var display_name: String:
	get: return name if _display_name.is_empty() else _display_name
	set(v): _display_name = "" if v == null else v

## Player-facing text for tooltips.
var description: String = ""

## Alias of reading display_name (the C# DisplayName).
func get_display_name() -> String:
	return display_name

var tags: Array = []
## Array of Cost.
var costs: Array = []

## Cast-gate evaluation point (Self).
var cast_gate: Condition = Condition.new()

## Where the ability can aim, centred on the caster.
var targeting: PatternDef = PatternDef.self_()

## Target-filter evaluation point, per candidate entity. Empty: any tile can be aimed at.
var target_filter: Condition = Condition.new()

## Aims at corpses instead of living entities (resurrection, corpse explosion).
var targets_dead: bool = false

## Only tiles the caster could stand on, free (teleports): no target filter needed.
var needs_free_tile: bool = false

## Turns before it can be cast again (0 = none). A player cast and a reaction cast start it alike.
var cooldown: int = 0

## After a cast it stays on cooldown until a Reset Cooldown step frees it (ignoring cooldown's number).
var cooldown_until_reset: bool = false

## Turns it starts on cooldown when its owner appears (placed, spawned); -1 = held until a reset.
var start_cooldown: int = 0

## Where the ability goes when nobody aims it (enemy turns, quick cast); Default = from its targeting (Instinct).
var instinct: InstinctDef = InstinctDef.new()

## Array of Step.
var steps: Array = []

func _to_string() -> String:
	return name
