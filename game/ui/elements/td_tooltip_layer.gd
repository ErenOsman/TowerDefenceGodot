class_name TdTooltipLayer
extends CanvasLayer
## The node behind TdTooltip and TdTooltipStack: a top CanvasLayer (nothing draws over a tooltip or its tail) holding
## the one tooltip box and the stack's boxes, following the mouse or an anchor, fading in and out on unscaled time.
## Made on first use under the scene tree's root; use TdTooltip / TdTooltipStack, not this class.

const LAYER := 120
const FADE_IN := 0.12
const FADE_OUT := 0.08
const MOUSE_OFFSET := Vector2(16, 16)
const ANCHOR_OFFSET := Vector2(0, -8)
const STACK_GAP := 6.0

enum Mode { MOUSE, ANCHOR, BESIDE }

var box: TdTooltipBox
var stack_root: Control
var stack_boxes: Array = []
var shown_by: Object = null
var stack_owner: Object = null
var visible_now := false

var _mode := Mode.MOUSE
var _follow := false
var _anchor: Control = null
var _anchor_rect := Rect2()
var _edge_rect := Rect2()
var _side := 0
var _pending: Callable = Callable() # a request made before the layer entered the tree
var _fade: Tween

func _init() -> void:
	layer = LAYER
	name = "TdTooltipLayer"
	box = TdTooltipBox.new()
	box.modulate.a = 0.0
	box.visible = false
	add_child(box)
	stack_root = Control.new()
	stack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_root.visible = false
	add_child(stack_root)

func _ready() -> void:
	if _pending.is_valid():
		var p := _pending
		var owner_then := shown_by # own() came right after the early show: keep it
		var stack_owner_then := stack_owner
		_pending = Callable()
		p.call()
		shown_by = owner_then
		if stack_owner_then != null: stack_owner = stack_owner_then

func bounds() -> Rect2:
	return get_viewport().get_visible_rect() if is_inside_tree() else Rect2(0, 0, 1920, 1080)

## Shows the one tooltip. mode MOUSE (anchor ignored), ANCHOR (near anchor_control's top-right), BESIDE (anchor_rect
## and edge_rect with the placement solver).
func show_tooltip(header: String, body: String, footer_label: String, footer_value: String, mode: int, follow: bool,
		anchor_control: Control, anchor_rect: Rect2, edge_rect: Rect2, side: int) -> void:
	if not is_inside_tree():
		_pending = show_tooltip.bind(header, body, footer_label, footer_value, mode, follow, anchor_control, anchor_rect, edge_rect, side)
		return
	hide_stack()
	shown_by = null
	_mode = mode
	_follow = follow
	_anchor = anchor_control
	_anchor_rect = anchor_rect
	_edge_rect = edge_rect
	_side = side
	box.visible = true
	box.set_content(header, body, footer_label, footer_value)
	box.set_tail(false)
	_place()
	visible_now = true
	_fade_to(1.0, FADE_IN)

func hide_tooltip(instant := false) -> void:
	_pending = Callable()
	if not visible_now and not instant: return
	visible_now = false
	_anchor = null
	if instant:
		if _fade: _fade.kill()
		box.modulate.a = 0.0
		box.visible = false
	else:
		_fade_to(0.0, FADE_OUT)

func _fade_to(a: float, seconds: float) -> void:
	if _fade: _fade.kill()
	_fade = TdTheme.tween(self)
	_fade.tween_property(box, "modulate:a", a, seconds)
	if a <= 0.0:
		_fade.tween_callback(_after_fade_out)

func _after_fade_out() -> void:
	if not visible_now: box.visible = false

func _process(_delta: float) -> void:
	if visible_now and _follow:
		_place()

func _place() -> void:
	var b := bounds()
	match _mode:
		Mode.MOUSE:
			box.position = TdTooltipPlacement.at_point(b, box.size, get_viewport().get_mouse_position(), MOUSE_OFFSET)
		Mode.ANCHOR:
			if is_instance_valid(_anchor):
				var r := _anchor.get_global_rect()
				# above the anchor's top-right corner, clamped inside
				var p := Vector2(r.end.x, r.position.y) + ANCHOR_OFFSET - Vector2(0, box.size.y)
				box.position = TdTooltipPlacement.slide(Rect2(p, box.size), b).position
		Mode.BESIDE:
			var anchor := _anchor.get_global_rect() if is_instance_valid(_anchor) and _follow else _anchor_rect
			var res := TdTooltipPlacement.solve(b, box.size + Vector2(0, box.tail_length()), anchor, _edge_rect, _side)
			var chosen: int = res["side"]
			var pos: Vector2 = res["position"]
			var above := chosen == TdTooltipPlacement.Side.ABOVE or chosen == TdTooltipPlacement.Side.ABOVE_CENTRED
			var below := chosen == TdTooltipPlacement.Side.BELOW
			if below: pos.y += box.tail_length(false)
			box.position = pos.round()
			box.set_tail(above or below, above, anchor.get_center().x - box.position.x)

# ------------------------------------------------------------------ stack

func show_stack(owner: Object, items: Array, anchor: Rect2, edge: Rect2, side: int) -> void:
	if not is_inside_tree():
		_pending = show_stack.bind(owner, items, anchor, edge, side)
		stack_owner = owner
		return
	hide_tooltip(true)
	stack_owner = owner
	stack_root.visible = true
	while stack_boxes.size() < items.size():
		var nb := TdTooltipBox.new()
		stack_root.add_child(nb)
		stack_boxes.append(nb)
	var width := 0.0
	var height := 0.0
	for i in stack_boxes.size():
		var bx: TdTooltipBox = stack_boxes[i]
		bx.visible = i < items.size()
		if not bx.visible: continue
		var it = items[i]
		var h: String = it[0] if it is Array else str(it.get("header", ""))
		var bd: String = it[1] if it is Array else str(it.get("body", ""))
		bx.set_content(h, bd)
		height += bx.size.y + (STACK_GAP if i > 0 else 0.0)
		width = maxf(width, bx.size.x)
	var res := TdTooltipPlacement.solve(bounds(), Vector2(width, height), anchor, edge, side)
	var top_left: Vector2 = res["position"]
	var to_left := top_left.x + width <= edge.position.x + 0.5 # left of the edge: boxes hug the edge
	var y := top_left.y
	for i in items.size():
		var bx: TdTooltipBox = stack_boxes[i]
		bx.position = Vector2(top_left.x + width - bx.size.x if to_left else top_left.x, y).round()
		y += bx.size.y + STACK_GAP
	stack_root.modulate.a = 0.0
	var tw := TdTheme.tween(self)
	tw.tween_property(stack_root, "modulate:a", 1.0, FADE_IN)

func hide_stack(owner: Object = null) -> void:
	if owner != null and owner != stack_owner: return
	if not is_inside_tree(): _pending = Callable()
	stack_owner = null
	stack_root.visible = false
