class_name ResetCooldownStepData
extends StepData

## The ability to free; null = every ability of the unit.
var ability: AbilityAsset = null
var on: int = StepTarget.Self
## Empty: a full reset (held cooldowns included). A number: shortens turn cooldowns by that much.
## [Slot("OnHit", optional: true)]
var turns: Formula = Formula.new()

func to_core(c: AssetConverter) -> Step:
	var s := ResetCooldownStep.new()
	s.ability = c.ability(ability) if ability != null else null
	s.on = on
	s.turns = turns
	return s
