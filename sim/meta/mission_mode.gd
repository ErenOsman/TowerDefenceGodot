class_name MissionMode
extends RefCounted
## How a mission is played (Missions & Guild — Design, MissionAsset.mode): Solo from the mission board, Coop in a
## room only (with a player range), or Any (alone from the board or in a room). Godot-first (see GODOT-NOTES.md).

const Solo := 0
const Coop := 1
const Any := 2

const NAMES := ["Solo", "Coop", "Any"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
