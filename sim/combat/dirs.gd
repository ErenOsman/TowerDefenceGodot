class_name Dirs
extends RefCounted
## Helpers for the C# Pos and Dir structs, which are both Vector2i in the port (see PORT.md Types).
## A Dir is a unit step: each component is -1, 0 or 1. Dir.dx/dy → .x/.y; Dir.Reverse → Dirs.reverse(d) (= -d);
## Pos + Dir → p + d. Pos.Manhattan/Chebyshev and the C# ToString forms are here too.

## Dir.None.
const NONE := Vector2i.ZERO

## Dir.IsNone.
static func is_none(d: Vector2i) -> bool:
	return d.x == 0 and d.y == 0

## The 8-way direction from a to b (sign of each axis).
static func between(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(signi(b.x - a.x), signi(b.y - a.y))

## The 4-way direction from a to b along the dominant axis (ties prefer x).
static func cardinal_between(a: Vector2i, b: Vector2i) -> Vector2i:
	var ddx := b.x - a.x
	var ddy := b.y - a.y
	if ddx == 0 and ddy == 0: return NONE
	return Vector2i(signi(ddx), 0) if absi(ddx) >= absi(ddy) else Vector2i(0, signi(ddy))

## Dir.Reverse.
static func reverse(d: Vector2i) -> Vector2i:
	return Vector2i(-d.x, -d.y)

## Pos.Manhattan.
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## Pos.Chebyshev.
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

## Pos.ToString: "(x,y)" (Godot's str() of a Vector2i has a space, so logs use this).
static func pos_str(p: Vector2i) -> String:
	return "(%d,%d)" % [p.x, p.y]

## Dir.ToString: "<dx,dy>".
static func dir_str(d: Vector2i) -> String:
	return "<%d,%d>" % [d.x, d.y]
