class_name CastAbilityStepData
extends StepData

var ability: AbilityAsset = null
var aim_at: int = StepTarget.Target
## Ignore Aim At: the ability's own instinct chooses where it goes. No valid aim, no cast.
var aim_by_instinct: bool = false

func to_core(c: AssetConverter) -> Step:
	var s := CastAbilityStep.new()
	s.ability = c.ability(ability)
	s.aim_at = aim_at
	s.aim_by_instinct = aim_by_instinct
	return s
