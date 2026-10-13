extends Control
## The Boot scene's plain loading panel (UI_BootLoading.cs): a bar that fills over at least
## MINIMUM_DISPLAY_TIME while the content loads, "Complete!", then Welcome on a first launch (no profile in
## the save) or the main menu.

const MINIMUM_DISPLAY_TIME := 1.5
const POST_LOAD_DELAY := 0.5

var _fill: ProgressBar
var _status: Label
var _percent: Label
var _timer := 0.0
var _progress := 0.0   # real work done (content loaded)
var _done := false
var _last_usec := 0

func _ready() -> void:
	_build()
	_set_status("Loading...")
	_last_usec = Time.get_ticks_usec()
	# let the panel draw once, then load the content (synchronous; one long frame)
	await get_tree().process_frame
	await get_tree().process_frame
	GameApp.ensure_loaded()
	_progress = 1.0

func _process(_delta: float) -> void:
	if _done: return
	var now := Time.get_ticks_usec()
	# capped: a frame stalled by the load would otherwise fill the bar at once
	_timer += minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now
	var shown := minf(clampf(_timer / MINIMUM_DISPLAY_TIME, 0.0, 1.0), _progress)
	_update(shown)
	if _timer >= MINIMUM_DISPLAY_TIME and _progress >= 1.0:
		_done = true
		_update(1.0)
		_set_status("Complete!")
		await get_tree().create_timer(POST_LOAD_DELAY, true, false, true).timeout
		SceneFlow.go(destination())

## Welcome on a first launch, else the main menu.
static func destination() -> int:
	return SceneFlow.Welcome if SaveData.profile.is_first_run else SceneFlow.MainMenu

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Boot keeps the plain dark wood backdrop + vignette (user decision 2026-10-13: like the Unity boot screen);
	# the blurred diorama is for Welcome, Main menu and Loading only.
	if ClassDB.class_exists("TdMenu") or ResourceLoader.exists("res://game/ui/screens/parts/td_menu.gd"):
		TdMenu.wood_background(self, true)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "Tower Defence"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	var display := load("res://art/fonts/Plinth-Bold.ttf") as Font
	if display != null: title.add_theme_font_override("font", display)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.70))
	box.add_child(title)
	_fill = ProgressBar.new()
	_fill.max_value = 1.0
	_fill.show_percentage = false
	_fill.custom_minimum_size = Vector2(0, 22)
	box.add_child(_fill)
	var row := HBoxContainer.new()
	box.add_child(row)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", 22)
	row.add_child(_status)
	_percent = Label.new()
	_percent.add_theme_font_size_override("font_size", 22)
	row.add_child(_percent)

func _update(p: float) -> void:
	_fill.value = p
	_percent.text = "%d%%" % roundi(p * 100.0)

func _set_status(t: String) -> void:
	_status.text = t
