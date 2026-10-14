class_name MissionAsset
extends ContentAsset
## A mission (Missions & Guild — Design, Content/Missions.json): a level played from the Guild a limited number of
## times a day, alone and/or in a co-op room, dropping Workshop tokens. Godot-first: res://data/content-godot until
## the Unity repo has Missions.json (see docs/GODOT-NOTES.md).

## Stable mission ID, saved (MissionProgress records, plays), e.g. "night-watch". Empty falls back to the asset name.
var id: String = ""
var display_name: String = ""
var description: String = ""
## A Unity sprite path ("" for none yet).
var icon: String = ""
## The level it plays (a chapter level reused, or one made for the mission).
var level: LevelAsset = null
## MissionMode: Solo / Coop / Any.
var mode: int = MissionMode.Solo
## Coop / Any: how many players a room may have (1–6). Null = 1–1.
var players: PlayerRange = null
## How many times a day it can be played (a play is spent at start; the count resets at local midnight).
var plays_per_day: int = 1
## LevelAssets / MissionAssets that must be won first (empty = open with the Guild): Array of ContentAsset.
var requires: Array = []
## requires: all of them (on) or any one (off).
var require_all: bool = true
## Co-op: one shared energy pool (on) or one pool per player (Multiplayer — Design).
var shared_pool: bool = false
## Co-op: how many towers each player brings.
var coop_hand_cap: int = 3
## Tokens given once, with the first win of this mission: Array of TokenAmount.
var first_win_tokens: Array = []
## Tokens given on every win: Array of TokenAmount.
var win_tokens: Array = []

## The id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

## The display name, else the asset name.
func get_display_name() -> String:
	return name if display_name.is_empty() else display_name
