extends Control
## Stand-in for a screen another agent has not written yet (SceneFlow falls back to it): the scene's name
## and buttons that keep the app usable end to end. Delete nothing here when the real scene lands; SceneFlow
## simply prefers the real one.

@export var scene_id: int = SceneFlow.MainMenu

var _box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.10, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_box.custom_minimum_size = Vector2(520, 0)
	center.add_child(_box)
	_label(SceneFlow.name_of(scene_id), 56)
	_label("placeholder — the real screen is not built yet", 22, Color(0.75, 0.7, 0.6))
	match scene_id:
		SceneFlow.Welcome: _welcome()
		SceneFlow.MainMenu: _main_menu()
		SceneFlow.LevelSelect: _level_select()
		SceneFlow.Camp: _camp()
		SceneFlow.Game: _level()
	if scene_id != SceneFlow.MainMenu and scene_id != SceneFlow.Welcome:
		_button("Main menu", func(): SceneFlow.go(SceneFlow.MainMenu))

func _welcome() -> void:
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = PlayerProfile.MaxNameLength
	name_edit.add_theme_font_size_override("font_size", 26)
	_box.add_child(name_edit)
	_button("Start (tutorial)", func(): SaveData.begin(name_edit.text, true))
	_button("Skip tutorial", func(): SaveData.begin(name_edit.text, false))

func _main_menu() -> void:
	var p := SaveData.profile
	_label("Welcome back, %s" % (p.player_name if p.created else PlayerProfile.DefaultName), 26)
	if GameApp.continue_level() != null:
		_button("Continue — %s" % GameApp.continue_level().get_display_name(), func(): GameApp.continue_game())
	_button("Play (%s)" % GameApp.home_label(), func(): GameApp.go_home())
	_button("Quit", func(): SceneFlow.quit_game())

func _level_select() -> void:
	var n := 0
	for e in GameApp.catalog.entries():
		var level: LevelAsset = e[0].level
		if level == null: continue
		var lv := level
		var won := SaveData.progress.is_won(level.get_id())
		_button("%s%s" % [level.get_display_name(), "  (won)" if won else ""], func(): GameApp.play_level(lv))
		n += 1
		if n >= 6: break

func _camp() -> void:
	_button("Level select", func(): SceneFlow.go(SceneFlow.LevelSelect))

func _level() -> void:
	var level := LevelLaunch.level
	_label("Level: %s" % (level.get_display_name() if level != null else "(none requested)"), 26)
	_button(GameApp.home_label(), func(): GameApp.go_home())

func _label(text: String, size: int, color := Color(0.95, 0.9, 0.8)) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)

func _button(text: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(fn)
	_box.add_child(b)
