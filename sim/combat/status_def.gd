class_name StatusDef
extends IRuleSource
## A status: a set of rules with a lifetime. Shared, read-only definition.
## display_name: assigning stores the raw field (_display_name); reading gives the C# DisplayName (name when empty).

## The stable ID rules refer to (HasStatus, Remove Status by name).
var name: String = ""

## The name players see; empty = name.
var _display_name: String = ""
var display_name: String:
	get: return name if _display_name.is_empty() else _display_name
	set(v): _display_name = "" if v == null else v

## Player-facing text for tooltips.
var description: String = ""

## Tags the status grants its owner while active (Stunned, Rooted, Buff…).
var tags: Array = []

var stacking: int = Stacking.Stack
var max_stacks: int = 99

## -1 is permanent.
var duration: int = -1
var duration_unit: int = DurationUnit.Turns

## Array of Modifier.
var modifiers: Array = []
## Array of ReplacementRule.
var replacements: Array = []
## Array of ReactionDef.
var reactions: Array = []

## Optional gate on the whole set of rules, re-checked at checkpoints.
var passive_condition: Condition = Condition.new()

## Non-empty: the rules apply to entities this covers (Self = owner, Target = receiver), not to the owner.
var aura: Condition = Condition.new()

## A shield: OnHit amount of damage the status absorbs, resolved when applied. Empty = not a shield.
var shield_pool: Formula = Formula.new()

## The pool is the stacks (shieldPool "Stacks"): one shield point per stack, and absorbed damage removes stacks.
var stacks_are_shield: bool:
	get: return shield_pool != null and shield_pool.expression.strip_edges() == "Stacks"

var team_override: int = TeamOverride.None
var fixed_team: int = 0

## Kept when the owner dies (otherwise statuses are cleared at death).
var persists_through_death: bool = false

func has_tag(tag: String) -> bool:
	return tags.has(tag)

## Alias of reading display_name (the C# DisplayName), for code written against a get_display_name() convention.
func get_display_name() -> String:
	return display_name
