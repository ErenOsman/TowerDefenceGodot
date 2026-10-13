class_name CasterAnimation
extends RefCounted
## Which Animator trigger the caster plays for an ability (Animation & Presentation — Design).
## Default: Cast for abilities tagged Spell, Attack for the rest. Custom: the trigger named in customTrigger.

const Default := 0
const Attack := 1
const Cast := 2
const Custom := 3
const None := 4

const NAMES := ["Default", "Attack", "Cast", "Custom", "None"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
