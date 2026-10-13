class_name Preference
extends RefCounted
## One sort key of a custom instinct: Highest or Lowest of a formula (Self = the caster, Target =
## the candidate, or each unit in the area for AreaSum).

## [Slot("Instinct")]
var value: Formula = Formula.new()
var highest: bool = false
var over: int = PreferOver.Target

## AreaSum / AreaCount: only units passing it count (Self = the caster, Target = the unit). [Slot("TargetFilter")]
var filter: Condition = Condition.new()

static func _make(p_value, p_highest: bool, p_over: int, p_filter) -> Preference:
	var p := Preference.new()
	p.value = Formula.of(p_value)
	p.highest = p_highest
	p.over = p_over
	p.filter = Condition.of(p_filter)
	return p

static func highest_of(formula) -> Preference: return _make(formula, true, PreferOver.Target, null)
static func lowest_of(formula) -> Preference: return _make(formula, false, PreferOver.Target, null)
static func most_in_area(p_filter = null) -> Preference: return _make(null, true, PreferOver.AreaCount, p_filter)
static func highest_sum(formula, p_filter = null) -> Preference: return _make(formula, true, PreferOver.AreaSum, p_filter)
