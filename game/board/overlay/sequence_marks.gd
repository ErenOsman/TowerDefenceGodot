class_name SequenceMarks
extends Control
## The tutorial / intro marks over the board (UI_SequenceBubble.cs: dim, ring, arrow): while a sequence line points
## at a unit or a tile, a soft light ring pulses round its feet and, for a line read and clicked on, the board
## dims a little around it. A line pointing at nothing shows a bobbing arrow when given a point. The speech bubble
## itself is the HUD's. Never takes the pointer. Unscaled time.

var _dim: ColorRect
var _ring: Control
var _arrow: Label
var _time := 0.0
var _ring_at = null       # Vector2 or null
var _ring_size := Vector2(110, 60)
var _arrow_at = null
var _dim_on := false
var _fade := 0.0

func _init() -> void:
	name = "Sequence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.04, 0.03, 0.0)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 hole = vec2(-1000.0);
uniform float radius = 120.0;
uniform vec2 view_size = vec2(1920.0, 1080.0);
void fragment() {
	vec2 p = UV * view_size;
	float d = length((p - hole) * vec2(1.0, 1.6));
	float k = smoothstep(radius * 0.8, radius * 2.2, d); // a soft edge round the target
	COLOR = vec4(COLOR.rgb, COLOR.a * k);
}"""
	mat.shader = sh
	_dim.material = mat
	_dim.visible = false
	add_child(_dim)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_ring.visible = false
	add_child(_ring)
	_arrow = Label.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.text = "▼"
	_arrow.label_settings = OverlayStyle.world_label(44, OverlayStyle.GOLD, OverlayStyle.BODY_FONT, 8)
	_arrow.visible = false
	add_child(_arrow)

## What to show this frame: ring_at (canvas point round a unit's feet, or null), whether the board dims, and an
## arrow point (or null).
func set_target(ring_at, dim: bool, arrow_at = null, ring_size: Vector2 = Vector2(110, 60)) -> void:
	if (ring_at == null) != (_ring_at == null): _fade = 0.0
	_ring_at = ring_at
	_dim_on = dim and ring_at != null
	_arrow_at = arrow_at
	_ring_size = ring_size

func tick(dt: float) -> void:
	_time += dt
	_fade = minf(1.0, _fade + dt / 0.25)
	_ring.visible = _ring_at != null
	_dim.visible = _dim_on
	if _dim_on:
		var mat: ShaderMaterial = _dim.material
		mat.set_shader_parameter("hole", _ring_at)
		mat.set_shader_parameter("view_size", get_viewport_rect().size)
		_dim.color = Color(0.05, 0.04, 0.03, 0.3 * _fade)
	if _ring_at != null:
		var s := 1.0 + 0.08 * sin(_time * 4.0)
		_ring.size = _ring_size * s
		_ring.position = _ring_at - _ring.size * 0.5
		_ring.queue_redraw()
	_arrow.visible = _arrow_at != null
	if _arrow_at != null:
		_arrow.reset_size()
		_arrow.position = _arrow_at - Vector2(_arrow.size.x * 0.5, _arrow.size.y + 24.0 + absf(sin(_time * 3.0)) * 14.0)

func _draw_ring() -> void:
	var c := _ring.size * 0.5
	var pts := PackedVector2Array()
	for i in 49:
		var a := i * TAU / 48.0
		pts.append(c + Vector2(cos(a) * c.x, sin(a) * c.y))
	# a soft light ring: a wide faint glow fading in to a thin warm line
	for k in [[22.0, 0.07], [15.0, 0.12], [9.0, 0.2], [4.0, 0.35], [2.0, 0.55]]:
		_ring.draw_polyline(pts, Color(1.0, 0.94, 0.72, k[1] * _fade), k[0], true)
