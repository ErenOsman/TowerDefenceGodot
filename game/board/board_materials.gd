class_name BoardMaterials
extends RefCounted
## Shared board materials, one per colour / texture (BoardView.cs Materials). GL Compatibility friendly:
## StandardMaterial3D only.

static var _lit := {}
static var _overlay := {}
static var _decal := {}
static var _on_top := {}

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
