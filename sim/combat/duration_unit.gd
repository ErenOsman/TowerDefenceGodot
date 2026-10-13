class_name DurationUnit
extends RefCounted
## Whether a duration counts the owner's turns (at its TurnEnded) or rounds (at RoundEnded).

const Turns := 0
const Rounds := 1

const NAMES := ["Turns", "Rounds"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
