class_name IRuleSource
extends RefCounted
## Anything that contributes modifiers, replacements or reactions: passives, statuses, items, GameRules.
## A non-empty aura filter makes its rules apply to the entities the filter covers instead of
## its owner (Self = the owner, Target = the candidate receiver).
## The C# interface properties are members implementers declare themselves (GDScript cannot redeclare an
## inherited member), so this base class only names the contract:
##   name: String, modifiers: Array[Modifier], replacements: Array[ReplacementRule],
##   reactions: Array[ReactionDef], aura: Condition (empty = not an aura).
