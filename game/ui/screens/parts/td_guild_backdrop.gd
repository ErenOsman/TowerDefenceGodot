class_name TdGuildBackdrop
extends Control
## The Guild's backdrop placeholder until there is Guild art (Missions & Guild — Design § The Guild: "a warm-tinted
## blurred diorama"; mockup guild.html uses the Rock Garden board): a level's 3D board (CoopBoardPic's render,
## cached) covering the screen, blurred, darkened and tinted warm, with a dark vignette. Dark wood until it renders.
##   var b := TdGuildBackdrop.new(); add_child(b)  (full rect)

## The level shown behind the Guild.
const LEVEL := "chapter2-1"
## The render size (the blur hides the detail; small is quick).
const RENDER := Vector2(960, 540)

var level_id := LEVEL
var _pic: CoopBoardPic
var _view: TextureRect

static var _mat: ShaderMaterial = null

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1E1510")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_view.mouse_filter = MOUSE_FILTER_IGNORE
	_view.material = material_warm()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # the blur reads a high mip
	add_child(_view)
	if TdTheme.has_sprite("vignette"):
		var v := TextureRect.new()
		v.texture = TdTheme.texture("vignette")
		v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.stretch_mode = TextureRect.STRETCH_SCALE
		v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		v.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(v)
	# the renderer: an invisible CoopBoardPic of the render size (its texture lands in CoopBoardPic.cache)
	_pic = CoopBoardPic.new()
	_pic.pitch = 40.0
	_pic.custom_minimum_size = RENDER
	_pic.size = RENDER
	_pic.modulate.a = 0.0
	add_child(_pic)
	_pic.show_level(level_id)

func _process(_delta: float) -> void:
	if _view.texture != null: return
	var key := "%s@%dx%d" % [level_id, int(RENDER.x), int(RENDER.y)]
	if CoopBoardPic.cache.has(key):
		_view.texture = CoopBoardPic.cache[key]
		_pic.queue_free()
		set_process(false)

## Whether the board is shown (not the plain wood).
func is_ready() -> bool:
	return _view != null and _view.texture != null

## A heavy blur (a high mip of the render), warm tint, darkened; transparent parts become the dark wood colour.
static func material_warm() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float lod = 3.4;
uniform vec3 tint = vec3(1.0, 0.82, 0.58);
uniform float dark = 0.62;
void fragment() {
	vec4 c = textureLod(TEXTURE, UV, lod);
	vec3 bg = vec3(0.118, 0.082, 0.063);
	vec3 col = mix(bg, c.rgb / max(c.a, 0.001), c.a);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.55) * tint * dark;
	COLOR = vec4(col, 1.0);
}
"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat
