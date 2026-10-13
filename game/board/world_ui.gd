class_name WorldUi
extends RefCounted
## The one rule for UI drawn over the board (WorldUi.cs; UI Design Rules, "UI over the board"): it follows its
## unit on screen and scales with the zoom where it stands, measured as a tile's on-screen width there against
## its width at the default framing. Parts that must fit the board (a compact plate) use fit(); parts with text
## use readable(), which never goes below the designed size. Overlay coordinates are the canvas's (the
## 1920×1080 reference under the canvas_items stretch), which is what Camera3D.unproject_position returns.

## A tile's on-screen width at the level's default framing, in canvas units (measured by BoardCamera for each
## board; 104 until then).
static var reference_tile: float = 104.0

## The largest a board UI part grows when zoomed in.
const MAX_SCALE := 2.5

## A tile's width on screen at a world point, in canvas units.
static func tile_width(cam: Camera3D, at: Vector3) -> float:
	if cam == null or not cam.is_inside_tree(): return reference_tile
	var across := cam.global_transform.basis.x
	across.y = 0.0
	across = across.normalized() * 0.5 if across.length_squared() > 0.0001 else Vector3.RIGHT * 0.5
	if cam.is_position_behind(at): return reference_tile
	return cam.unproject_position(at - across).distance_to(cam.unproject_position(at + across))

## The zoom at a world point: 1 at the default framing, more when zoomed in.
static func zoom(cam: Camera3D, at: Vector3) -> float:
	return tile_width(cam, at) / maxf(1.0, reference_tile)

## The scale for parts that must fit the board: they shrink when zoomed out (up to MAX_SCALE zoomed in).
static func fit(z: float) -> float:
	return minf(z, MAX_SCALE)

## The scale for parts with text or numbers: never below the designed size, up to MAX_SCALE.
static func readable(z: float) -> float:
	return clampf(z, 1.0, MAX_SCALE)
