class_name SpawnStepData
extends StepData

var entity: EntityAsset = null
var at: int = SpawnAt.AimTile
## The owner becomes the Summoner (team copied, dieWithSummoner applies).
var summon: bool = true
## Not a summon: -1 = the owner's team.
var team: int = -1

func to_core(c: AssetConverter) -> Step:
	var s := SpawnStep.new()
	s.entity = c.entity(entity)
	s.at = at
	s.summon = summon
	s.team = team
	return s
