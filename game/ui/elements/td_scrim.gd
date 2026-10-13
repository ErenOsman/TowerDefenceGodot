class_name TdScrim
extends ColorRect
## The dim behind a window (scrim token: wood.900 at 88 %), full screen, blocking the pointer (a raycast blocker).
## Left or right click on it emits `clicked` (windows close on right click / Esc; a click outside may close too).
## fade_in() / fade_out() use motion.normal / motion.quick on unscaled time.

signal clicked(button: int)

func _init() -> void:
	color = TdTheme.color("scrim")
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		clicked.emit(event.button_index)
		accept_event()

func fade_in() -> void:
	visible = true
	modulate.a = 0.0
	TdTheme.tween(self).tween_property(self, "modulate:a", 1.0, TdTheme.motion("normal"))

func fade_out() -> void:
	var tw := TdTheme.tween(self)
	tw.tween_property(self, "modulate:a", 0.0, TdTheme.motion("quick"))
	tw.tween_callback(func() -> void: visible = false)
