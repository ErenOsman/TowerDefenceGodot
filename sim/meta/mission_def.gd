class_name MissionDef
extends RefCounted
## A mission, engine-free (Missions & Guild — Design): the converter builds it from a MissionAsset
## (AssetConverter.mission). The rules on it live in MissionBoard.

## Stable ID (saves key on it), e.g. "night-watch".
var id: String = ""
## The name players see ("Night Watch").
var name: String = ""
var description: String = ""
## A Unity sprite path ("" for none).
var icon: String = ""
## The id of the level it plays ("" when the asset has none).
var level_id: String = ""
## MissionMode.
var mode: int = MissionMode.Solo
## Co-op player range (Coop / Any).
var min_players: int = 1
var max_players: int = 1
var plays_per_day: int = 1
## Level ids and mission ids that must be won first (empty = open with the Guild).
var requires: Array = []
var require_all: bool = true
var shared_pool: bool = false
var coop_hand_cap: int = 3
## {token id: amount} given once, with the first win.
var first_win_tokens: Dictionary = {}
## {token id: amount} given on every win.
var win_tokens: Dictionary = {}
## Gold given once, with the first win (the only gold source with win_gold; Upgrades — Design § Gold).
var first_win_gold: int = 0
## Gold given on every win.
var win_gold: int = 0

## Playable in a co-op room (Coop or Any).
var is_coop: bool:
	get: return mode == MissionMode.Coop or mode == MissionMode.Any

## Playable alone from the mission board (Solo or Any).
var is_solo: bool:
	get: return mode == MissionMode.Solo or mode == MissionMode.Any

## A room's player count clamped to the mission's range (1–6 at most).
func clamp_players(count: int) -> int:
	return clampi(count, maxi(1, min_players), clampi(max_players, maxi(1, min_players), 6))

## Whether a token drops from it (first win or every win).
func drops_token(token_id: String) -> bool:
	return first_win_tokens.has(token_id) or win_tokens.has(token_id)
