class_name TowerTaskKind
extends RefCounted
## What a tower level task counts (Upgrades — Design § Data): missions won with the tower in the hand, levels won
## with it, one named mission won with it, kills by it, damage dealt by it, hits it took and survived, times it was
## placed, and wins without losing a tower. Godot-first (no C# counterpart).

const WinMission := 0
const WinLevel := 1
const WinMissionId := 2
const Kills := 3
const Damage := 4
const HitsTaken := 5
const Placed := 6
const WinNoLoss := 7

const NAMES := ["WinMission", "WinLevel", "WinMissionId", "Kills", "Damage", "HitsTaken", "Placed", "WinNoLoss"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
