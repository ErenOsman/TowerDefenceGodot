class_name HudPause
extends HudPopup
## The pause menu (UI_Pause; the Unity build's look): "Paused" over the dimmed level with Continue (primary), Settings,
## Codex (not in the tutorial; only when the Codex screen exists), then "Quit to <home>" (controller.leave_label: it
## records the level as quit and leaves) and Quit game (danger). Game time stops while it is open
## (Engine.time_scale 0) and comes back on Continue. Settings / Codex open the menus agent's screens
## (res://game/ui/screens/settings.tscn, codex.tscn: open(), close(), signal closed) over it; without the settings
## screen a short note shows instead. Esc / the Pause key / right click continue.

const SETTINGS_SCENE := "res://game/ui/screens/settings.tscn"
const CODEX_SCENE := "res://game/ui/screens/codex.tscn"

var continue_button: TdButton
var settings_button: TdButton
var codex_button: TdButton
var leave_button: TdButton
var quit_button: TdButton
var _resume_scale := 1.0
var _sub: Node = null
var _subtitle: Label

## "Two Roads · Round 4 · Wave 2/3": the level, the round and the waves as shown now.
static func pause_subtitle(c: LevelController) -> String:
	if c == null or c.session == null: return ""
	var parts: Array[String] = []
	if c.level != null and c.level.display_name != "": parts.append(c.level.display_name)
	var f: ViewFrame = c.shown
	parts.append("Round %d" % (f.round if f != null else c.session.round))
	if f != null and not f.waves.is_empty(): parts.append("Wave " + HudText.wave_text(f.waves))
	return " · ".join(parts)

func _ready() -> void:
	make("Paused", 520, false, true)
	title_label.add_theme_color_override("font_color", TdTheme.color("cream.100"))
	body.add_theme_constant_override("separation", 22)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	_subtitle = HudArt.label("", "small", TdTheme.color("cream.300"))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_subtitle)
	continue_button = _add(wide_button("Continue", TdButton.Style.PRIMARY, "icon_play"))
	continue_button.set_key_hint("Esc")
	continue_button.clicked.connect(close)
	settings_button = _add(wide_button("Settings", TdButton.Style.SECONDARY, "icon_settings"))
	settings_button.clicked.connect(_open_settings)
	codex_button = _add(wide_button("Codex", TdButton.Style.SECONDARY, "icon_codex"))
	codex_button.clicked.connect(func(): _open_sub(CODEX_SCENE))
	leave_button = _add(wide_button("Quit to level select", TdButton.Style.SECONDARY, "icon_back"))
	leave_button.clicked.connect(_leave)
	quit_button = _add(wide_button("Quit game", TdButton.Style.SECONDARY, "icon_quit"))
	quit_button.clicked.connect(_quit)
	visible = false

func _add(b: TdButton) -> TdButton:
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(b)
	return b

func open() -> void:
	var c := controller
	leave_button.text = "Quit to " + (c.leave_label.to_lower() if c != null else "level select")
	_subtitle.text = pause_subtitle(c)
	codex_button.visible = ResourceLoader.exists(CODEX_SCENE) and not (c != null and c.is_tutorial)
	_resume_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
	Engine.time_scale = 0.0
	super.open()

func close() -> void:
	if _closing: return
	_close_sub()
	_restore_speed()
	super.close()

func _restore_speed() -> void:
	var flow = get_tree().root.get_node_or_null("SceneFlow")
	var sd = get_tree().root.get_node_or_null("SaveData")
	if flow != null and sd != null: flow.restore_game_speed()
	else: Engine.time_scale = _resume_scale

func _extra_close_key(keys) -> bool:
	return keys.pressed("Pause")

func _sub_panel_open() -> bool:
	return is_instance_valid(_sub)

func _process(delta: float) -> void:
	if is_open() and Engine.time_scale != 0.0: Engine.time_scale = 0.0
	super._process(delta)

func _open_settings() -> void:
	if ResourceLoader.exists(SETTINGS_SCENE):
		_open_sub(SETTINGS_SCENE)
		return
	# no settings screen yet: a short note
	var note := HudPopup.new()
	note.make("Settings", 560, true)
	var l := HudArt.label("Settings are not available here yet. Open them from the main menu.", "body", TdTheme.color("cream.200"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	note.body.add_child(l)
	add_child(note)
	note.closed.connect(func(): note.queue_free())
	note.open()
	_sub = note

func _open_sub(path: String) -> void:
	if not ResourceLoader.exists(path): return
	var scene: PackedScene = load(path)
	if scene == null: return
	var n := scene.instantiate()
	add_child(n)
	if n is Control: (n as Control).set_anchors_preset(PRESET_FULL_RECT)
	if n.has_signal("closed"): n.closed.connect(func(): if is_instance_valid(n): n.queue_free())
	n.tree_exited.connect(func(): if _sub == n: _sub = null)
	if n.has_method("open"): n.open()
	_sub = n

func _close_sub() -> void:
	if is_instance_valid(_sub):
		_sub.queue_free()
	_sub = null

func _leave() -> void:
	if controller == null: return
	_closing = true
	controller.level_select()

func _quit() -> void:
	if controller != null: controller.record_quit()
	var flow = get_tree().root.get_node_or_null("SceneFlow")
	if flow != null: flow.quit_game()
	else: get_tree().quit()
