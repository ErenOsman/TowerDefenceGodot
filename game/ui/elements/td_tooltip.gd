class_name TdTooltip
extends RefCounted
## The game's one tooltip (port of UI_Tooltip): a paper box on the top layer with a coloured header, a body and an
## optional footer band, fading in (0.12 s) and out (0.08 s) on unscaled time. Static API, made on first use:
##
##   TdTooltip.show(body, header, footer_label, footer_value, follow := true)   follows the mouse
##   TdTooltip.show_at(anchor_control, body, header, …, follow := false)        above the anchor's top-right corner
##   TdTooltip.show_beside(anchor, side, edge, body, header, …)                 beside an edge, with the placement solver
##        (anchor / edge: a Control or a Rect2 in canvas coordinates; edge null = the anchor; a tail points at the
##         anchor when it opens above or below)
##   TdTooltip.show_content(dict, …) / show_content_beside(dict, …)             a TooltipText content dictionary
##   TdTooltip.own(owner); TdTooltip.hide(owner)   hide only if that owner showed it last; hide() hides anyway
##   TdTooltip.hide_immediate(), TdTooltip.is_visible(), TdTooltip.is_shown_by(owner)
## Header / body / footer value are BBCode (TooltipText builds them). Only one of tooltip / stack shows at a time.
## Hover delay (0.4 s) is the trigger's job (TdTooltipTrigger).

const Side = TdTooltipPlacement.Side

static var _layer: TdTooltipLayer

## The layer node (made under the tree's root on first use).
static func layer() -> TdTooltipLayer:
	if is_instance_valid(_layer):
		return _layer
	_layer = TdTooltipLayer.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(_layer)
	return _layer

static func show(body: String, header := "", footer_label := "", footer_value := "", follow := true) -> void:
	layer().show_tooltip(header, body, footer_label, footer_value, TdTooltipLayer.Mode.MOUSE, follow, null, Rect2(), Rect2(), 0)

static func show_at(anchor: Control, body: String, header := "", footer_label := "", footer_value := "", follow := false) -> void:
	if anchor == null: return
	layer().show_tooltip(header, body, footer_label, footer_value, TdTooltipLayer.Mode.ANCHOR, follow, anchor, Rect2(), Rect2(), 0)

## Beside an edge: Side.LEFT / RIGHT (top level with the anchor's top), ABOVE (from the anchor's left), ABOVE_CENTRED
## (centred on the anchor, only above), BELOW, AUTO (away from the screen side the edge is on). The box moves off
## whatever it would cover (bounds, the anchor, TdTooltipPlacement.set_avoid rects).
static func show_beside(anchor, side: int, edge, body: String, header := "", footer_label := "", footer_value := "", follow := false) -> void:
	var a := _rect_of(anchor)
	var e := _rect_of(edge) if edge != null else a
	var ctl: Control = anchor if anchor is Control else null
	layer().show_tooltip(header, body, footer_label, footer_value, TdTooltipLayer.Mode.BESIDE, follow and ctl != null, ctl, a, e, side)

## A TooltipText content dictionary ({header, body, footer_label, footer_value}) following the mouse.
static func show_content(c: Dictionary, follow := true) -> void:
	show(c.get("body", ""), c.get("header", ""), c.get("footer_label", ""), c.get("footer_value", ""), follow)

static func show_content_beside(c: Dictionary, anchor, side: int, edge = null) -> void:
	show_beside(anchor, side, edge, c.get("body", ""), c.get("header", ""), c.get("footer_label", ""), c.get("footer_value", ""))

## Marks the tooltip just shown as the owner's: hide(owner) then hides it only while it is still theirs.
static func own(owner: Object) -> void:
	layer().shown_by = owner

## Hides with a fade; with an owner, only if that owner showed it last (own).
static func hide(owner: Object = null) -> void:
	if not is_instance_valid(_layer): return
	if owner != null:
		if owner != _layer.shown_by: return
		_layer.shown_by = null
	_layer.hide_tooltip()

static func hide_immediate() -> void:
	if is_instance_valid(_layer): _layer.hide_tooltip(true)

static func is_visible() -> bool:
	return is_instance_valid(_layer) and _layer.visible_now

static func is_shown_by(owner: Object) -> bool:
	return owner != null and is_visible() and _layer.shown_by == owner

## The box node (for checks and screenshots).
static func box() -> TdTooltipBox:
	return layer().box

static func _rect_of(v) -> Rect2:
	if v is Control: return (v as Control).get_global_rect()
	if v is Rect2: return v
	if v is Vector2: return Rect2(v, Vector2.ZERO)
	return Rect2()
