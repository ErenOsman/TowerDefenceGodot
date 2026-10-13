extends Control
## The first-launch screen (UI_Welcome.cs; hud-menu-spec §4; Tutorial, First Run & Sequences — Design): the game's
## name, a plaque asking for the player's name (at most PlayerProfile.MaxNameLength characters, placeholder
## PlayerProfile.DefaultName), Start = SaveData.begin(name, true) (plays the tutorial), "Skip tutorial" =
## begin(name, false) (main menu). Enter in the field is Start. Esc does nothing (nothing to go back to).
## Behind: the blurred level diorama with the Archer and Guardian miniatures.

var name_edit: LineEdit
var start_button: TdMenuButton
var skip_button: LinkButton
var plaque: Control
var _counter: Label
var _leaving := false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	TdMenu.wood_background(self)
	var dio := TdDiorama.new()
	dio.dim = 0.62
	dio.focus = Vector2(0.5, 0.56)
	add_child(dio)
	dio.add_mini("Assets/Art/Models/Archer/Archer Blender.prefab", Vector2(340, 715), 270.0, 18.0)
	dio.add_mini("Assets/Art/Models/Guardian/Guardian Blender.prefab", Vector2(-340, 720), 270.0, -18.0)
	_build()
	await get_tree().process_frame
	TdPanelTransition.open(plaque)
	name_edit.grab_focus()

func _build() -> void:
	var title := TdMenu.label(TdMenu.GAME_TITLE, "display", TdTheme.color("cream.100"), 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(PRESET_CENTER_TOP)
	title.offset_left = -500; title.offset_right = 500; title.offset_top = 64; title.offset_bottom = 180
	_shadow(title)
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.offset_top = 210
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.MENU, 0)
	p.custom_minimum_size = Vector2(760, 0)
	center.add_child(p)
	plaque = p
	var margin := MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 44)
	p.add_child(margin)
	var col := TdMenu.vbox(12)
	margin.add_child(col)

	var eyebrow := TdMenu.label("FIRST TIME HERE", "micro", TdTheme.color("gold"), 22)
	var fv := FontVariation.new()
	fv.base_font = TdTheme.font("plinth")
	fv.spacing_glyph = 3
	eyebrow.add_theme_font_override("font", fv)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(eyebrow)
	var head := TdMenu.label("Welcome, commander", "plaque_title", TdTheme.color("cream.100"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow(head)
	col.add_child(head)
	var lead := TdMenu.label("What should we call you?", "body", TdTheme.color("cream.200"))
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lead)
	col.add_child(TdMenu.spacer(16))

	col.add_child(TdMenu.label("Your name", "small", TdTheme.color("cream.200")))
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(632, 72)
	name_edit.max_length = PlayerProfile.MaxNameLength
	name_edit.placeholder_text = PlayerProfile.DefaultName
	name_edit.add_theme_font_override("font", TdTheme.font("plinth"))
	name_edit.add_theme_font_size_override("font_size", 34)
	name_edit.add_theme_constant_override("caret_width", 3)
	name_edit.add_theme_color_override("caret_color", TdTheme.color("accent.fill"))
	name_edit.text_submitted.connect(func(_t): begin(true))
	name_edit.text_changed.connect(func(_t): _update_counter())
	col.add_child(name_edit)
	_counter = TdMenu.label("", "small", TdTheme.color("ink.2"), 20)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_counter.offset_right = -22
	_counter.mouse_filter = MOUSE_FILTER_IGNORE
	name_edit.add_child(_counter)
	_update_counter()
	col.add_child(TdMenu.label("You can change it later in Settings.", "body", TdTheme.color("cream.300"), 20))
	col.add_child(TdMenu.spacer(20))

	var row := CenterContainer.new()
	col.add_child(row)
	start_button = TdMenuButton.new()
	start_button.style = TdButton.Style.MENU_PRIMARY
	start_button.custom_minimum_size = Vector2(320, 68)
	start_button.size = Vector2(320, 68)
	start_button.text = "Start"
	start_button.icon = TdTheme.texture("icon_play")
	start_button.font_size = 30
	start_button.left_pad = 32
	start_button.clicked.connect(func(): begin(true))
	row.add_child(start_button)

	col.add_child(TdMenu.spacer(4))
	var skip_row := CenterContainer.new()
	col.add_child(skip_row)
	skip_button = LinkButton.new()
	skip_button.text = "Skip tutorial, I know how to play"
	skip_button.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	skip_button.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	skip_button.add_theme_font_size_override("font_size", 22)
	skip_button.add_theme_color_override("font_color", TdTheme.color("cream.200"))
	skip_button.add_theme_color_override("font_hover_color", TdTheme.color("cream.100"))
	skip_button.add_theme_color_override("font_pressed_color", TdTheme.color("cream.300"))
	skip_button.custom_minimum_size = Vector2(0, 44)
	skip_button.pressed.connect(func(): begin(false))
	skip_row.add_child(skip_button)

func _update_counter() -> void:
	_counter.text = "%d / %d" % [name_edit.text.length(), PlayerProfile.MaxNameLength]

static func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)

## Creates the profile and leaves: the tutorial (play_tutorial) or the main menu. Once only (a double click
## cannot start twice).
func begin(play_tutorial: bool) -> void:
	if _leaving: return
	_leaving = true
	SaveData.begin(PlayerProfile.clean_name(name_edit.text), play_tutorial)
