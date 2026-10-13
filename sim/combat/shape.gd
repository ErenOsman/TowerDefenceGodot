class_name Shape
extends RefCounted
## Single is the centre tile only; Steps and PathAhead are movement shapes measured from the caster; Ray is a straight shot at any angle stopped by the first wall or blocker. New shapes go at the end: assets store the shape as a number.

const Diamond := 0
const Square := 1
const Circle := 2
const Plus := 3
const Diagonal := 4
const Line := 5
const Cone := 6
const Custom := 7
const Steps := 8
const PathAhead := 9
const Single := 10
const Ray := 11

const NAMES := ["Diamond", "Square", "Circle", "Plus", "Diagonal", "Line", "Cone", "Custom", "Steps", "PathAhead", "Single", "Ray"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
