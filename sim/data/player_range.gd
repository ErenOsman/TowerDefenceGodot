class_name PlayerRange
extends RefCounted
## A co-op mission's player count (Missions & Guild — Design, MissionAsset.players: `{ "min": 2, "max": 4 }`):
## the room's count is clamped to it.

var min: int = 1
var max: int = 1
