class_name AttackStep
extends Step
## An attack: freezes Attack-phase slots, gathers its area once, then one batch per hit.

var area: PatternDef = PatternDef.single()

## Target-filter evaluation point for area candidates.
var area_filter: Condition = Condition.new()

## Attack phase; frozen for every hit of this attack.
var power: Formula = Formula.new("100")

var can_miss: bool = true
var can_crit: bool = true

## One chain per target: these steps run in authored order and read earlier chain variables. Array of Step.
var on_hit: Array = []

## Attack phase: number of batches (multi-hit). At least 1.
var hits: Formula = Formula.new("1")

## Attack phase: number of bounces after the first batch (chain lightning).
var bounces: Formula = Formula.new("0")

## Where a bounce looks for its next target, centred on the last target.
var bounce_area: PatternDef = PatternDef.diamond("2")

## Target filter for bounce candidates (Self = caster).
var bounce_filter: Condition = Condition.new()

## How a bounce picks among its candidates; Default = the nearest to the last target (canonical order).
var bounce_instinct: InstinctDef = InstinctDef.new()

func expand(c: StepContext) -> Array:
	var e := AttackEffect.new()
	e.step = self
	e.aim = c.aim
	e.caster = c.self_.id
	return [c.init(e)]
