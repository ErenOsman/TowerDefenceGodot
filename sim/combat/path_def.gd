class_name PathDef
extends RefCounted
## One enemy route: tiles in walking order. A branching route is authored as separate paths that
## share their first tiles; two paths that share a tile cross there. Consecutive tiles that do not
## share an edge form a gap, which walking cannot cross. A path may pass a tile twice (a loop), so a
## unit's place on it is its step (Entity.path_step), not its tile.

var id: int = 0
## Array of Vector2i.
var tiles: Array = []

## The tile's first index on this path, or -1.
func index_of(p: Vector2i) -> int:
	return tiles.find(p)

func contains(p: Vector2i) -> bool:
	return tiles.has(p)

## The visit of a tile nearest a step (ties: the later one): where a unit at step `near`
## that is now on `p` stands on a looping path. near < 0 gives the first visit; -1 off the path.
func visit_near(p: Vector2i, near: int) -> int:
	if near < 0: return index_of(p)
	var best := -1
	var best_distance := 2147483647
	for i in tiles.size():
		if tiles[i] != p: continue
		var d := absi(i - near)
		if d <= best_distance:
			best = i
			best_distance = d
	return best

## The way the path goes at a step: towards the next tile (from the last tile, the way it came).
## NONE out of range or when the path has a single tile.
func direction_at_step(i: int) -> Vector2i:
	if i < 0 or i >= tiles.size() or tiles.size() < 2: return Dirs.NONE
	return Dirs.cardinal_between(tiles[i], tiles[i + 1]) if i + 1 < tiles.size() else Dirs.cardinal_between(tiles[i - 1], tiles[i])

## The way the path goes at a tile's first visit (see direction_at_step).
func direction_at(p: Vector2i) -> Vector2i:
	return direction_at_step(index_of(p))

## True when tile i can be walked to from tile i - 1 (they share an edge).
func is_step(i: int) -> bool:
	return i > 0 and i < tiles.size() and Dirs.manhattan(tiles[i - 1], tiles[i]) == 1
