class_name XorShiftRng
extends IRng
## xorshift64* generator. Project-owned so the sequence never changes with the engine version.
## The C# state is a ulong; here it is the same 64 bits in a wrapping signed int (logical right
## shifts are emulated by masking the arithmetic shift).

## 0x9E3779B97F4A7C15 as a signed 64-bit int (used when the seed is 0).
const ZERO_SEED := -7046029254386353131

var state: int

func _init(p_seed: int = 1) -> void:
	state = ZERO_SEED if p_seed == 0 else p_seed

func next_uint() -> int:
	state ^= (state >> 12) & 0xFFFFFFFFFFFFF
	state ^= state << 25
	state ^= (state >> 27) & 0x1FFFFFFFFF
	return ((state * 0x2545F4914F6CDD1D) >> 32) & 0xFFFFFFFF

func next_unit() -> float:
	return Num.fix(float(next_uint()) / 4294967296.0)

func chance(p: float) -> bool:
	return next_unit() < p

func clone() -> IRng:
	var r := XorShiftRng.new(1)
	r.state = state
	return r
