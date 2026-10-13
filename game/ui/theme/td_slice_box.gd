@tool
class_name TdSliceBox
extends StyleBox
## A 9-slice StyleBox for the style B kit sprites (res://art/ui/KitB). The PNGs are drawn at 2x the 1920x1080
## reference, so the texture is drawn at `texture_scale` (0.5): a 38 px PNG border becomes 19 px on the canvas and
## stays sharp when the window is bigger than 1080p (the full-resolution texture is used, only the transform halves it).
## `border_*` are in PNG pixels (slices.json "border"); `outset_*` are reference pixels the sprite reaches past the
## control's rect (slices.json "outsetRef": rims, bands, glows), so a control keeps its logical size from the spec and
## its sprite hangs outside it. When the rect is smaller than the borders, the borders shrink with it (like Unity's
## Sliced image with a pixels-per-unit multiplier), so a 18 px pill still gets round ends.
##
## Note: drawing sets a canvas transform and resets it to identity afterwards, so do not draw this box between a
## `draw_set_transform` and other transformed draws in the same `_draw` (Godot's own controls never do).

@export var texture: Texture2D:
	set(v): texture = v; emit_changed()
## 9-slice border in texture pixels.
@export var border_left := 0:
	set(v): border_left = v; emit_changed()
@export var border_top := 0:
	set(v): border_top = v; emit_changed()
@export var border_right := 0:
	set(v): border_right = v; emit_changed()
@export var border_bottom := 0:
	set(v): border_bottom = v; emit_changed()
## Canvas units per texture pixel (0.5 for the 2x kit).
@export var texture_scale := 0.5:
	set(v): texture_scale = maxf(v, 0.001); emit_changed()
## How far the sprite reaches past the rect it is drawn in (reference px).
@export var outset_left := 0.0:
	set(v): outset_left = v; emit_changed()
@export var outset_top := 0.0:
	set(v): outset_top = v; emit_changed()
@export var outset_right := 0.0:
	set(v): outset_right = v; emit_changed()
@export var outset_bottom := 0.0:
	set(v): outset_bottom = v; emit_changed()
## Tint (white sprites such as glows, focus rings, HP fills take their token colour here).
@export var modulate_color := Color.WHITE:
	set(v): modulate_color = v; emit_changed()
@export var draw_center := true:
	set(v): draw_center = v; emit_changed()
## Part of the texture to use (texture px); a zero size = the whole texture.
@export var region := Rect2():
	set(v): region = v; emit_changed()
## Tile the middle instead of stretching it (wood grain).
@export var tile_center := false:
	set(v): tile_center = v; emit_changed()

## Sets the four borders (texture px) at once.
func set_border(l: int, t: int, r: int, b: int) -> TdSliceBox:
	border_left = l; border_top = t; border_right = r; border_bottom = b
	return self

## Sets the four outsets (reference px) at once.
func set_outset(l: float, t: float, r: float, b: float) -> TdSliceBox:
	outset_left = l; outset_top = t; outset_right = r; outset_bottom = b
	return self

## Sets the content margins (padding inside the logical rect) at once.
func set_padding(l: float, t: float, r: float, b: float) -> TdSliceBox:
	content_margin_left = l; content_margin_top = t; content_margin_right = r; content_margin_bottom = b
	return self

## A copy with another tint (the kit's white sprites).
func tinted(c: Color) -> TdSliceBox:
	var s: TdSliceBox = duplicate()
	s.modulate_color = c
	return s

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(outset_left, outset_top, outset_right, outset_bottom)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var r := _get_draw_rect(rect)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var s := texture_scale
	# borders bigger than the rect: shrink them with it
	var bw := float(border_left + border_right) * s
	var bh := float(border_top + border_bottom) * s
	if bw > r.size.x and bw > 0.0: s = minf(s, r.size.x / float(border_left + border_right))
	if bh > r.size.y and bh > 0.0: s = minf(s, r.size.y / float(border_top + border_bottom))
	var src := region if region.size != Vector2.ZERO else Rect2(Vector2.ZERO, texture.get_size())
	var mode := RenderingServer.NINE_PATCH_TILE_FIT if tile_center else RenderingServer.NINE_PATCH_STRETCH
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(s, s), 0.0, r.position))
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, r.size / s), src,
		texture.get_rid(), Vector2(border_left, border_top), Vector2(border_right, border_bottom), mode, mode, draw_center, modulate_color)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
