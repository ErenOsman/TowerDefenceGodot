class_name LevelRecord
extends RefCounted
## Everything saved about one level. Not shown to the player yet (Level Select — Design): the
## facts are kept so stars or stats can be added later without replays.

var level_id: String = ""
var attempts: int = 0
var wins: int = 0
var won: bool = false
## Best values over wins; -1 until the first win.
var best_base_hp_pct: int = -1
var fewest_rounds: int = -1
var fewest_towers_lost: int = -1
var last_played: String = ""
