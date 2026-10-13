class_name LevelEventKind
extends RefCounted
## What a scripted LevelEvent does.

const SpawnEnemies := 0
const GiveEnergy := 1
const ShowMessage := 2
const ChangeTerrain := 3

const NAMES := ["SpawnEnemies", "GiveEnergy", "ShowMessage", "ChangeTerrain"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
