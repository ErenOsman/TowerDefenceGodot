class_name PassiveDef
extends IRuleSource
## A passive: rules gated by a condition re-checked at every checkpoint.
## display_name: assigning stores the raw field (_display_name); reading gives the C# DisplayName (name when empty).

var name: String = ""

## What players see; empty uses the name.
var _display_name: String = ""
var display_name: String:
	get: return name if _display_name.is_empty() else _display_name
	set(v): _display_name = "" if v == null else v
var description: String = ""

## Not shown to players (rules that only make something else work, e.g. a hazard's mechanics).
var hidden: bool = false

## Empty = always active.
var condition: Condition = Condition.new()

## Optional hysteresis: once on, the passive stays on until this is true.
var off_condition: Condition = Condition.new()

## Array of Modifier.
var modifiers: Array = []
## Array of ReplacementRule.
var replacements: Array = []
## Array of ReactionDef.
var reactions: Array = []

## Non-empty: an aura (e.g. "Target.IsAlly and Target.Distance <= 2").
var aura: Condition = Condition.new()

## Alias of reading display_name (the C# DisplayName), for code written against a get_display_name() convention.
func get_display_name() -> String:
	return display_name
