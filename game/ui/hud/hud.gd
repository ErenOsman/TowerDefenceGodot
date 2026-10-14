class_name Hud
extends CanvasLayer
## The battle HUD (hud-menu-spec §6, UI Design Rules "In-game HUD" and "Bottom row layout", the Unity build's look),
## added over the level by LevelController (`controller = …` before it enters the tree, `bind(controller)` after).
## Parts: HudTopBar (pills, tracker, Skip, Pause, End turn), HudHandTray (bottom-left), HudActionBar (bottom-centre of
## the free area, slid right of the tray or raised a row by HudLayout), the hint line under the bar (red for
## refusals; the enemy turn's threat summary while End turn is hovered), HudInspector (right), HudSequence (dialogue
## box / pointing bubble), and the popups: HudPause, HudEndScreen, HudInfoPopup (double-click a unit, `I`, or the
## card's Info button). Everything redraws on the controller's `changed`; the top bar every frame. The root and
## full-screen layers ignore the pointer, so only real HUD parts block the board. Keys come from KeyBinds; the
## controller handles ability / End round / Skip / Pause keys and Esc cancelling, the HUD answers them visibly.

var controller: LevelController

var root: Control
var top_bar: HudTopBar
var tray: HudHandTray
var action_bar: HudActionBar
var inspector: HudInspector
var hint_pill: PanelContainer
var hint_label: Label
var sequence: HudSequence
var pause: HudPause
var end_screen: HudEndScreen
var info: HudInfoPopup
## The co-op parts (turn strip, Pass, chat, notices): only when controller.is_coop, else null.
var coop_hud: HudCoop = null
var layout := {}

var _bound := false
var _dirty := true
var _inspector_subject := ""
var _last_click_ms := 0
var _insets_sent := Vector3(-1, -1, -1)

func _ready() -> void:
	layer = 10
	_build()
	if controller != null and not _bound: bind(controller)

func _build() -> void:
	if root != null: return
	root = Control.new()
	root.name = "Root"
	root.theme = TdTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	top_bar = HudTopBar.new()
	top_bar.name = "TopBar"
	root.add_child(top_bar)
	tray = HudHandTray.new()
	root.add_child(tray)
	action_bar = HudActionBar.new()
	action_bar.visible = false
	root.add_child(action_bar)
	hint_pill = HudArt.panel("pill_wood", [20, 6, 20, 8])
	hint_pill.name = "Hint"
	hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_pill.visible = false
	root.add_child(hint_pill)
	hint_label = HudArt.label("", "body", TdTheme.color("cream.100"))
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_pill.add_child(hint_label)
	inspector = HudInspector.new()
	inspector.visible = false
	root.add_child(inspector)
	inspector.info_pressed.connect(func(): if controller != null and controller.selected >= 0: open_info(controller.selected))
	sequence = HudSequence.new()
	sequence.find_ui = find_ui
	sequence.find_piece = func(): return tray.first_in_hand()
	sequence.find_ability = func(kind): return action_bar.button_for(kind) if action_bar.visible else null
	root.add_child(sequence)
	pause = HudPause.new()
	pause.name = "Pause"
	root.add_child(pause)
	pause.closed.connect(func():
		_panels_changed()
		_dirty = true)
	end_screen = HudEndScreen.new()
	end_screen.name = "EndScreen"
	root.add_child(end_screen)
	info = HudInfoPopup.new()
	info.name = "Info"
	root.add_child(info)
	info.closed.connect(_panels_changed)
	top_bar.pause_pressed.connect(open_pause)

