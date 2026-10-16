class_name ChanceDrop
extends RefCounted
## A token a mission may drop on a win with a chance (Missions & Guild — Design § Data, `chanceDrops`):
## `{ "token": "Token/Ember Core", "chance": 0.3 }`, 0 < chance ≤ 1. Listed in the Rewards popup; not rolled yet.

var token: TokenAsset = null
var chance: float = 0.0
