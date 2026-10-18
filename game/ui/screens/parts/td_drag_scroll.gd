class_name TdDragScroll
extends Node
## Makes a ScrollContainer comfortable with a mouse: a visible 12 px scrollbar (PaperVScrollBar on paper), the wheel
## (built in), and left-button drag-to-scroll over the content that does not break clicks on rows and buttons: a
## press is left alone until the pointer moves more than THRESHOLD px; then the press is cancelled for the control
## under it (a release far outside it, so it does not click) and the content follows the pointer until release.
##   TdDragScroll.attach(scroll, true)

const THRESHOLD := 6.0
const BAR_WIDTH := 12.0

var scroll: ScrollContainer
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _start_scroll := 0
var _cancelling := false

static func attach(s: ScrollContainer, paper := false) -> TdDragScroll:
	var bar := s.get_v_scroll_bar()
	if paper: bar.theme_type_variation = "PaperVScrollBar"
	bar.custom_minimum_size.x = BAR_WIDTH
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return attach_drag(s)

## Only the drag-to-scroll (no bar styling), once per scroll: the DragScroll autoload gives it to every menu scroll.
static func attach_drag(s: ScrollContainer) -> TdDragScroll:
	if s.has_meta(META):
		var had = s.get_meta(META)
		if is_instance_valid(had): return had
	var d := TdDragScroll.new()
	d.scroll = s
	s.set_meta(META, d)
	s.add_child(d, false, Node.INTERNAL_MODE_BACK)
	return d

const META := "td_drag_scroll"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## A press whose release never came back (QA 2026-10-15, Eren: after picking from a dropdown the list followed the
## mouse as if the button were held): a dropdown's PopupMenu is its own Window, so the release went there. The press
## state is dropped as soon as the left button is no longer down, and when the pointer leaves the window or it loses
## focus.
func _process(_delta: float) -> void:
	if (_down or _dragging) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): release()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]: release()

## Forgets the press (no drag until the next press).
func release() -> void:
	_down = false
	_dragging = false

## Whether it thinks the left button is held over its list (a press, or a drag in progress).
func is_holding() -> bool:
	return _down or _dragging

func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree() or _cancelling: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x < -50000.0: return # our own cancelling release: let it through to the pressed control
		if event.pressed:
			_down = scroll.get_global_rect().has_point(event.position) and not _over_bar(event.position) and _on_top() \
				and not _over_drag_source()
			_dragging = false
			_start = event.position
			_start_scroll = scroll.scroll_vertical
		else:
			if _dragging: scroll.get_viewport().set_input_as_handled()
			_down = false
			_dragging = false
	elif event is InputEventMouseMotion and _down:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT): # the release went elsewhere (a popup window)
			release()
			return
		if not _dragging and event.position.distance_to(_start) > THRESHOLD:
			if scroll.get_v_scroll_bar().max_value <= scroll.size.y: # nothing to scroll
				_down = false
				return
			_dragging = true
			_cancel_press()
		if _dragging:
			var scale := scroll.get_global_transform_with_canvas().get_scale().y
			scroll.scroll_vertical = _start_scroll - int((event.position.y - _start.y) / maxf(scale, 0.001))
			scroll.get_viewport().set_input_as_handled()

## The press is on something that starts its own drag-and-drop (a hand-editor tile or hand slot: meta "drag_source"):
## that drag wins, the list does not scroll.
func _over_drag_source() -> bool:
	var n: Node = scroll.get_viewport().gui_get_hovered_control()
	while n != null and n != scroll:
		if n is Control and n.get_meta("drag_source", false): return true
		# controls that drag by themselves: a slider's knob, text selection
		if n is Slider or n is LineEdit or n is TextEdit: return true
		n = n.get_parent()
	return false

## Not under another popup (only the top popup's lists scroll).
func _on_top() -> bool:
	if TdPopup.open_popups.is_empty(): return true
	var n: Node = scroll
	while n != null and not (n is TdPopup): n = n.get_parent()
	return n == TdPopup.open_popups[TdPopup.open_popups.size() - 1]

func _over_bar(p: Vector2) -> bool:
	var bar := scroll.get_v_scroll_bar()
	return bar.visible and bar.get_global_rect().has_point(p)

## The control that took the press gets a release far away: it un-presses without clicking.
func _cancel_press() -> void:
	_cancelling = true
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = Vector2(-100000, -100000)
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	_cancelling = false
