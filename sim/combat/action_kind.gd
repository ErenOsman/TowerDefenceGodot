class_name ActionKind
extends RefCounted
## What an action is, for presentation (Skip finishes one action) and the combat log.
## Command: a command run without a surrounding action (tests, tools). TowersTurnStart: every placed tower's
## TurnStarted at the start of the player phase, as one action. TowersTurnEnd: every placed tower's TurnEnded
## at End round. Phase: a round or phase starting (banner).

const Command := 0
const Cast := 1
const Place := 2
const Sell := 3
const TowersTurnStart := 4
const TowersTurnEnd := 5
const EnemyTurn := 6
const Phase := 7
const Wave := 8
const Spawn := 9
const LevelEvent := 10
const Income := 11
const RoundEnd := 12
const LevelEnd := 13

const NAMES := ["Command", "Cast", "Place", "Sell", "TowersTurnStart", "TowersTurnEnd", "EnemyTurn", "Phase", "Wave", "Spawn", "LevelEvent", "Income", "RoundEnd", "LevelEnd"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
