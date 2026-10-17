extends RefCounted
## The rect math of the edge-clip probe (tools/qa/probe_clipping.gd; UI Design Rules — Design § Edge clip), apart from
## any screen so tests/test_clip_probe.gd can run it on a synthetic tree.
##   var recs := ClipMath.collect(screen_root)      # the visible Controls as plain records (below)
##   var finds := ClipMath.findings(recs)          # [{path, edges, px, check, against}]
## A record: {path: String, rect: Rect2 (global), over: Vector4 (l, t, r, b: what it draws past its rect),
##   parent: int (index of the nearest recorded ancestor, -1 for none), clip: bool (clip_contents), scroll_h / scroll_v:
##   bool (a ScrollContainer that scrolls that way), content: Rect2 (a scroll's content child), card: bool (a
##   PanelContainer / Panel with a drawn StyleBox), known: String (an overhang drawer's kind, "" for none)}.
## Checks:
##   a  the drawn rect leaves the rect of an ancestor with clip_contents (along a scroll's axis: that rect merged with
##      its content's, so rows cut by scrolling are fine; a control wholly outside a clip rect is slid / scrolled
##      away: skipped);
##   b  the drawn rect leaves the nearest card ancestor's rect (axes scrolled by a ScrollContainer in between skipped);
##   c  as a or b, but only the overhang leaves (ring stroke, sprite outset, expand margin, button bleed) or the
##      control is a known overhang drawer (portrait ring, Lv chip, form badge) placed with negative offsets.
## A child that overflows the same ancestor on the same edges no further than its parent is not reported again.

const TOL := 1.0
## Node names / classes of the decorations that sit at a portrait's edge by design (checked as overhang drawers).
const KNOWN_NAMES := ["Ring", "LvChip", "FormBadge", "ReadyMark", "TiredBadge"]

# ------------------------------------------------------------------ pure math

## How far `r` reaches past `limit` on each side (positive = outside), Vector4(l, t, r, b).
static func overflow(r: Rect2, limit: Rect2) -> Vector4:
	return Vector4(limit.position.x - r.position.x, limit.position.y - r.position.y, r.end.x - limit.end.x, r.end.y - limit.end.y)

## The rect grown by an overhang Vector4(l, t, r, b).
static func grown(r: Rect2, o: Vector4) -> Rect2:
	return r.grow_individual(o.x, o.y, o.z, o.w)

## The edges of an overflow past the tolerance ("left", "top", "right", "bottom"); axes in `skip` (Vector2: x / y
## non-zero = skip that axis) are left out.
static func edges_of(ov: Vector4, skip := Vector2.ZERO, tol := TOL) -> PackedStringArray:
	var out := PackedStringArray()
	if skip.x == 0.0 and ov.x > tol: out.append("left")
	if skip.y == 0.0 and ov.y > tol: out.append("top")
	if skip.x == 0.0 and ov.z > tol: out.append("right")
	if skip.y == 0.0 and ov.w > tol: out.append("bottom")
	return out

static func _px(ov: Vector4, edges: PackedStringArray) -> float:
	var m := 0.0
	if edges.has("left"): m = maxf(m, ov.x)
	if edges.has("top"): m = maxf(m, ov.y)
	if edges.has("right"): m = maxf(m, ov.z)
	if edges.has("bottom"): m = maxf(m, ov.w)
	return m

## The clip limit of a clipping record: its rect, but along a scrolling axis its rect merged with its content's rect
## (a row cut only because the list is scrolled is fine; what reaches past the content's own edge is cut at one end
## of the scroll; a content shorter than the scroll is cut by the scroll's rect).
static func clip_limit(rec: Dictionary) -> Rect2:
	var r: Rect2 = rec.rect
	var c: Rect2 = rec.get("content", Rect2())
	if c.size == Vector2.ZERO: return r
	var m := r.merge(c)
	if rec.get("scroll_h", false): r = Rect2(Vector2(m.position.x, r.position.y), Vector2(m.size.x, r.size.y))
	if rec.get("scroll_v", false): r = Rect2(Vector2(r.position.x, m.position.y), Vector2(r.size.x, m.size.y))
	return r

