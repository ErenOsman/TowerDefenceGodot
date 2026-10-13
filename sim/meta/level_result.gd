class_name LevelResult
extends RefCounted
## How one play of a level ended, reported by the level when its session ends.

var level_id: String = ""
var won: bool = false
## Left through the pause menu: counts as an attempt only, never as a loss record.
var quit: bool = false
## Base HP left at the end, as a percentage of all bases' max HP together (0–100).
var base_hp_pct: int = 0
var rounds: int = 0
var towers_lost: int = 0
## When it was played (ISO 8601); the level fills it in.
var when: String = ""
