class_name StepTarget
extends RefCounted
## Which entity a step acts on. Target: the chain target in an attack; the event's target in a reaction.
## Self: the step's owner (the caster, or the reaction's owner). EventSource: in a reaction, the triggering
## event's source (e.g. the attacker, for Thorns). EventTarget: in a reaction, the triggering event's target.

const Target := 0
const Self := 1
const EventSource := 2
const EventTarget := 3

const NAMES := ["Target", "Self", "EventSource", "EventTarget"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
