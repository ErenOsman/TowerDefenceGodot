class_name RouteBuilder
extends RefCounted
## Builds a movement route from the pointer, as in Fire Emblem: hovering shows the shortest route;
## moving onto a tile next to the route's end extends the route through it (within the budget), so
## the player picks the way; moving back onto the route cuts it there; anything else falls back to
## the shortest route. Engine-free: the editor playtester and the game UI both use it.
## Construct with RouteBuilder.new(state, mover, ability). C# Start/Min/Max → start/min/max (read-only by convention).

var start: Vector2i
var min: int
var max: int

## Tiles reachable with this ability, with their shortest routes (excluding the start): Vector2i → Array.
var shortest: Dictionary = {}

var _state: GameState
var _mover: Entity
var _path: Array = []

## The current route (excluding the start); its last tile is the destination. (A copy: read-only.)
var path: Array:
	get: return _path.duplicate()

## The last tile of the route, or null.
var destination: Variant:
	get: return _path[_path.size() - 1] if not _path.is_empty() else null

## A route for this ability: Steps shapes only (PathAhead routes are fixed by the path).
func _init(p_state: GameState, p_mover: Entity, ability: AbilityDef) -> void:
	_state = p_state
	_mover = p_mover
	start = p_mover.pos
	var rr := Targeting.radii(p_state, p_mover, ability.targeting, Tags.set_of(ability.tags))
	min = rr[0]
	max = rr[1]
	for tr in Targeting.routes(p_state, p_mover, ability.targeting, start, min, max):
		shortest[tr[0]] = tr[1]

func can_reach(tile: Vector2i) -> bool:
	return shortest.has(tile)

## Updates the route for the tile under the pointer.
func hover(tile: Vector2i) -> void:
	if tile == start:
		_path.clear()
		return

	var on_path := _path.find(tile)
	if on_path >= 0:
		_path.resize(on_path + 1)
		return

	var end: Vector2i = _path[_path.size() - 1] if not _path.is_empty() else start
	if absi(end.x - tile.x) + absi(end.y - tile.y) == 1 and _path.size() + 1 <= max and _state.can_enter(_mover, tile):
		_path.append(tile)
		return

	if shortest.has(tile):
		_path.clear()
		_path.append_array(shortest[tile])
	# an unreachable tile keeps the current route

## The aim to cast with, or null if the route is not a valid destination (e.g. shorter than the minimum).
func to_aim() -> Aim:
	if _path.size() < maxi(1, min): return null
	var to: Vector2i = _path[_path.size() - 1]
	var aim := Aim.new(to, Dirs.between(start, to))
	aim.path = _path.duplicate()
	return aim
