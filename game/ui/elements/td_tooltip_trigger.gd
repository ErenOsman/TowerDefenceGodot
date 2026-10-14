class_name TdTooltipTrigger
extends Node
## Shows a tooltip while the pointer rests on its parent Control (port of UI_TooltipTrigger + UI_TooltipStackTrigger).
## Add it as a child of any Control (or TdTooltipTrigger.attach(control, header, body)). After `delay` (never less
## than motion.tooltip_delay, 0.4 s) the tooltip opens by `position_mode`, or beside an edge after set_placement();
## leaving hides it, but only if it is still this trigger's (TdTooltip.own / hide(owner)). With set_stack(items) it
## shows a TdTooltipStack instead. An open tooltip follows content changes (set_content while showing).

enum PositionMode { FOLLOW_MOUSE, MOUSE_STATIC, ANCHOR_FOLLOW, ANCHOR_STATIC }

@export var header := ""
@export_multiline var body := ""
@export var footer_label := ""
@export var footer_value := ""
@export var delay := 0.4
@export var position_mode := PositionMode.FOLLOW_MOUSE
## Nothing shows while false (e.g. a row whose tooltip is empty for now).
@export var enabled := true

var _side := -1
var _edge: Control = null
var _stack: Array = []
var _hovering := false
var _showing := false
var _timer := 0.0
var _target: Control

## Adds a trigger to a control and returns it.
static func attach(control: Control, header_text := "", body_text := "", footer_label_text := "", footer_value_text := "") -> TdTooltipTrigger:
	var t := find_on(control)
	if t == null:
		t = TdTooltipTrigger.new()
		control.add_child(t)
	t.set_content(header_text, body_text, footer_label_text, footer_value_text)
	return t

## The trigger on a control, or null.
static func find_on(control: Control) -> TdTooltipTrigger:
	if control == null: return null
	for c in control.get_children():
		if c is TdTooltipTrigger: return c
	return null

## Forgets every trigger's hover and hides the tooltip: for a window opening over them. Godot re-sends hover
## enter/exit only on pointer motion, so without this a tooltip stays drawn over the window, or a pending one
## (pointer resting on Pause, the window opened by key) opens over it after the delay. Leaving the window and
## moving onto a control again starts its tooltip as usual.
static func reset_all(tree: SceneTree) -> void:
	if tree != null:
		for t in tree.get_nodes_in_group(GROUP):
			var trig := t as TdTooltipTrigger
			if trig == null: continue
			trig._hovering = false
			trig._showing = false
			trig._timer = 0.0
	TdTooltip.hide_immediate()
	TdTooltipStack.hide()

const GROUP := "td_tooltip_triggers"

func _enter_tree() -> void:
	add_to_group(GROUP)
	_target = get_parent() as Control
	if _target == null: return
	if not _target.mouse_entered.is_connected(_on_enter):
		_target.mouse_entered.connect(_on_enter)
		_target.mouse_exited.connect(_on_exit)
	if _target.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_target.mouse_filter = Control.MOUSE_FILTER_PASS

func _exit_tree() -> void:
	_close()
	_hovering = false
	if _target != null and _target.mouse_entered.is_connected(_on_enter):
		_target.mouse_entered.disconnect(_on_enter)
		_target.mouse_exited.disconnect(_on_exit)

func set_content(header_text: String, body_text: String, footer_label_text := "", footer_value_text := "") -> void:
	var changed := header != header_text or body != body_text or footer_label != footer_label_text or footer_value != footer_value_text
	header = header_text
	body = body_text
	footer_label = footer_label_text
	footer_value = footer_value_text
	if changed and _showing: _open()

## A TooltipText content dictionary.
func set_tooltip(c: Dictionary) -> void:
	set_content(c.get("header", ""), c.get("body", ""), c.get("footer_label", ""), c.get("footer_value", ""))

func set_footer(label_text: String, value_text: String) -> void:
	set_content(header, body, label_text, value_text)

## Opens beside an edge instead of the position mode (TdTooltip.show_beside): e.g. left of the side bar the element
## sits in, or above the bottom bar. Edge null: the element itself. side < 0 goes back to the position mode.
func set_placement(side: int, edge: Control = null) -> void:
	_side = side
	_edge = edge

## Shows a stack of boxes instead ([[header, body], …]; empty: back to the single tooltip).
func set_stack(items: Array, side: int = TdTooltipPlacement.Side.AUTO, edge: Control = null) -> void:
	_stack = items.duplicate()
	_side = side
	_edge = edge
	if _showing: _open()

func is_showing() -> bool:
	return _showing

func _on_enter() -> void:
	_hovering = true
	_timer = 0.0

func _on_exit() -> void:
	_hovering = false
	_timer = 0.0
	_close()

func _process(delta: float) -> void:
	if not _hovering or _showing or not enabled: return
	_timer += TdTheme.unscaled(delta)
	if _timer >= maxf(delay, TdTheme.motion("tooltip_delay")):
		_open()

func _open() -> void:
	if _target == null: return
	if not _stack.is_empty():
		_showing = true
		TdTooltipStack.show(self, _target, _stack, _side if _side >= 0 else TdTooltipPlacement.Side.AUTO, _edge)
		return
	if header == "" and body == "": return
	_showing = true
	if _side >= 0:
		TdTooltip.show_beside(_target, _side, _edge, body, header, footer_label, footer_value)
	else:
		match position_mode:
			PositionMode.FOLLOW_MOUSE: TdTooltip.show(body, header, footer_label, footer_value, true)
			PositionMode.MOUSE_STATIC: TdTooltip.show(body, header, footer_label, footer_value, false)
			PositionMode.ANCHOR_FOLLOW: TdTooltip.show_at(_target, body, header, footer_label, footer_value, true)
			PositionMode.ANCHOR_STATIC: TdTooltip.show_at(_target, body, header, footer_label, footer_value, false)
	TdTooltip.own(self)

func _close() -> void:
	if not _showing: return
	_showing = false
	TdTooltip.hide(self)
	TdTooltipStack.hide(self)
