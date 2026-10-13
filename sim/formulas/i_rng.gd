class_name IRng
extends RefCounted
## Seeded, integer-based random source. The only source of randomness in the simulation.
## Interface: implementers extend this and override every method.

## A uint in [0, 2^32).
func next_uint() -> int:
	push_error("abstract")
	return 0

## A value in [0, 1) as an exact Num.
func next_unit() -> float:
	push_error("abstract")
	return 0.0

## True with probability p (p <= 0 never, p >= 1 always). Always draws exactly once.
func chance(p: float) -> bool:
	push_error("abstract")
	return false

func clone() -> IRng:
	push_error("abstract")
	return null