## Connects to the level (the controller calls it once the HUD is in the tree).
func bind(c: LevelController) -> void:
	controller = c
	_build()
	if _bound or c == null: return
	_bound = true
	for part in [top_bar, tray, action_bar, inspector, sequence, pause, end_screen, info]: part.controller = c
	c.changed.connect(func(_v): _dirty = true)
	c.message_changed.connect(func(_t): _dirty = true)
	c.sequence_changed.connect(func(): _dirty = true)
	c.pause_requested.connect(open_pause)
	c.level_ended.connect(_on_level_ended)
	if c.is_coop and coop_hud == null:
		coop_hud = HudCoop.new()
		root.add_child(coop_hud)
		root.move_child(coop_hud, pause.get_index()) # under the popups
		coop_hud.bind(c, top_bar)
	var keys = get_tree().root.get_node_or_null("KeyBinds") if is_inside_tree() else null
	if keys != null and keys.has_signal("changed"): keys.changed.connect(func():
		top_bar.keys_changed()
		_dirty = true)
	if c.converter != null:
		var names := []
		for d in c.converter.built("StatusDef"):
			if not d.has_tag(Tags.Hidden): names.append(d.display_name)
		TooltipText.set_keywords(names)
	# tooltips are 340 wide in the battle (UI Design Rules, Tooltip); back to the kit's width when the level goes
	TdTooltip.box().set_box_width(340)
	_dirty = true

func _exit_tree() -> void:
	if is_instance_valid(TdTooltip._layer): TdTooltip.box().set_box_width(TdTooltipBox.WIDTH)

## A HUD element by node name (sequence lines point at "EndTurnButton", "HandTray", …), or null.
func find_ui(element: String) -> Control:
	if root == null: return null
	return root.find_child(element, true, false) as Control

# ------------------------------------------------------------------ popups

func open_pause() -> void:
	if controller == null or pause.is_open() or end_screen.visible: return
	TdTooltip.hide_immediate()
	inspector.visible = false
	pause.open()
	_panels_changed()

func open_info(id: int) -> void:
	if controller == null or end_screen.visible or pause.is_open(): return
	TdTooltip.hide_immediate()
	info.show_entity(id)
	_panels_changed()

func _on_level_ended(outcome: int) -> void:
	if pause.is_open(): pause.close()
	if info.is_open(): info.close()
	TdTooltip.hide_immediate()
	end_screen.show_outcome(outcome)
	_panels_changed()

func _panels_changed() -> void:
	if controller == null: return
	controller.ui_panel_open = pause.is_open() or info.is_open() or end_screen.visible
	# a mid-screen banner ("Round 9") never shows over a window
	if controller.overlay != null and controller.overlay.banners != null:
		controller.overlay.banners.visible = not controller.ui_panel_open
	# nor do the board's plates (a selected unit's dark plate backing showed through the scrim)
	if controller.overlay != null and controller.overlay.plates != null:
		controller.overlay.plates.visible = not controller.ui_panel_open or (coop_hud != null and coop_hud.typing())

# ------------------------------------------------------------------ refresh

func _process(_delta: float) -> void:
	if controller == null or controller.session == null: return
	_panels_changed()
	if _dirty:
		_dirty = false
		_refresh()
	_layout()
	_hint()
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	if keys != null and not controller.ui_panel_open and keys.key_pressed(KEY_I) and controller.selected >= 0:
		open_info(controller.selected)
	# the story box is up: the hand and the bar step back
	var back := sequence.box_shown()
	tray.modulate.a = 0.8 if back else 1.0
	action_bar.modulate.a = 0.8 if back else 1.0

func _refresh() -> void:
	tray.refresh()
	var bar_wanted := action_bar.wanted(controller)
	if bar_wanted: action_bar.refresh()
	action_bar.visible = bar_wanted
	var subject = inspector.subject(controller)
	var key := ""
	if subject != null: key = ("e%d" % subject["entity"].id) if subject["entity"] != null else "t" + subject["hand"].id
	if subject != null:
		inspector.refresh()
		if not inspector.visible or key != _inspector_subject: inspector.play_open()
	# the guided tutorial keeps the card closed until its free-play line: one thing to look at, one thing to click
	var guided_card := controller.guided == null or not controller.guided.hides_card
	inspector.visible = subject != null and not pause.is_open() and not end_screen.visible and guided_card
	_inspector_subject = key

