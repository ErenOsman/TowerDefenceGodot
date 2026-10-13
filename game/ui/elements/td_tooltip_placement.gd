class_name TdTooltipPlacement
extends RefCounted
## Where a tooltip box goes (port of the Unity TooltipPlacement), the same for the tooltip and the tooltip stack: try
## the asked side of the edge, then its opposite, then the rest; slide each try inside the bounds; score what it still
## covers (spill past the bounds, the anchor itself, the registered avoid rects such as the board's previewed tiles);
## take the first try that covers nothing, else the one that covers least. Rects are canvas coordinates (y down).

enum Side {
	AUTO,          ## left when the edge is on the right half of the screen, else right
	LEFT,          ## left of the edge, top level with the anchor's top
	RIGHT,         ## right of the edge, top level with the anchor's top
	ABOVE,         ## above the edge, starting at the anchor's left
	ABOVE_CENTRED, ## straight above the edge centred on the anchor, only there (slid inside, never another side)
	BELOW,         ## below the edge, its right side lined up with the edge's
}

## Space between the box and the edge it opens beside.
const GAP := 8.0
## Space kept from the bounds' sides.
const PADDING := 8.0

static var _avoid: Dictionary = {} # owner -> Array[Rect2]

## Registers rects (canvas coordinates) tooltips should keep clear of; an owner replaces its own, empty clears them.
static func set_avoid(owner: Object, rects: Array) -> void:
	if owner == null: return
	var id := owner.get_instance_id()
	if rects.is_empty(): _avoid.erase(id)
	else: _avoid[id] = rects.duplicate()

## Every registered avoid rect.
static func avoid_rects() -> Array:
	var out := []
	for k in _avoid: out.append_array(_avoid[k])
	return out

static func clear_avoid() -> void:
	_avoid.clear()

## The box's top-left corner and the side it ended on: {"position": Vector2, "side": Side}.
## bounds = the canvas (viewport visible rect), size = the box, anchor = the hovered element, edge = what it opens
## beside (often the anchor itself, or the bar the anchor sits in), avoid = extra rects (null: the registered ones).
static func solve(bounds: Rect2, size: Vector2, anchor: Rect2, edge: Rect2, side: int, avoid = null) -> Dictionary:
	var keep_clear: Array = avoid if avoid is Array else avoid_rects()
	var best := Vector2.ZERO
	var best_score := INF
	var chosen := side
	var order: Array = [Side.ABOVE_CENTRED] if side == Side.ABOVE_CENTRED else order_for(side, edge, bounds)
	var inner := inset(bounds)
	for s in order:
		var box := beside(size, anchor, edge, s)
		var spill := area(box) - overlap(box, inner)
		box = slide(box, bounds)
		var score := spill + overlap(box, anchor)
		for r in keep_clear: score += overlap(box, r)
		if score < best_score - 0.5:
			best_score = score
			best = box.position
			chosen = s
		if best_score <= 0.5: break
	return {"position": best, "side": chosen}

## The asked side first (Auto: away from the screen side the edge is on), then its opposite, then the rest.
static func order_for(side: int, edge: Rect2, bounds: Rect2) -> Array:
	var first := side
	if side == Side.AUTO:
		first = Side.LEFT if edge.get_center().x > bounds.get_center().x else Side.RIGHT
	var out := [first, opposite(first)]
	for s in [Side.LEFT, Side.RIGHT, Side.ABOVE, Side.BELOW]:
		if s != first and s != opposite(first): out.append(s)
	return out

static func opposite(s: int) -> int:
	match s:
		Side.LEFT: return Side.RIGHT
		Side.RIGHT: return Side.LEFT
		Side.ABOVE, Side.ABOVE_CENTRED: return Side.BELOW
		_: return Side.ABOVE

## The box on one side of the edge: left / right with its top level with the anchor's top; above starting at the
## anchor's left (centred: on the anchor's centre); below with its right side lined up with the edge's.
static func beside(size: Vector2, anchor: Rect2, edge: Rect2, side: int) -> Rect2:
	var x: float
	var top: float
	match side:
		Side.LEFT:
			x = edge.position.x - GAP - size.x; top = anchor.position.y
		Side.ABOVE:
			x = anchor.position.x; top = edge.position.y - GAP - size.y
		Side.ABOVE_CENTRED:
			x = anchor.get_center().x - size.x / 2.0; top = edge.position.y - GAP - size.y
		Side.BELOW:
			x = edge.end.x - size.x; top = edge.end.y + GAP
		_:
			x = edge.end.x + GAP; top = anchor.position.y
	return Rect2(Vector2(x, top), size)

static func inset(bounds: Rect2) -> Rect2:
	return bounds.grow(-PADDING)

## Moves the box inside the bounds (keeping its top on screen when it is taller).
static func slide(box: Rect2, bounds: Rect2) -> Rect2:
	var inner := inset(bounds)
	box.position.x = clampf(box.position.x, inner.position.x, maxf(inner.position.x, inner.end.x - box.size.x))
	box.position.y = clampf(box.position.y, inner.position.y, maxf(inner.position.y, inner.end.y - box.size.y))
	return box

static func area(r: Rect2) -> float:
	return maxf(0.0, r.size.x) * maxf(0.0, r.size.y)

static func overlap(a: Rect2, b: Rect2) -> float:
	var w := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var h := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	return w * h if w > 0.0 and h > 0.0 else 0.0

## Follow-the-mouse placement: point + offset, clamped inside the bounds (padding 8).
static func at_point(bounds: Rect2, size: Vector2, point: Vector2, offset := Vector2(16, 16)) -> Vector2:
	return slide(Rect2(point + offset, size), bounds).position
