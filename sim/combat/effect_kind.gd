class_name EffectKind
extends RefCounted
## The kind of effect a ReplacementRule matches.

const Damage := 0
const Heal := 1
const ApplyStatus := 2
const RemoveStatus := 3
const Step := 4
const Push := 5
const Teleport := 6
const CastAbility := 7
const Spawn := 8
const Resurrect := 9
const Remove := 10
const Other := 11

const NAMES := ["Damage", "Heal", "ApplyStatus", "RemoveStatus", "Step", "Push", "Teleport", "CastAbility", "Spawn", "Resurrect", "Remove", "Other"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
