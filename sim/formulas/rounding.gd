class_name Rounding
extends RefCounted

static func apply(v: float, r: int) -> float:
	match r:
		Round.Floor: return Num.floor_of(Num.fix(v))
		Round.FloorMin0: return Num.max_of(0.0, Num.floor_of(Num.fix(v)))
		Round.Nearest: return Num.round_of(Num.fix(v))
		_: return v
