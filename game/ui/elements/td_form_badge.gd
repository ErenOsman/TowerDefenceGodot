class_name TdFormBadge
extends Control
## A tower form's badge (Workshop — Design § Elsewhere; mockup workshop-badge): the form's round badge sprite at the
## lower-right of a portrait. Below MIN_SIZE px it would not read, so it becomes a small dot in the badge's colour.
##   TdFormBadge.attach(medallion, badge_path, diameter)   # badge_path "" → nothing
## The badge's colour (colour_of) also tints form rings in the Workshop.

## Smaller than this the badge is drawn as a colour dot.
const MIN_SIZE := 20.0
## The badge's size against the portrait's diameter.
const RATIO := 0.36

static var _colours := {}

var texture: Texture2D
var colour := Color.WHITE
var dot := false

## A badge (or dot) of a size for a badge sprite path; null for "".
static func make(path: String, size: float) -> TdFormBadge:
	if path == "": return null
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex == null: return null
	var b := TdFormBadge.new()
	b.texture = tex
	b.colour = colour_of(path)
	b.dot = size < MIN_SIZE
	var s := maxf(size, 0.0) if not b.dot else 10.0
	b.custom_minimum_size = Vector2(s, s)
	b.size = b.custom_minimum_size
	return b

## Adds a badge at the lower-right of a portrait control of a diameter (inside its box, overlapping the ring like
## the mockup's .fbadge); anchor moves that corner (a miniature figure: about its waist). Size: ratio × diameter,
## at most 34 px. Returns it (null for no badge).
static func attach(portrait: Control, path: String, diameter: float, ratio := RATIO, anchor := Vector2.ONE) -> TdFormBadge:
	if portrait == null: return null
	var old := portrait.get_node_or_null("FormBadge")
	if old != null:
		portrait.remove_child(old)
		old.queue_free()
	var s := minf(diameter * ratio, 34.0)
	var b := make(path, s)
	if b == null: return null
	b.name = "FormBadge"
	b.position = Vector2(diameter, diameter) * anchor - b.size * (0.82 if not b.dot else 1.0)
	portrait.add_child(b)
	return b

## The badge's colour: the mean of its strongly coloured pixels (cached per path; gold when unreadable).
static func colour_of(path: String) -> Color:
	if _colours.has(path): return _colours[path]
	var c := Color("#E0A030")
	var tex: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	var img: Image = tex.get_image() if tex != null else null
	if img != null and not img.is_empty():
		if img.is_compressed(): img.decompress()
		var sum := Vector3.ZERO
		var n := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var p := img.get_pixel(x, y)
				if p.a > 0.9 and p.s > 0.45 and p.v > 0.35:
					sum += Vector3(p.r, p.g, p.b)
					n += 1
		if n > 0: c = Color(sum.x / n, sum.y / n, sum.z / n)
	_colours[path] = c
	return c

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	if dot:
		var r := size.x / 2.0
		draw_circle(Vector2(r, r), r, TdTheme.color("rim"))
		draw_circle(Vector2(r, r), r - 1.5, colour)
		return
	# a soft shadow, then the badge (it has its own dark rim)
	draw_circle(size / 2.0 + Vector2(0, 2), size.x / 2.0, Color(0, 0, 0, 0.35))
	draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
