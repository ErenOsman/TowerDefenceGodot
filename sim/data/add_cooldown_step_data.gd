class_name AddCooldownStepData
extends StepData

## The ability to delay; null = every ability of the unit except the one being cast.
var ability: AbilityAsset = null
var on: int = StepTarget.Self
## Turns added to its cooldown (held cooldowns stay held). [Slot("OnHit")]
var turns: Formula = Formula.new("1")

func to_core(c: AssetConverter) -> Step:
	var s := AddCooldownStep.new()
	s.ability = c.ability(ability) if ability != null else null
	s.on = on
	s.turns = turns
	return s
