class_name WaveDef
extends RefCounted
## One wave of a level: when it starts, its spawns and its LevelEvents.

var name: String = ""
var start: int = WaveStart.AtRound
var start_round: int = 1
var after_wave: int = -1
var spawns: Array = []  # of SpawnEntry
var events: Array = []  # of LevelEventDef

## The last wave round with a spawn or a LevelEvent.
var last_scheduled_round: int:
	get:
		var last := 1
		for s in spawns:
			if s.round > last: last = s.round
		for e in events:
			if e.round > last: last = e.round
		return last
