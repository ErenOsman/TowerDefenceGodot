class_name HudPopup
extends Control
## A window over the level: the scrim (blocks the board) and a wood window centred on it, opening with the panel
## transition. Subclasses fill `body` in build(). `closed` fires once it has gone; `closable` says whether Esc /
## right click on the scrim close it (the end screen cannot be closed). The HUD sets controller.ui_panel_open while
## any popup is open.

signal closed

var controller: LevelController
var closable := true
var panel: TdPanel
var body: VBoxContainer
var title_label: Label
var close_button: TdButton
var _scrim: TdScrim
var _opened_frame := -1
var _closing := false

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

## Builds the window: title (centred when there is no close button), body, optional ×.
func make(title: String, width: float, with_close: bool, centred_title := false) -> void:
	_scrim = TdScrim.new()
	_scrim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_scrim)
	_scrim.clicked.connect(func(button): if button == MOUSE_BUTTON_RIGHT and closable: close())
	var w := TdPanel.make_window(title, with_close)
	panel = w["panel"]
	body = w["body"]
	title_label = w["title"]
	close_button = w["close"]
	if centred_title: title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if close_button != null: close_button.clicked.connect(close)
	panel.custom_minimum_size = Vector2(width, 0)
	add_child(panel)
	panel.resized.connect(_centre)
	resized.connect(_centre)

func _centre() -> void:
	if panel == null: return
	panel.size = panel.get_combined_minimum_size()
	panel.position = ((size - panel.size) / 2.0).round()
	panel.pivot_offset = panel.size / 2.0

func open() -> void:
	visible = true
	_closing = false
	_opened_frame = Engine.get_process_frames()
	# the Pause button's (or a unit's) tooltip would stay drawn over the window until the pointer moves, and a
	# pending one would still open over it (browser smoke test 2026-10-14)
	TdTooltipTrigger.reset_all(get_tree() if is_inside_tree() else null)
	_centre()
	_scrim.fade_in()
	TdPanelTransition.open(panel)

func close() -> void:
	if _closing: return
	_closing = true
	_scrim.fade_out()
	TdPanelTransition.close(panel, func():
		visible = false
		closed.emit())

func is_open() -> bool:
	return visible and not _closing

## Keys that close it (Esc), not on the frame it opened (the key that opened it is still "pressed").
func _process(_delta: float) -> void:
	# a window whose content got shorter (a wrapped line measured before its width was known) keeps its old height:
	# `resized` only fires when it grows; the victory window had 30 px of empty frame under its buttons (QA round 2)
	if visible and panel != null and not panel.size.is_equal_approx(panel.get_combined_minimum_size()): _centre()
	if not is_open() or not closable or Engine.get_process_frames() == _opened_frame: return
	if _sub_panel_open(): return
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	if keys != null and (keys.back_pressed() or _extra_close_key(keys)): close()

func _extra_close_key(_keys) -> bool:
	return false

func _sub_panel_open() -> bool:
	return false

## A wide button for a window's button column.
static func wide_button(text: String, style: int, icon_name: String, width := 440.0) -> TdButton:
	var b := TdButton.new()
	b.style = style
	b.custom_minimum_size = Vector2(width, 58)
	b.size = Vector2(width, 58)
	b.text = text
	if icon_name != "": b.icon = TdTheme.texture(icon_name)
	return b
