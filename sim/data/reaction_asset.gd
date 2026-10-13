class_name ReactionAsset
extends ContentAsset
## A reaction as data (Create > Game > Reaction); AssetConverter.reaction() makes its ReactionDef.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

var trigger: int = Trigger.OnHitTaken
## [Slot("ReactionTrigger")]
var condition: Condition = Condition.new()
## [Slot("OnHit")]
var chance: Formula = Formula.new("1")
var roll_per: int = RollPer.Hit
var timing: int = Timing.AfterItem
var limit: int = Limit.None
var ignore_tags: Array[String] = [Tags.Reflected]
var works_when_dead: bool = false
var response: StepList = StepList.new()
