class_name WaveData
extends RefCounted
## One wave of a level: when it starts, its spawns and its scripted events.

var name: String = ""
var start: int = WaveStart.AtRound
## AtRound: the level round the wave starts in.
var start_round: int = 1
## AfterWave: the index of the wave that must finish first.
var after_wave: int = -1
## Rounds count from the wave's start: 1 = the round it starts. Array of SpawnData.
var spawns: Array = []
## Array of LevelEventData.
var events: Array = []
