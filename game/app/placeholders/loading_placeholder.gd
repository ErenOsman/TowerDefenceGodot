extends CanvasLayer
## Stand-in loading screen (UI_Loading.cs flow, no styling): opaque, on top (layer 100), loads
## SceneFlow.pending_target under itself, waits while the level holds the screen, then closes.

const MIN_TIME := 0.6

var _bar: ProgressBar
var _t := 0.0
var _progress := 0.0

func _ready() -> void:
	layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var l := Label.new()
	l.text = "Loading…"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	box.add_child(l)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 28)
	_bar.max_value = 1.0
	box.add_child(_bar)
	SceneFlow.loading_progress.connect(func(p): _progress = maxf(_progress, p * 0.8))
	SceneFlow.load_pending(self)

func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	if SceneFlow.target_ready: _progress = 0.8 if SceneFlow.loading_screen_held else 1.0
	_bar.value = minf(_progress, _t / MIN_TIME)
	if SceneFlow.target_ready and not SceneFlow.loading_screen_held and _t >= MIN_TIME:
		SceneFlow.close_loading_screen(self)
		set_process(false)
