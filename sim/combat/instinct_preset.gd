class_name InstinctPreset
extends RefCounted
## The ready-made instincts (Instinct — Design, Preferences). Default = chosen from the ability's targeting; Ahead = furthest along the chooser's own path; Engage = movement toward where the follow-up attack can hit the unit its instinct likes best.

const Default := 0
const Nearest := 1
const Farthest := 2
const First := 3
const Last := 4
const Weakest := 5
const Strongest := 6
const MostHurt := 7
const MostHit := 8
const Random := 9
const FarthestStep := 10
const FirstValid := 11
const Custom := 12
const Ahead := 13
const Engage := 14

const NAMES := ["Default", "Nearest", "Farthest", "First", "Last", "Weakest", "Strongest", "MostHurt", "MostHit", "Random", "FarthestStep", "FirstValid", "Custom", "Ahead", "Engage"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
