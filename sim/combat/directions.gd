class_name Directions
extends RefCounted
## CardinalDirection helpers.

## CardinalDirection.ToDir: Up is +y, Down -y, Left -x, Right +x.
static func to_dir(d: int) -> Vector2i:
	if d == CardinalDirection.Up: return Vector2i(0, 1)
	if d == CardinalDirection.Down: return Vector2i(0, -1)
	if d == CardinalDirection.Left: return Vector2i(-1, 0)
	return Vector2i(1, 0)
