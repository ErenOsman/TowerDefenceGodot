class_name TdDevPanel
extends CanvasLayer
## The runtime F1 dev panel (debug builds, or `--dev` after `--` on the command line): a TdTheme window over the
## game with three tabs. Save: the save file as JSON text (edit, Save / Reload / Reset) and the quick actions
## (player name, grant all towers, complete Chapter 1, win first N levels, mark tutorial done, clear codex).
## Shortcuts: play any level with the current hand, instant playback, game speed, +100 energy in a running
## level (LevelController.dev_add_energy). Log: the last 200 log lines (DevLog). Esc or F1 closes; the game is
## paused while it is open. Created by the DevPanel autoload (game/dev/dev_panel_autoload.gd); it reads the app
## autoloads by path, so it also builds without them (tests).

signal closed

const WIDTH := 1560.0
const HEIGHT := 900.0
const TEXT_SIZE := 20

var tabs: TabContainer
var save_text: TextEdit
var save_summary: Label
var status: Label
var name_edit: LineEdit
var count_edit: LineEdit
var reset_button: Button
var level_pick: OptionButton
var instant_toggle: CheckButton
var speed_slider: HSlider
var speed_label: Label
var energy_button: Button
var level_label: Label
var log_text: TextEdit
var _log_serial := -1
var _reset_armed_until := 0.0
var _was_paused := false
var _level_ids: Array = []

func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _app(n: String) -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(n) if tree != null else null

