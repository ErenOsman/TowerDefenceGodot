class_name Phase
extends RefCounted
## The phase of a level round.

const NotStarted := 0
const Player := 1
const Enemy := 2
const Level := 3
const Over := 4

const NAMES := ["NotStarted", "Player", "Enemy", "Level", "Over"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
