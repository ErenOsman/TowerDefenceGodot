class_name ReplacementRule
extends RefCounted
## Intercepts an effect before it applies. Reads state but never changes it.

var name: String = ""
var matches: int = EffectKind.Damage
var with_tags: Array = []

## Replacement evaluation point: Self (owner), Source, Target, effect kind and tags.
var condition: Condition = Condition.new()

var action: int = ReplaceAction.Cancel

## Used by Replace: steps acting on the effect's target (Target) or the owner (Self). Array of Step.
var instead: Array = []
