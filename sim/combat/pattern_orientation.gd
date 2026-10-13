class_name PatternOrientation
extends RefCounted
## C# Orientation (renamed: Godot owns Orientation). Fixed: as authored. TowardTarget: rotated toward the aim. Facing: rotated to the caster's facing.

const Fixed := 0
const TowardTarget := 1
const Facing := 2

const NAMES := ["Fixed", "TowardTarget", "Facing"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
