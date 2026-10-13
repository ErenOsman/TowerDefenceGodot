class_name SpawnStep
extends Step
## Creates an entity from a definition. A summon takes its summoner's effective team; other
## spawns take the team given, or the step owner's. Occupied tiles: nearest free within 1, else fizzle.

var entity: EntityDef
var at: int = SpawnAt.AimTile

## The step owner becomes the Summoner (dieWithSummoner applies). Otherwise CreatedBy is set.
var summon: bool = true

## -1 = the owner's effective team.
var team: int = -1

func expand(c: StepContext) -> Array:
	var tile: Vector2i
	match at:
		SpawnAt.Self: tile = c.self_.pos
		SpawnAt.Target:
			if c.target == null: return []
			tile = c.target.pos
		_:
			if c.aim == null: return []
			tile = c.aim.tile
	var e := SpawnEffect.new()
	e.def = entity
	e.tile = tile
	e.summon = summon
	e.team = team
	e.owner = c.self_.id
	return [c.init(e)]
