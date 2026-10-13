class_name SequenceEvent
extends RefCounted
## Game events a line can wait for. New values go at the end: assets store them as numbers.

const TowerPlaced := 0
const UnitSelected := 1
const AbilityCast := 2
const QuickCast := 3
const RoundEnded := 4
const WaveCleared := 5
const LevelWon := 6
const TowerMoved := 7
const EnemyInRange := 8
const SelectionCleared := 9
const WaveArrived := 10

const NAMES := ["TowerPlaced", "UnitSelected", "AbilityCast", "QuickCast", "RoundEnded", "WaveCleared", "LevelWon", "TowerMoved", "EnemyInRange", "SelectionCleared", "WaveArrived"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
