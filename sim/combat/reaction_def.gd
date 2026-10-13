class_name ReactionDef
extends RefCounted
## A rule that responds to an event by queuing new effects.

var name: String = ""
var trigger: int = Trigger.OnHitTaken

## Reaction-trigger evaluation point. Empty is always true.
var condition: Condition = Condition.new()

var chance: Formula = Formula.new("1")
var roll_per: int = RollPer.Hit
var timing: int = Timing.AfterItem
var limit: int = Limit.None

## Events carrying any of these tags are ignored. Reflected by default (two Thorns cannot ping-pong).
var ignore_tags: Array = [Tags.Reflected]

var works_when_dead: bool = false
## Array of Step.
var response: Array = []
