class_name LevelBonusData
extends RefCounted
## One stat bonus a level gives (Upgrades — Design § Data): `{ "stat": "Power", "kind": "Flat", "amount": "2" }`.
## kind Flat adds the amount; PctAdd adds a fraction (0.1 = +10 %) of the stat after the flat bonuses.

var stat: String = ""
var kind: int = ModKind.Flat
## A number as text ("2", "0.1").
var amount: String = "0"
