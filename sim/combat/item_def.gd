class_name ItemDef
extends IRuleSource
## An equipped item, as a rule source only (no inventory management in combat).

var name: String = ""
## Array of Modifier.
var modifiers: Array = []
## Array of ReplacementRule.
var replacements: Array = []
## Array of ReactionDef.
var reactions: Array = []

## IRuleSource.Aura: items are never auras.
var aura: Condition:
	get: return Condition.new()
