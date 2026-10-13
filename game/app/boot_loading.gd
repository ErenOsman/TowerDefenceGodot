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
	_set_status("Loading…")
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
	# the Unity boot: a centred rounded dark plaque (700×135) with the name, "Loading…" above a cobalt bar
	# (710×35) with the percentage centred in white inside it
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(710, 0)
	box.add_theme_constant_override("separation", 0)
	center.add_child(box)
	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(700, 135)
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plaque.add_theme_stylebox_override("panel", TdTheme.stylebox("menu_panel", Color.WHITE, [24, 8, 24, 12]))
	box.add_child(plaque)
	var title := Label.new()
	title.text = "Tower Defence"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.apply_type(title, "display", TdTheme.color("cream.100"), 72)
	title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	title.add_theme_constant_override("shadow_offset_y", 4)
	plaque.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 72)
	box.add_child(gap)
	_status = Label.new()
	TdTheme.apply_type(_status, "small", TdTheme.color("cream.100"), 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap2)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(710, 35)
	bar.add_theme_stylebox_override("panel", TdTheme.stylebox("loadbar_track"))
	box.add_child(bar)
	_fill = ProgressBar.new() # kept as the value holder; drawn by _fill_box
	_fill.max_value = 1.0
	_fill.visible = false
	bar.add_child(_fill)
	_fill_box = Panel.new()
	_fill_box.add_theme_stylebox_override("panel", TdTheme.stylebox("loadbar_fill"))
	_fill_box.size = Vector2(0, 35)
	bar.add_child(_fill_box)
	_percent = Label.new()
	TdTheme.apply_type(_percent, "header", Color.WHITE, 22)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent.set_anchors_preset(Control.PRESET_FULL_RECT)
	TdTheme.outline(_percent, 4)
	bar.add_child(_percent)

var _fill_box: Panel

func _update(p: float) -> void:
	_fill.value = p
	_fill_box.size = Vector2(710.0 * clampf(p, 0.0, 1.0), 35)
	_fill_box.visible = p > 0.01
	_percent.text = "%d%%" % roundi(p * 100.0)

func _set_status(t: String) -> void:
	_status.text = t
