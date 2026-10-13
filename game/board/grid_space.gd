class_name GridSpace
extends RefCounted
## Grid ↔ world (BoardView.cs GridSpace). Tile (x, y) sits at world (x, 0, −y), one unit per tile: x grows east
## (+X), the board's north (+y, the level text's top row) is −Z, so the camera's default view looks north like
## Unity's. Unity put the tile at (x, 0, y) in a left-handed world; this is the same board seen the same way.
##
## The FBX models (units and map-kit pieces) import with their front (Blender −Y = the map's north at rest)
## along Godot +Z, i.e. turned half a turn from this board frame; piece_yaw/facing_yaw add that half turn.
## Godot's Y rotation is counter-clockwise seen from above; the kit's turns (TileLook) are clockwise.

## The world point of a tile (its centre on the ground, raised by height).
static func to_world(p: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(p.x, height, -p.y)

## The tile a world point lies on (rounded to the nearest centre).
static func to_tile(w: Vector3) -> Vector2i:
	return Vector2i(roundi(w.x), roundi(-w.z))

## The world direction of a board direction (dx, dy with +y north), on the ground plane.
static func to_world_dir(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0.0, -d.y)

## The point on the ground plane (y = height) under a screen point (canvas / viewport coordinates, as
## Viewport.get_mouse_position and Camera3D.unproject_position use), or null (it misses the plane).
## Camera3D.project_ray_* ignore a frustum projection's offset (Godot computes the ray from symmetric half
## extents), and the board camera is off-centre, so their hit is only the first guess: it is then corrected until
## unproject_position(hit) lands on the screen point (Newton steps on the plane, 2×2 Jacobian by finite
## differences). unproject_position handles the offset, the stretch and an embedded window, so picking matches
## what is drawn.
static func ground_under(cam: Camera3D, screen: Vector2, height: float = 0.0) -> Variant:
	if cam == null or not cam.is_inside_tree(): return null
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 1e-5: return null
	var t := (height - origin.y) / dir.y
	if t < 0.0: return null
	var g := origin + dir * t
	for i in 6:
		if cam.is_position_behind(g): return null
		var at := cam.unproject_position(g)
		var e := screen - at
		if e.length_squared() < 0.0025: break
		var h := 0.01
		var jx := (cam.unproject_position(g + Vector3(h, 0, 0)) - at) / h
		var jz := (cam.unproject_position(g + Vector3(0, 0, h)) - at) / h
		var det := jx.x * jz.y - jz.x * jx.y
		if absf(det) < 1e-9: break
		var a := (e.x * jz.y - jz.x * e.y) / det
		var b := (jx.x * e.y - e.x * jx.y) / det
		var step := Vector3(a, 0.0, b)
		if step.length() > 50.0: return null # toward the horizon: the pointer is above it
		g += step
	return g

## The tile under a screen point (a ray onto the ground plane), or null when it misses the board.
static func tile_under(cam: Camera3D, screen: Vector2, grid) -> Variant:
	var hit = ground_under(cam, screen)
	if hit == null: return null
	var p := to_tile(hit)
	if grid != null and not grid.in_bounds(p): return null
	return p

## The Y rotation (radians) of a map-kit piece turned `turns` quarter turns clockwise seen from above (TileLook):
## the piece's rest front (+Z after import) is the map's north, so turn 0 is half a turn.
static func piece_yaw(turns: int) -> float:
	return wrapf(PI - float(posmod(turns, 4)) * PI * 0.5, -PI, PI)

## The Y rotation (radians) that turns a model (front along +Z after import) to face a board direction.
## (0, 0) keeps nothing to say: callers skip Dirs.NONE.
static func facing_yaw(d: Vector2i) -> float:
	return atan2(float(d.x), float(-d.y))

## The Y rotation (radians) that turns a model at `from` to face the world point `to` (ground plane), or null
## when they are on the same spot.
static func look_yaw(from: Vector3, to: Vector3) -> Variant:
	var dx := to.x - from.x
	var dz := to.z - from.z
	if dx * dx + dz * dz < 0.000001: return null
	return atan2(dx, dz)

## A decal's Y rotation for a chevron turned by Unity yaw degrees (0: its top points north, clockwise).
## The decal quad's texture top points to −Z (north) at 0.
static func decal_yaw(unity_degrees: float) -> float:
	return -deg_to_rad(unity_degrees)
