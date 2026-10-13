class_name ReplacementData
extends RefCounted
## Inspector data for a ReplacementRule.

var name: String = ""
var matches: int = EffectKind.Damage
var with_tags: Array[String] = []
## [Slot("Replacement")]
var condition: Condition = Condition.new()
var action: int = ReplaceAction.Cancel
var instead: StepList = StepList.new()
