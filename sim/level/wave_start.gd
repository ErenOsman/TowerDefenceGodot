class_name WaveStart
extends RefCounted
## When a wave starts: AtRound (level phase of round startRound) or AfterWave (first level phase after wave afterWave is finished).

const AtRound := 0
const AfterWave := 1

const NAMES := ["AtRound", "AfterWave"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