## Every finding of a record list (see the header).
static func findings(recs: Array, tol := TOL) -> Array:
	var out := []
	var by_node := {} # index → its findings (for the parent dedupe)
	for i in recs.size():
		var rec: Dictionary = recs[i]
		var bare: Rect2 = rec.rect
		var drawn := grown(bare, rec.get("over", Vector4.ZERO))
		var known: bool = rec.get("known", "") != ""
		var mine := []
		var skip := Vector2.ZERO # axes scrolled by a ScrollContainer between the record and the ancestor
		var card_done := false
		var gone := false
		var j: int = rec.get("parent", -1)
		while j >= 0:
			var anc: Dictionary = recs[j]
			if anc.get("clip", false):
				var vis: Rect2 = anc.rect
				if not drawn.intersects(vis):
					gone = true # slid or scrolled out of sight entirely
					break
				var lim := clip_limit(anc)
				var e := edges_of(overflow(drawn, lim), Vector2.ZERO, tol)
				if not e.is_empty():
					mine.append(_find(rec, anc, "a", e, overflow(drawn, lim), overflow(bare, lim), known, tol))
			if anc.get("card", false) and not card_done:
				card_done = true
				var e2 := edges_of(overflow(drawn, anc.rect), skip, tol)
				if not e2.is_empty():
					mine.append(_find(rec, anc, "b", e2, overflow(drawn, anc.rect), overflow(bare, anc.rect), known, tol))
			if anc.get("scroll_h", false): skip.x = 1.0
			if anc.get("scroll_v", false): skip.y = 1.0
			j = anc.get("parent", -1)
		if gone: mine = []
		by_node[i] = mine
		var p: int = rec.get("parent", -1)
		for f in mine:
			if p >= 0 and _repeats(f, by_node.get(p, [])): continue
			out.append(f)
	return out

static func _find(rec: Dictionary, anc: Dictionary, check: String, e: PackedStringArray, ov: Vector4, ov_bare: Vector4, known: bool, tol: float) -> Dictionary:
	# c: only the drawn overhang leaves (the bare rect stays inside on those edges), or a known decoration
	var bare_e := edges_of(ov_bare, Vector2.ZERO, tol)
	var only_over := true
	for x in e: if bare_e.has(x): only_over = false
	return {"path": rec.path, "edges": e, "px": _px(ov, e), "check": "c" if (only_over or known) else check,
		"rule": check, "against": anc.path, "ov": ov}

## The parent already reports this ancestor on these edges at least as far.
static func _repeats(f: Dictionary, parent_finds: Array) -> bool:
	for pf in parent_finds:
		if pf.against != f.against or pf.rule != f.rule: continue
		var all_in := true
		var pov: Vector4 = pf.ov
		var ov: Vector4 = f.ov
		for x in f.edges:
			if not pf.edges.has(x): all_in = false
			elif x == "left" and ov.x > pov.x + 0.5: all_in = false
			elif x == "top" and ov.y > pov.y + 0.5: all_in = false
			elif x == "right" and ov.z > pov.z + 0.5: all_in = false
			elif x == "bottom" and ov.w > pov.w + 0.5: all_in = false
		if all_in: return true
	return false

## One finding as the probe's output line: "<screen> <node path> <edge(s)> <px>" plus the check and the ancestor.
static func line(screen: String, f: Dictionary) -> String:
	var what: String = {"a": "cut by clip", "b": "outside card", "c": "overhang " + ("cut by clip" if f.rule == "a" else "outside card")}[f.check]
	return "%s %s %s %d  [%s: %s %s]" % [screen, f.path, ",".join(f.edges), ceili(f.px), f.check, what, f.against]

# ------------------------------------------------------------------ the tree → records

## The visible Controls under `top` (itself included) as records. Hidden or transparent (< 5 % alpha) branches and
## zero-size controls are left out (a zero-size control's children are still walked: holders, anchors).
static func collect(top: Node) -> Array:
	var recs := []
	_walk(top, -1, 1.0, top, recs)
	return recs

static func _walk(n: Node, parent: int, alpha: float, top: Node, recs: Array) -> void:
	var idx := parent
	var a := alpha
	if n is CanvasItem:
		var ci := n as CanvasItem
		if not ci.visible: return
		a *= ci.modulate.a
		if a < 0.05: return
	if n is CanvasLayer and n != top: return # its own layer (tooltips): not part of the screen's layout
	if n is Control:
		var c := n as Control
		var sz := c.size * c.get_global_transform().get_scale()
		if (sz.x >= 1.0 and sz.y >= 1.0) or c.clip_contents:
			idx = recs.size()
			recs.append(record(c, parent, top))
	for ch in n.get_children(): _walk(ch, idx, a, top, recs)

## One Control's record.
static func record(c: Control, parent: int, top: Node) -> Dictionary:
	var rec := {"path": path_of(c, top), "rect": c.get_global_rect(), "over": overhang(c), "parent": parent,
		"clip": c.clip_contents, "card": is_card(c), "known": known_kind(c)}
	if c is ScrollContainer:
		var sc := c as ScrollContainer
		rec.scroll_h = sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		rec.scroll_v = sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		for ch in sc.get_children():
			if ch is Control and not (ch is ScrollBar) and (ch as Control).visible:
				rec.content = (ch as Control).get_global_rect()
				break
	return rec

