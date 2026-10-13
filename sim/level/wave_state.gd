class_name WaveState
extends RefCounted
## A wave's runtime state. Wave rounds count from 1 in the round the wave starts.

var def: WaveDef = null
var index: int = 0
## The level round the wave started in; -1 while waiting for its start condition.
var start_round: int = -1
var finished: bool = false

var started: bool:
	get: return start_round >= 0

func wave_round(round: int) -> int: return round - start_round + 1
