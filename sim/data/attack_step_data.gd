class_name AttackStepData
extends StepData

var area: PatternDef = PatternDef.single()
## [Slot("TargetFilter")]
var area_filter: Condition = Condition.new()
## [Slot("Attack")]
var power: Formula = Formula.new("100")
var can_miss: bool = true
var can_crit: bool = true

## One chain per target; steps run in order and read earlier results (HpLost…).
var on_hit: StepList = StepList.new()

## [Slot("Attack")]
var hits: Formula = Formula.new("1")
## [FoldoutGroup("Bounces"), Slot("Attack")]
var bounces: Formula = Formula.new("0")
var bounce_area: PatternDef = PatternDef.diamond("2")
## [Slot("TargetFilter")]
var bounce_filter: Condition = Condition.new()
## How a bounce picks among its candidates. Default: the nearest to the last target.
var bounce_instinct: InstinctDef = InstinctDef.new()

func to_core(c: AssetConverter) -> Step:
	var s := AttackStep.new()
	s.area = area if area != null else PatternDef.single()
	s.area_filter = area_filter
	s.power = power
	s.can_miss = can_miss
	s.can_crit = can_crit
	s.on_hit = c.steps(on_hit)
	s.hits = hits
	s.bounces = bounces
	s.bounce_area = bounce_area if bounce_area != null else PatternDef.diamond("2")
	s.bounce_filter = bounce_filter
	s.bounce_instinct = bounce_instinct if bounce_instinct != null else InstinctDef.new()
	return s