# ---------------------------------------------------------------- building

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = TdTheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var window := PanelContainer.new()
	window.theme_type_variation = "WindowPanel"
	window.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	center.add_child(window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	window.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Dev panel"
	title.theme_type_variation = "H2Label"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hint := Label.new()
	hint.text = "F1 / Esc closes · game paused"
	hint.theme_type_variation = "SmallLabel"
	head.add_child(hint)
	var close := _button("Close", close_panel)
	head.add_child(close)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	tabs.add_child(_save_tab())
	tabs.add_child(_shortcuts_tab())
	tabs.add_child(_log_tab())

	status = Label.new()
	status.theme_type_variation = "SmallLabel"
	status.text = "Ready."
	status.clip_text = true
	col.add_child(status)

func _button(text: String, on_press: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	if variation != "": b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b

func _label(text: String, variation := "BodyLabel") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l

func _text_box(editable: bool) -> TextEdit:
	var t := TextEdit.new()
	t.editable = editable
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := TdPanel.box(TdPanel.Kind.WELL, 12.0)
	for st in ["normal", "focus", "read_only"]: t.add_theme_stylebox_override(st, box)
	t.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	t.add_theme_font_size_override("font_size", TEXT_SIZE)
	t.add_theme_color_override("font_color", TdTheme.color("cream.100"))
	t.add_theme_color_override("font_readonly_color", TdTheme.color("cream.200"))
	t.add_theme_color_override("caret_color", TdTheme.color("cream.100"))
	t.add_theme_color_override("selection_color", Color(TdTheme.color("accent"), 0.4))
	t.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	return t

func _save_tab() -> Control:
	var row := HBoxContainer.new()
	row.name = "Save"
	row.add_theme_constant_override("separation", 20)
	save_text = _text_box(true)
	row.add_child(save_text)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(440, 0)
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	save_summary = _label("", "SmallLabel")
	save_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(save_summary)
	var file_row := HBoxContainer.new()
	file_row.add_child(_button("Save", _on_save, "PrimaryButton"))
	file_row.add_child(_button("Reload", refresh_save))
	reset_button = _button("Reset", _on_reset, "DangerButton")
	file_row.add_child(reset_button)
	for b in file_row.get_children(): b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(file_row)
	side.add_child(_label("Quick actions", "H3Label"))
	var name_row := HBoxContainer.new()
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Player name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 22)
	name_row.add_child(name_edit)
	name_row.add_child(_button("Set name", func(): _quick("set_name", name_edit.text)))
	side.add_child(name_row)
	for a in SaveTools.ACTIONS:
		if a[0] == "win_first":
			var win_row := HBoxContainer.new()
			var b := _button("Win first", func(): _quick("win_first", maxi(0, int(count_edit.text))))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			win_row.add_child(b)
			count_edit = LineEdit.new()
			count_edit.text = "8"
			count_edit.custom_minimum_size = Vector2(90, 0)
			count_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_edit.add_theme_font_size_override("font_size", 22)
			win_row.add_child(count_edit)
			win_row.add_child(_label("levels"))
			side.add_child(win_row)
		else:
			var id: String = a[0]
			side.add_child(_button(a[1], func(): _quick(id)))
	return row

func _shortcuts_tab() -> Control:
	var col := VBoxContainer.new()
	col.name = "Shortcuts"
	col.add_theme_constant_override("separation", 16)
	col.add_child(_label("Play a level with the current hand", "H3Label"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	level_pick = OptionButton.new()
	level_pick.custom_minimum_size = Vector2(620, 52)
	level_pick.focus_mode = Control.FOCUS_NONE
	row.add_child(level_pick)
	row.add_child(_button("Play", _on_play_level, "PrimaryButton"))
	row.add_child(_button("Main menu", func(): _go("MainMenu")))
	row.add_child(_button("Level select", func(): _go("LevelSelect")))
	col.add_child(row)
	col.add_child(HSeparator.new())
	col.add_child(_label("Playback", "H3Label"))
	instant_toggle = CheckButton.new()
	instant_toggle.text = "Instant playback (no animations)"
	instant_toggle.focus_mode = Control.FOCUS_NONE
	instant_toggle.toggled.connect(_on_instant)
	instant_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(instant_toggle)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 12)
	speed_row.add_child(_label("Game speed"))
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.25
	speed_slider.max_value = 4.0
	speed_slider.step = 0.25
	speed_slider.custom_minimum_size = Vector2(460, 40)
	speed_slider.focus_mode = Control.FOCUS_NONE
	speed_slider.value_changed.connect(_on_speed)
	speed_row.add_child(speed_slider)
	speed_label = _label("1×")
	speed_label.custom_minimum_size = Vector2(80, 0)
	speed_row.add_child(speed_label)
	col.add_child(speed_row)
	col.add_child(HSeparator.new())
	col.add_child(_label("In a level", "H3Label"))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	energy_button = _button("+100 energy", func(): _add_energy(100))
	level_row.add_child(energy_button)
	level_label = _label("", "SmallLabel")
	level_row.add_child(level_label)
	col.add_child(level_row)
	return col

func _log_tab() -> Control:
	var col := VBoxContainer.new()
	col.name = "Log"
	log_text = _text_box(false)
	col.add_child(log_text)
	var row := HBoxContainer.new()
	row.add_child(_label("Last %d lines of print / push_warning / push_error." % DevLog.LIMIT, "SmallLabel"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_button("Clear", func():
		if DevLog.current != null: DevLog.current.clear()))
	col.add_child(row)
	return col

# ---------------------------------------------------------------- open / close

func open_panel() -> void:
	visible = true
	if is_inside_tree():
		_was_paused = get_tree().paused
		get_tree().paused = true
	refresh()

func close_panel() -> void:
	if not visible: return
	visible = false
	if is_inside_tree(): get_tree().paused = _was_paused
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	if not visible: return
	if DevLog.current != null and DevLog.current.serial != _log_serial and tabs.current_tab == 2: _refresh_log()
	var c = current_level()
	energy_button.disabled = c == null or c.session == null or c.session.is_over
	level_label.text = ("Level %s · energy %d · round %d%s" % [c.level.get_id(), c.session.energy, c.session.round,
		" · instant (this level's own setting)" if c.instant_override != null and c.instant_override else ""]) if c != null and c.session != null else "No level is running."

## Fills every tab from the live state.
func refresh() -> void:
	refresh_save()
	_fill_levels()
	var sd = _app("SaveData")
	if sd != null:
		instant_toggle.set_pressed_no_signal(sd.settings.instant_playback)
		speed_slider.set_value_no_signal(sd.settings.game_speed)
		speed_label.text = "%s×" % Num.to_str(sd.settings.game_speed)
	_refresh_log()

# ---------------------------------------------------------------- save tab

func refresh_save() -> void:
	var sd = _app("SaveData")
	if sd == null:
		save_text.text = SaveTools.read_text()
		save_summary.text = "SaveData autoload not running: showing %s." % SaveTools.PATH
		return
	save_text.text = sd.data.to_json()
	save_summary.text = "%s\n%s" % [ProjectSettings.globalize_path(sd.path), SaveTools.summary(sd.data)]
	if name_edit.text == "": name_edit.text = sd.profile.player_name

func _on_save() -> void:
	var sd = _app("SaveData")
	var path: String = sd.path if sd != null else SaveTools.PATH
	var problem := SaveTools.write_text(path, save_text.text)
	if problem != "":
		_say("Not saved: " + problem)
		return
	if sd != null: sd.load_data()
	refresh_save()
	_say("Saved %s." % path)

func _on_reset() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > _reset_armed_until:
		_reset_armed_until = now + 3.0
		reset_button.text = "Sure?"
		_say("Click Reset again within 3 s to wipe the save.")
		get_tree().create_timer(3.0, true).timeout.connect(func(): reset_button.text = "Reset")
		return
	_reset_armed_until = 0.0
	reset_button.text = "Reset"
	var sd = _app("SaveData")
	if sd != null: sd.reset()
	else: SaveTools.write_data(SaveTools.PATH, GameData.new())
	refresh_save()
	_say("Save reset to defaults.")

func _quick(action: String, arg = null) -> void:
	var sd = _app("SaveData")
	var app = _app("GameApp")
	if sd == null or app == null:
		_say("Needs the SaveData and GameApp autoloads.")
		return
	var line := SaveTools.run(action, sd.data, app.catalog, arg)
	sd.save()
	refresh_save()
	_say(line)

# ---------------------------------------------------------------- shortcuts tab

func _fill_levels() -> void:
	level_pick.clear()
	_level_ids.clear()
	var app = _app("GameApp")
	if app == null or app.catalog == null: return
	var c: GameCatalogAsset = app.catalog
	var current := ""
	var lc = current_level()
	if lc != null and lc.level != null: current = lc.level.get_id()
	if c.tutorial != null: _add_level(c.tutorial, "Tutorial")
	for e in c.entries():
		var ch = c.chapters[e[1]]
		_add_level(e[0].level, ch.display_name if ch.display_name != "" else ch.id)
	var at := _level_ids.find(current)
	if at >= 0: level_pick.select(at)

func _add_level(l: LevelAsset, chapter: String) -> void:
	if l == null or _level_ids.has(l.get_id()): return
	_level_ids.append(l.get_id())
	level_pick.add_item("%s — %s" % [chapter, l.get_display_name()])

func _on_play_level() -> void:
	var app = _app("GameApp")
	var i := level_pick.selected
	if app == null or i < 0 or i >= _level_ids.size(): return
	var level: LevelAsset = app.catalog.find_level(_level_ids[i])
	if level == null and app.catalog.tutorial != null and app.catalog.tutorial.get_id() == _level_ids[i]: level = app.catalog.tutorial
	if level == null: return
	close_panel()
	if is_inside_tree(): get_tree().paused = false
	app.play_level(level)

func _go(scene_name: String) -> void:
	var flow = _app("SceneFlow")
	if flow == null: return
	close_panel()
	if is_inside_tree(): get_tree().paused = false
	flow.go(flow.NAMES.find(scene_name))

func _on_instant(on: bool) -> void:
	var sm = _app("SettingsMgr")
	if sm != null: sm.set_instant_playback(on)
	_say("Instant playback " + ("on." if on else "off."))

func _on_speed(v: float) -> void:
	var sm = _app("SettingsMgr")
	if sm != null: sm.set_game_speed(v)
	speed_label.text = "%s×" % Num.to_str(v)

## The running LevelController, or null.
func current_level() -> Node:
	if not is_inside_tree(): return null
	var s := get_tree().current_scene
	if s is LevelController: return s
	for n in get_tree().root.get_children():
		if n is LevelController: return n
	return null

func _add_energy(amount: int) -> void:
	var c = current_level()
	if c != null and c.has_method("dev_add_energy") and c.dev_add_energy(amount): _say("+%d energy (shown when the panel closes)." % amount)
	else: _say("No running level to give energy to.")

# ---------------------------------------------------------------- log tab

func _refresh_log() -> void:
	if DevLog.current == null:
		log_text.text = "(log capture is not installed)"
		return
	_log_serial = DevLog.current.serial
	log_text.text = "\n".join(DevLog.current.lines())
	log_text.scroll_vertical = log_text.get_line_count()

func _say(text: String) -> void:
	status.text = text
