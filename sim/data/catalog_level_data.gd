class_name CatalogLevelData
extends RefCounted
## One level in the catalog and what opens it.

var level: LevelAsset = null
## Previous: the entry before it must be won (the default). Open: from the start. Levels: the listed levels.
var requirement: int = RequirementKind.Previous
## Levels: these must be won first. Array of LevelAsset.
var requires: Array = []
## Levels: all of them (on) or any one (off).
var require_all: bool = true
## Given once, the first time the level is won: a new tower of this type. Null: none.
var first_clear_reward: TowerAsset = null
## Workshop: tokens given once, with the first win. Array of TokenAmount.
var first_win_tokens: Array = []
## Workshop: tokens given on every win. Array of TokenAmount.
var win_tokens: Array = []