## A card: a PanelContainer / Panel whose panel StyleBox draws something.
static func is_card(c: Control) -> bool:
	if not (c is PanelContainer or c is Panel): return false
	var sb := c.get_theme_stylebox("panel")
	return sb != null and not (sb is StyleBoxEmpty)

## The kind of a known overhang drawer ("" for none): a portrait ring, Lv chip, form badge, ring line, ready mark.
static func known_kind(c: Control) -> String:
	var nm := String(c.name)
	for k in KNOWN_NAMES: if nm == k or nm.begins_with(k): return k
	var sc: Script = c.get_script()
	if sc != null:
		var g := sc.get_global_name()
		if g in ["TdLvChip", "TdFormBadge"]: return g
		if _is_ring_line(c): return "RingLine"
	# TdMenu.medallion's ring: a TextureRect placed at a negative offset in its holder
	if c is TextureRect and c.position.x < -0.5 and c.position.y < -0.5 and c.get_parent() is Control and not (c.get_parent() is Container): return "Ring"
	return ""

## What a control draws past its rect (l, t, r, b, canvas px): its panel StyleBox's outset / expand margins / shadow,
## a TdTowerCard.RingLine's stroke, a TdButton's bleed when it keeps none inside its rect, a "clip_overhang" meta
## (Vector4) a screen can set on its own drawers.
static func overhang(c: Control) -> Vector4:
	var o := Vector4.ZERO
	if c.has_meta("clip_overhang"): o = c.get_meta("clip_overhang")
	if c is PanelContainer or c is Panel:
		o = _vmax(o, stylebox_overhang(c.get_theme_stylebox("panel")))
	if c.has_method("bleed_active") and c.has_method("bleed") and not bool(c.call("bleed_active")):
		var face: Vector2 = c.custom_minimum_size if c.custom_minimum_size != Vector2.ZERO else c.size
		o = _vmax(o, TdButton.bleed_for(int(c.get("style")), face, bool(c.get("keyboard_focus"))))
	if _is_ring_line(c):
		o = _vmax(o, ring_line_overhang(c.size.x, float(c.get("width")), (c.get("glow") as Color).a > 0.0))
	var s := c.get_global_transform().get_scale()
	return Vector4(o.x * s.x, o.y * s.y, o.z * s.x, o.w * s.y)

static func _is_ring_line(c: Control) -> bool:
	return c.get_script() != null and "colour" in c and "width" in c and "glow" in c

## TdTowerCard.RingLine: an arc of radius 0.515 × size, stroke max(width, 0.055 × size) + 4 (the rim), plus its glow.
static func ring_line_overhang(size: float, width := 4.0, glow := false) -> Vector4:
	var r := size * 0.515
	var w := maxf(width, size * 0.055)
	var ext := r + (w + 4.0) / 2.0 - size / 2.0
	if glow: ext = maxf(ext, r + w + 2.0 + 6.0 * 2.5 + 1.5 - size / 2.0)
	return Vector4(ext, ext, ext, ext)

## How far a StyleBox draws past the rect it is drawn in.
static func stylebox_overhang(sb: StyleBox) -> Vector4:
	if sb == null: return Vector4.ZERO
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		var o := Vector4(f.expand_margin_left, f.expand_margin_top, f.expand_margin_right, f.expand_margin_bottom)
		if f.shadow_size > 0 and f.shadow_color.a > 0.0:
			var s := float(f.shadow_size)
			o = _vmax(o, Vector4(s - f.shadow_offset.x, s - f.shadow_offset.y, s + f.shadow_offset.x, s + f.shadow_offset.y))
		return o
	if sb is StyleBoxTexture:
		var t := sb as StyleBoxTexture
		return Vector4(t.expand_margin_left, t.expand_margin_top, t.expand_margin_right, t.expand_margin_bottom)
	if "outset_left" in sb:
		return Vector4(float(sb.get("outset_left")), float(sb.get("outset_top")), float(sb.get("outset_right")), float(sb.get("outset_bottom")))
	return Vector4.ZERO

static func _vmax(a: Vector4, b: Vector4) -> Vector4:
	return Vector4(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z), maxf(a.w, b.w))

## The node's path under `top` (auto names "@…" become the class name).
static func path_of(n: Node, top: Node) -> String:
	var parts := PackedStringArray()
	var x := n
	while x != null and x != top:
		parts.append(_seg(x))
		x = x.get_parent()
	parts.append(_seg(top) if top != null else "")
	parts.reverse()
	return "/".join(parts)

static func _seg(n: Node) -> String:
	var nm := String(n.name)
	if not nm.begins_with("@"): return nm
	var sc: Script = n.get_script()
	var cls: String = sc.get_global_name() if sc != null and sc.get_global_name() != "" else n.get_class()
	return "%s%d" % [cls, n.get_index()]