func _layout() -> void:
	var screen := root.size
	var pieces := tray.piece_count()
	tray.position = HudLayout.tray_rect(screen, pieces).position
	tray.size = Vector2(HudLayout.tray_width(pieces), HudLayout.TRAY_H)
	var bar_w := action_bar.get_combined_minimum_size().x
	layout = HudLayout.bottom_row(screen, pieces, action_bar.buttons_shown, bar_w)
	if action_bar.visible:
		var r: Rect2 = layout["bar"]
		action_bar.size = action_bar.get_combined_minimum_size()
		action_bar.position = Vector2(r.position.x, r.end.y - action_bar.size.y)
	var bottom: float = layout["bottom_inset"] if action_bar.visible else HudLayout.TRAY_H
	# while the guided tutorial speaks, the board is framed above its dialogue box (a small board such as the
	# tutorial's 7×5 would otherwise fill the screen and sit under the box)
	if controller.guided != null and not controller.guided.finished and sequence != null:
		bottom = maxf(bottom, sequence.guided_bottom_inset())
	# top bar + bottom row only: the board is centred on the whole width (the card may cover its edge)
	_send_insets(HudLayout.TOP_BAR, bottom, 0.0)

## Tells the camera what the HUD covers (the controller's set_hud_insets when it has one, else the camera's insets).
func _send_insets(top: float, bottom: float, right: float) -> void:
	var v := Vector3(top, bottom, right)
	if v == _insets_sent: return
	_insets_sent = v
	if controller.has_method("set_hud_insets"):
		controller.set_hud_insets(top, bottom, right)
	elif controller.camera != null and "hud_insets" in controller.camera:
		var h: Vector4 = controller.camera.hud_insets
		controller.camera.hud_insets = Vector4(h.x, right, top, bottom)

## The hint line's text (the controller's hint, worded for the HUD): a target aim says "a marked enemy" (walks and
## placing keep the tile wording); the End turn threat summary is the End turn tooltip's, never the hint's.
static func hint_text(hint: String, aiming_target: bool, threat: String) -> String:
	if threat != "" and hint == threat: return ""
	if aiming_target and hint.begins_with("Click a green tile"): return "Click a marked enemy. Right-click cancels."
	return hint

func _hint() -> void:
	var aim: AbilityDef = controller.aiming
	var threat: String = controller.threat_summary if controller.preview_enemy_phase and "threat_summary" in controller else ""
	var text := hint_text(controller.hint, aim != null and not aim.targeting.is_movement, threat)
	var refusal: bool = controller.hint_is_refusal
	if controller.ui_panel_open: text = ""
	# one voice: while the guided tutorial speaks, its dialogue box says what to do and what was wrong
	if controller.guided != null and not controller.guided.finished: text = ""
	hint_pill.visible = text != ""
	if text == "": return
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", TdTheme.color("bad") if refusal else TdTheme.color("cream.100"))
	hint_pill.size = hint_pill.get_combined_minimum_size()
	var w := hint_pill.size.x
	var screen := root.size
	var x: float
	var y: float
	var centred: bool
	if action_bar.visible:
		x = layout["hint_x"]; y = layout["hint_y"]; centred = layout["hint_centred"]
	else:
		var h := HudLayout.hint_without_bar(screen, tray.piece_count(), w)
		x = h["x"]; y = h["y"]; centred = h["centred"]
	var left := x - w / 2.0 if centred else x
	hint_pill.position = Vector2(HudLayout.hint_left(left, w, screen, tray.piece_count(), action_bar.visible and not layout.get("raised", false), action_bar.position.x), y)

# ------------------------------------------------------------------ board double-click → Info

func _unhandled_input(event: InputEvent) -> void:
	if controller == null or controller.ui_panel_open: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
		var h = controller.hover
		if h == null or controller.shown == null: return
		for f in controller.shown.entities.values():
			if f.position != null and f.pos == h and f.life == LifeState.Alive:
				open_info(f.id)
				return
