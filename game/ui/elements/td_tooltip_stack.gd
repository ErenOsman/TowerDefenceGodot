class_name TdTooltipStack
extends RefCounted
## One tooltip made of several paper boxes stacked top to bottom (port of TooltipStack), e.g. one per status of a
## unit. The column's top lines up with the anchor's top and it opens beside an edge (the anchor itself when null),
## moved off what it would cover like the tooltip; boxes hug the edge. No footer, no tail. Only one of tooltip / stack
## shows at a time.
##   TdTooltipStack.show(owner, anchor, items, side := Side.AUTO, edge := null, also_beside := null)
##       items: [[header, body], …] or [{header, body}, …] (TooltipText.status(...) dictionaries work)
##       anchor / edge / also_beside: Control or Rect2; also_beside widens the edge to cover another rect too
##   TdTooltipStack.hide(owner := null), TdTooltipStack.is_shown_by(owner)

const Side = TdTooltipPlacement.Side

static func show(owner: Object, anchor, items: Array, side: int = Side.AUTO, edge = null, also_beside = null) -> void:
	if anchor == null or items.is_empty():
		hide(owner)
		return
	var a := TdTooltip._rect_of(anchor)
	var e := TdTooltip._rect_of(edge) if edge != null else a
	if also_beside != null: e = e.merge(TdTooltip._rect_of(also_beside))
	TdTooltip.layer().show_stack(owner, items, a, e, side)

## Hides the boxes; with an owner, only if that owner showed them last.
static func hide(owner: Object = null) -> void:
	if is_instance_valid(TdTooltip._layer): TdTooltip._layer.hide_stack(owner)

static func is_shown_by(owner: Object) -> bool:
	return owner != null and is_instance_valid(TdTooltip._layer) and TdTooltip._layer.stack_owner == owner and TdTooltip._layer.stack_root.visible
