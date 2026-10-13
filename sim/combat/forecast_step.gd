class_name ForecastStep
extends RefCounted
## One ability a unit would cast in its coming turn: which, where, and what it would hit from there.

var ability: AbilityDef
var aim: Aim

## The area, targets, line or route of that cast, as the board would stand at that moment.
var preview: AimPreview

var is_movement: bool:
	get: return ability.targeting.is_movement

static func make(p_ability: AbilityDef, p_aim: Aim, p_preview: AimPreview) -> ForecastStep:
	var f := ForecastStep.new()
	f.ability = p_ability
	f.aim = p_aim
	f.preview = p_preview
	return f
