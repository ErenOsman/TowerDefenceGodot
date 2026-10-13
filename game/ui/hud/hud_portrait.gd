class_name HudPortrait
extends Control
## A picture drawn inside a circle (a textured polygon, no mask node: clip_children does not render here), covering
## the circle like STRETCH_KEEP_ASPECT_COVERED, on a dark backing. `focus_y` moves the crop up or down (0 = centre,
## negative shows more of the top, for head-and-shoulders busts).

@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
@export var focus_y := -0.12
@export var backing := Color(0.17, 0.13, 0.1, 1.0)

const SEGMENTS := 48

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## The UV rect (0..1) of the texture a square crop covers: the shorter side fills, centred, shifted by focus_y.
static func cover_uv(tex_size: Vector2, focus := 0.0) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0: return Rect2(0, 0, 1, 1)
	if tex_size.x >= tex_size.y:
		var w := tex_size.y / tex_size.x
		return Rect2((1.0 - w) / 2.0, 0.0, w, 1.0)
	var h := tex_size.x / tex_size.y
	var y := clampf((1.0 - h) / 2.0 + focus * (1.0 - h), 0.0, 1.0 - h)
	return Rect2(0.0, y, 1.0, h)

func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var uv := cover_uv(texture.get_size() if texture != null else Vector2.ONE, focus_y)
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(uv.position + (d * 0.5 + Vector2(0.5, 0.5)) * uv.size)
	draw_colored_polygon(pts, backing)
	if texture != null: draw_colored_polygon(pts, Color.WHITE, uvs, texture)
