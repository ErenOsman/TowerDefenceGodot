class_name InstinctDef
extends RefCounted
## How an ability chooses its own aim when nobody clicks one (Instinct — Design): enemy turns,
## bounces, later quick cast and Pick. Must drops candidates; a Taunted chooser keeps only the
## ones hitting any of its taunters (when this ability can hit one; else all); the preset (or the Prefer list) sorts them;
## then the tie-break: the target's EntityId, then the candidates' own order.

var preset: int = InstinctPreset.Default

## Candidates whose target fails it are dropped (Self = the caster, Target = the candidate).
## A candidate without a target fails a non-empty Must. [Slot("TargetFilter")]
var must: Condition = Condition.new()

## Custom only: sort keys in order (Array of Preference); later ones break the earlier ones' ties.
var prefer: Array = []

var is_default: bool:
	get: return preset == InstinctPreset.Default and must.is_empty

static func of(p_preset: int, p_must = null) -> InstinctDef:
	var d := InstinctDef.new()
	d.preset = p_preset
	d.must = Condition.of(p_must)
	return d

static func custom(...p_prefer: Array) -> InstinctDef:
	var d := InstinctDef.new()
	d.preset = InstinctPreset.Custom
	d.prefer = p_prefer.duplicate()
	return d
