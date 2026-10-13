class_name BoardMaterials
extends RefCounted
## Shared board materials, one per colour / texture (BoardView.cs Materials). GL Compatibility friendly:
## StandardMaterial3D only.

static var _lit := {}
static var _overlay := {}
static var _decal := {}
static var _on_top := {}
static var _mipmapped := {}
static var _border := {}
static var _outline := {}  # dashed (bool) → Texture2D

## An opaque lit material (placeholders, slabs).
static func lit(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _lit.has(key): return _lit[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	_lit[key] = m
	return m

## A transparent unlit material (flat highlights, effects).
static func overlay(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _overlay.has(key): return _overlay[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_overlay[key] = m
	return m

## A transparent unlit material showing a texture tinted by c (a tile decal such as the selection ring).
static func decal(tex: Texture2D, c: Color) -> StandardMaterial3D:
	if tex == null: return overlay(c)
	tex = mipmapped(tex)
	var key := "%d|%s" % [tex.get_instance_id(), c.to_html()]
	if _decal.has(key): return _decal[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_decal[key] = m
	return m

## A transparent material drawn over everything in the world (depth test off): preview lines stay readable in
## front of the models they pass. Repeats along U for dashes.
static func on_top(tex: Texture2D, c: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%d|%s" % [tex.get_instance_id() if tex != null else 0, c.to_html()]
	if _on_top.has(key): return _on_top[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 10
	m.albedo_texture = tex
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_repeat = true
	m.disable_receive_shadows = true
	_on_top[key] = m
	return m

## A copy of a texture with mipmaps (the kit's PNGs import without them, so decals shimmered and thinned out when the
## board is zoomed out); the texture itself when it cannot be read.
static func mipmapped(tex: Texture2D) -> Texture2D:
	if tex == null: return null
	var key := tex.get_instance_id()
	if _mipmapped.has(key): return _mipmapped[key]
	var out: Texture2D = tex
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed(): img.decompress()
		img.generate_mipmaps()
		out = ImageTexture.create_from_image(img)
	_mipmapped[key] = out
	_mipmapped[out.get_instance_id()] = out
	return out

## A decal sprite's border colour: its most common nearly opaque colour (the kit draws the border opaque and the fill
## translucent). White when it cannot be read.
static func border_color(tex: Texture2D) -> Color:
	if tex == null: return Color.WHITE
	var key := tex.get_instance_id()
	if _border.has(key): return _border[key]
	var c := Color.WHITE
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed(): img.decompress()
		var counts := {}
		var step := maxi(1, img.get_width() / 64)
		for y in range(0, img.get_height(), step):
			for x in range(0, img.get_width(), step):
				var px := img.get_pixel(x, y)
				if px.a < 0.8: continue
				var k := Color(snappedf(px.r, 0.05), snappedf(px.g, 0.05), snappedf(px.b, 0.05), 1.0)
				counts[k] = counts.get(k, 0) + 1
		var best := 0
		for k in counts:
			if counts[k] > best:
				best = counts[k]
				c = k
	_border[key] = c
	return c

## A white rounded-square outline (about 3 px wide on a tile at the default zoom) with a thin dark line inside it,
## for tinting: laid over a kit decal it makes the tile's border read clearly.
## dashed: the border in dashes (a walk's reach, an enemy's path: dashed = path, the kit's pattern rule).
static func outline_texture(dashed: bool = false) -> Texture2D:
	if _outline.has(dashed): return _outline[dashed]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var inset := 6.0
	var width := 9.0
	var dark := 2.5
	var radius := 30.0
	for y in n:
		for x in n:
			# distance inside the rounded square's edge
			var px := absf(x + 0.5 - n * 0.5)
			var py := absf(y + 0.5 - n * 0.5)
			var half := n * 0.5 - inset
			var qx := px - (half - radius)
			var qy := py - (half - radius)
			var outside := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - radius
			var d := -outside # > 0 inside the shape, measured from the edge
			var col := Color(0, 0, 0, 0)
			if d >= 0.0 and d < width:
				col = Color(1, 1, 1, 1)
			elif d >= width and d < width + dark:
				col = Color(0.08, 0.06, 0.05, 0.55)
			# soft edges
			if d > -1.0 and d < 0.0: col = Color(1, 1, 1, d + 1.0)
			if dashed and col.a > 0.0:
				# dashes 22 texels long, 14 apart, running along each side (x on the top/bottom, y on the sides)
				var along := float(x) if py > px else float(y)
				if fmod(along + 6.0, 36.0) >= 22.0: col = Color(0, 0, 0, 0)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_outline[dashed] = tex
	return tex
