extends Control
## The main menu (UI_MainMenu.cs; hud-menu-spec §5; the Unity build): the game's name top-left, "Welcome back,
## {name}", a vertical list of menu buttons — Continue "Continue: {level}" (only when GameApp.continue_level()
## exists; it is then the one cobalt button), Play (→ GameApp.go_home(): the Camp once unlocked, else level select),
## Codex, Settings, Credits, a gap, Quit — the version bottom-left, and behind it
## the blurred level diorama with three miniatures (Archer, Guardian, Mage) sharp in the bottom right.
## No Miscellaneous button (Unity's was an empty placeholder). Codex / Settings / Credits open as popups (Esc or right click closes the top one). Up/Down move the focus
## through the list, Enter presses. Menu music comes from SceneFlow (AudioMgr.play_scene_music).

const SCREENS := "res://game/ui/screens/"

var buttons: Dictionary = {}   # name → TdMenuButton
var greeting: RichTextLabel
var list: VBoxContainer
var popups: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	TdMenu.menu_background(self)
	var dio := TdDiorama.new() # only the sharp miniatures; the board is the shared background image
	dio.build_board = false
	add_child(dio)
	# turned toward the viewer's lower left, like the Unity menu
	dio.add_mini("art/models/Archer.fbx", Vector2(-800, 975), 250.0, -35.0)
	dio.add_mini("art/models/Mage.fbx", Vector2(-250, 975), 250.0, -35.0)
	dio.add_mini("art/models/Guardian.fbx", Vector2(-525, 1000), 270.0, -35.0)
	_build()
	popups = Control.new()
	popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(popups)
	_enter()
	_first_button().grab_focus()

## Entry motion without a flash: everything starts hidden in _build (before the first frame is drawn); the column
## slides in from x -24 as a whole (moving buttons inside a container fights its layout, which made them jitter)
## and the buttons fade in one after another (0.04 s apart). Unscaled time.
func _enter() -> void:
	var to := _col.position
	_col.position = to + Vector2(-24, 0)
	var tw := TdTheme.tween(_col)
	TdTheme.ease_tweener(tw.tween_property(_col, "position", to, TdTheme.motion("normal")), "out")
	var i := 0
	for c in list.get_children():
		var t := TdTheme.tween(c)
		t.tween_interval(0.04 * i)
		t.tween_property(c, "modulate:a", 1.0, TdTheme.motion("normal"))
		i += 1

var _col: Control

func _build() -> void:
	var col := TdMenu.vbox(0)
	_col = col
	col.position = Vector2(120, 72)
	col.custom_minimum_size = Vector2(560, 0)
	add_child(col)
	var logo := TdMenu.logo_slot(72, Vector2(560, 150))
	logo.size_flags_horizontal = SIZE_SHRINK_BEGIN
	col.add_child(logo)
	col.add_child(TdMenu.spacer(30))
	greeting = TdMenu.rich("", "body", TdTheme.color("cream.200"), 26)
	greeting.custom_minimum_size = Vector2(560, 0)
	col.add_child(greeting)
	col.add_child(TdMenu.spacer(24))
	list = TdMenu.vbox(20)
	col.add_child(list)
	_add("Continue", "Continue", "icon_continue", func(): GameApp.continue_game())
	_add("Play", "Play", "icon_play", func(): GameApp.go_home())
	_add("Codex", "Codex", "icon_codex", func(): open_popup("codex"))
	_add("Settings", "Settings", "icon_settings", func(): open_popup("settings"))
	_add("Credits", "Credits", "icon_credits", func(): open_popup("credits"))
	list.add_child(TdMenu.spacer(4))
	_add("Quit", "Quit", "icon_quit", func(): SceneFlow.quit_game())
	buttons["Play"].hint = "Choose a level"

	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	var version := TdMenu.label("Version " + (v if v != "" else "0.7"), "body", TdTheme.color("cream.300"), 20)
	version.set_anchors_preset(PRESET_BOTTOM_LEFT)
	version.offset_left = 120; version.offset_top = -72; version.offset_bottom = -40
	add_child(version)

	refresh()

func _add(id: String, text: String, icon: String, fn: Callable) -> void:
	var b := TdMenuButton.new()
	b.style = TdButton.Style.MENU_WOOD
	b.custom_minimum_size = Vector2(440, 64)
	b.size = Vector2(440, 64)
	b.text = text
	b.icon = TdTheme.texture(icon)
	b.keyboard_focus = true
	b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	b.clicked.connect(fn)
	b.modulate.a = 0.0 # faded in by _enter()
	list.add_child(b)
	buttons[id] = b

## Greeting and Continue as the save says now (also after the Credits' secrets).
func refresh() -> void:
	var p := SaveData.profile
	var show := p.created and p.player_name != ""
	greeting.visible = show
	greeting.text = "Welcome back, [b][color=%s]%s[/color][/b]" % [TdTheme.rich("cream.100"), TooltipText.escape(p.player_name)] if show else ""
	var next := GameApp.continue_level()
	var cont: TdMenuButton = buttons["Continue"]
	cont.visible = next != null
	if next != null: cont.text = "Continue: %s" % next.get_display_name()
	# Play is always the blue primary, Continue is a wood button (Eren 2026-10-15)
	cont.style = TdButton.Style.MENU_WOOD
	buttons["Play"].style = TdButton.Style.MENU_PRIMARY
	buttons["Play"].text = "Play"

func _first_button() -> TdButton:
	return buttons["Continue"] if buttons["Continue"].visible else buttons["Play"]

## Opens a popup by its scene name ("codex", "settings", "credits"); returns it.
func open_popup(scene: String) -> TdPopup:
	var p: TdPopup = load(SCREENS + scene + ".tscn").instantiate()
	p.free_on_close = true
	popups.add_child(p)
	if p.has_signal("secret_used"): p.secret_used.connect(func(_m): refresh())
	_set_list_live(false)
	p.closed.connect(func():
		if not is_inside_tree(): return
		if TdPopup.open_popups.is_empty(): _set_list_live(true)
		_first_button().grab_focus())
	p.open()
	return p

## While a popup is on top the list is inert: no hover, no pressed or focused look behind the scrim.
func _set_list_live(on: bool) -> void:
	if not on: get_viewport().gui_release_focus()
	for c in list.get_children():
		if not (c is TdButton): continue
		var b: TdButton = c
		b.mouse_filter = MOUSE_FILTER_STOP if on else MOUSE_FILTER_IGNORE
		if not on:
			b.hovered = false
			b.force_state(false, false)
			b.hover_changed.emit(false)

func _unhandled_key_input(event: InputEvent) -> void:
	# Up / Down through the list (wrapping); Esc does nothing on the main menu (Quit is explicit)
	if not (event is InputEventKey) or not event.pressed or not TdPopup.open_popups.is_empty(): return
	if event.keycode != KEY_UP and event.keycode != KEY_DOWN: return
	var shown := []
	for c in list.get_children():
		if c is TdButton and c.visible: shown.append(c)
	if shown.is_empty(): return
	var at := shown.find(get_viewport().gui_get_focus_owner())
	var step := 1 if event.keycode == KEY_DOWN else -1
	shown[posmod(at + step if at >= 0 else 0, shown.size())].grab_focus()
	get_viewport().set_input_as_handled()
