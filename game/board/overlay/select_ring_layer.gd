class_name SelectRingLayer
extends Control
## The cobalt selection ring as a TRUE circle on screen (Eren 2026-10-15: the ground decal was squashed into an
## ellipse by the perspective). Each ring is centred on the unit's projected foot point; its radius is the tile's
## size on screen there (half a tile measured along the camera's right on the ground, × RADIUS_TILES), so it zooms
## with the board like the decal did. The look is the kit decal's (board/decal_select_ring): a dark outline, the
## light cobalt band, a dark inner outline and a faint cobalt fill, the widths in tile units as on the decal.
## Strength scales the alpha (1 = selected, 0.5 = a tower lit from its tray piece). Drawn under the plates; never
## takes the pointer. Aim / range / hover tile markers stay ground decals (they belong to tiles).

## The ring's outer edge from the unit's centre, in tiles (the decal: 1.15 tiles wide, its outline 8/256 in).
const RADIUS_TILES := 0.54
## Outline, band, outline widths in tiles (the decal's 5 / 10 / 5 px of 256 over 1.15 tiles).
const OUTLINE_TILES := 0.0225
const BAND_TILES := 0.045
const OUTLINE_COLOR := Color8(18, 12, 9)
const BAND_COLOR := Color8(141, 187, 255)
const FILL_COLOR := Color8(78, 144, 233, 46)

var cam: Camera3D = null
var _rings: Array = []    # [world Vector3, strength float]
var _drawn: Array = []    # [centre Vector2, radius px, strength]

func _init() -> void:
	name = "Select Rings"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Starts this frame's rings (the controller sets them each frame it draws its highlights).
func clear_rings() -> void:
	_rings.clear()

## A ring round the unit standing at `world` (its feet).
func add_ring(world: Vector3, strength: float = 1.0) -> void:
	_rings.append([world, strength])

## The rings set now: [world, strength] pairs (tests).
var rings: Array:
	get: return _rings

## Projects the rings after the camera moved (BattleOverlay.refresh).
func tick() -> void:
	_drawn.clear()
	if cam != null:
		for r in _rings:
			var c = SelectRingLayer.screen_circle(cam, r[0])
			if c != null: _drawn.append([c[0], c[1], r[1]])
	queue_redraw()

## The on-screen circle round a foot point: [centre Vector2, radius px] or null (behind the camera).
static func screen_circle(camera: Camera3D, world: Vector3):
	if camera.is_position_behind(world): return null
	return [camera.unproject_position(world), RADIUS_TILES * SelectRingLayer.px_per_tile(camera, world)]

## A tile's width on screen at a ground point (px), measured along the camera's right on the ground: the same in
## every direction on screen, so a circle of a radius from it stays round.
static func px_per_tile(camera: Camera3D, world: Vector3) -> float:
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized() if right.length() > 0.001 else Vector3.RIGHT
	return (camera.unproject_position(world + right * 0.5) - camera.unproject_position(world - right * 0.5)).length()

func _draw() -> void:
	for d in _drawn:
		var c: Vector2 = d[0]
		var r: float = d[1]
		var k: float = d[2]
		var tile := r / RADIUS_TILES
		var o := maxf(1.5, OUTLINE_TILES * tile)
		var b := maxf(2.0, BAND_TILES * tile)
		draw_circle(c, r - o * 2.0 - b, Color(FILL_COLOR, FILL_COLOR.a * k), true, -1.0, true)
		draw_arc(c, r - o * 0.5, 0.0, TAU, 96, Color(OUTLINE_COLOR, k), o, true)
		draw_arc(c, r - o - b * 0.5, 0.0, TAU, 96, Color(BAND_COLOR, k), b, true)
		draw_arc(c, r - o * 1.5 - b, 0.0, TAU, 96, Color(OUTLINE_COLOR, k), o, true)
