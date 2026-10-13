class_name Num
extends RefCounted
## The simulation's number type, ported from Game.Formulas.Num (a decimal wrapper in C#).
## In GDScript a Num IS a float: pass floats around, never Num objects. These static helpers give the
## decimal semantics: every arithmetic result goes through Num.fix() so 0.1 + 0.2 == 0.3 holds,
## division/modulo by zero give 0, modulo is floored, Round() rounds half away from zero, booleans are 1/0.
## Keep ints out: a stat value is a float (2.0); int(x) only when the C# did FloorToInt.

const EPS := 1e-9

## Snap to 9 decimals: removes binary drift so decimal-exact values stay comparable with ==.
static func fix(x: float) -> float:
	if absf(x) > 1e6: return roundf(x * 1000.0) / 1000.0
	return roundf(x * 1e9) / 1e9

static func add(a: float, b: float) -> float: return fix(a + b)
static func sub(a: float, b: float) -> float: return fix(a - b)
static func mul(a: float, b: float) -> float: return fix(a * b)

## Division by zero returns 0 (the Div node reports it).
static func div(a: float, b: float) -> float:
	if b == 0.0: return 0.0
	return fix(a / b)

## Floored modulo: the sign of the divisor (-1 % 3 = 2). Modulo by zero returns 0.
static func mod(a: float, b: float) -> float:
	if b == 0.0: return 0.0
	var r := fmod(a, b)
	if r != 0.0 and ((r < 0.0) != (b < 0.0)): r += b
	return fix(r)

static func bool_num(b: bool) -> float: return 1.0 if b else 0.0
static func is_true(x: float) -> bool: return x != 0.0

static func parse(s: String) -> float:
	return fix(float(s.strip_edges()))

static func is_numeric(s: String) -> bool:
	return s.strip_edges().is_valid_float()

static func min_of(a: float, b: float) -> float: return a if a <= b else b
static func max_of(a: float, b: float) -> float: return a if a >= b else b
static func clamp_of(x: float, lo: float, hi: float) -> float: return max_of(lo, min_of(hi, x))

static func floor_of(x: float) -> float: return floorf(x)

## Round half away from zero (decimal.Round MidpointRounding.AwayFromZero).
static func round_of(x: float) -> float:
	return floorf(x + 0.5) if x >= 0.0 else -floorf(-x + 0.5)

static func floor_to_int(x: float) -> int: return int(floorf(x))

static func eq(a: float, b: float) -> bool: return absf(a - b) < EPS

## Invariant text, trailing zeros trimmed: 211.2, 120, 0.05 (C# Num.ToString()).
static func to_str(x: float) -> String:
	x = fix(x)
	if x == floorf(x) and absf(x) < 1e15:
		return str(int(x))
	var s := "%.9f" % x
	s = s.rstrip("0")
	if s.ends_with("."): s = s.substr(0, s.length() - 1)
	return s
