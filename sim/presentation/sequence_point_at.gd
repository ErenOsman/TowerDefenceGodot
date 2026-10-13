class_name SequencePointAt
extends RefCounted
## What a line's speech bubble points at: Speaker, Nothing, FirstEnemy, FirstTower, Tile (tileX, tileY), UI (uiElement), Center, Subject.

const Speaker := 0
const Nothing := 1
const FirstEnemy := 2
const FirstTower := 3
const Tile := 4
const UI := 5
const Center := 6
const Subject := 7

const NAMES := ["Speaker", "Nothing", "FirstEnemy", "FirstTower", "Tile", "UI", "Center", "Subject"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
