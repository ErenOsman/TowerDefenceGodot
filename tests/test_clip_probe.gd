extends TestCase
## The edge-clip probe's rect math (tools/qa/clip_math.gd, used by tools/qa/probe_clipping.gd; UI Design Rules —
## Design § Edge clip) on synthetic trees: clip ancestors, cards, scroll axes, overhang drawers, the parent dedupe.

const ClipMath := preload("res://tools/qa/clip_math.gd")

func _rec(path: String, rect: Rect2, parent := -1, extra := {}) -> Dictionary:
	var r := {"path": path, "rect": rect, "over": Vector4.ZERO, "parent": parent, "clip": false, "card": false, "known": ""}
	r.merge(extra, true)
	return r

func _one(finds: Array, path: String) -> Dictionary:
	for f in finds: if f.path == path: return f
	return {}

func test_overflow_and_edges() -> void:
	var ov := ClipMath.overflow(Rect2(-5, 10, 50, 50), Rect2(0, 0, 100, 100))
	assert_eq(ov, Vector4(5, -10, -55, -40))
	assert_eq(ClipMath.edges_of(ov), PackedStringArray(["left"]))
	assert_eq(ClipMath.edges_of(Vector4(0.8, 0, 0, 0)), PackedStringArray(), "under the 1 px tolerance")
	assert_eq(ClipMath.edges_of(Vector4(3, 3, 3, 3), Vector2(1, 0)), PackedStringArray(["top", "bottom"]), "x axis skipped")
	assert_eq(ClipMath.grown(Rect2(10, 10, 10, 10), Vector4(1, 2, 3, 4)), Rect2(9, 8, 14, 16))

func test_clip_ancestor_cuts_ring() -> void:
	# the Upgrade card before the fix: a scroll (clip) whose content starts 2 px in; a medallion ring 5 px out
	var recs := [
		_rec("Card", Rect2(0, 0, 380, 600), -1, {"card": true}),
		_rec("Card/Scroll", Rect2(14, 14, 352, 572), 0, {"clip": true, "scroll_v": true, "content": Rect2(14, 14, 352, 904)}),
		_rec("Card/Scroll/Body", Rect2(16, 16, 346, 900), 1),
		_rec("Card/Scroll/Body/Medal", Rect2(16, 60, 84, 84), 2),
		_rec("Card/Scroll/Body/Medal/Ring", Rect2(11, 55, 94, 94), 3, {"known": "Ring"}),
	]
	var finds := ClipMath.findings(recs)
	assert_eq(finds.size(), 1, str(finds))
	var f := _one(finds, "Card/Scroll/Body/Medal/Ring")
	assert_eq(f.edges, PackedStringArray(["left"]))
	assert_num(f.px, 3.0)
	assert_eq(f.check, "c", "a portrait ring is a known overhang drawer")
	assert_eq(f.against, "Card/Scroll")
	assert_true(ClipMath.line("upgrade_view", f).begins_with("upgrade_view Card/Scroll/Body/Medal/Ring left 3"))
	# with 6 px of room the ring is inside
	recs[1].content = Rect2(14, 14, 352, 912)
	recs[2].rect = Rect2(20, 20, 340, 900)
	recs[3].rect = Rect2(20, 64, 84, 84)
	recs[4].rect = Rect2(15, 59, 94, 94)
	assert_eq(ClipMath.findings(recs), [])

func test_overhang_only_is_c() -> void:
	# a tile whose rect fits but whose sprite outset (2 px) is cut by the clip it touches
	var recs := [
		_rec("Clip", Rect2(0, 0, 200, 100), -1, {"clip": true}),
		_rec("Clip/Tile", Rect2(0, 10, 150, 44), 0, {"over": Vector4(2, 2, 2, 2), "card": true}),
	]
	var finds := ClipMath.findings(recs)
	assert_eq(finds.size(), 1)
	assert_eq(finds[0].check, "c")
	assert_eq(finds[0].rule, "a")
	assert_eq(finds[0].edges, PackedStringArray(["left"]))
	assert_num(finds[0].px, 2.0, "the 2 px outset, no room")

func test_card_ancestor() -> void:
	var recs := [
		_rec("Card", Rect2(100, 100, 300, 200), -1, {"card": true}),
		_rec("Card/Box", Rect2(110, 110, 280, 180), 0),
		_rec("Card/Box/Badge", Rect2(380, 95, 30, 30), 1),
	]
	var finds := ClipMath.findings(recs)
	assert_eq(finds.size(), 1)
	assert_eq(finds[0].check, "b")
	assert_eq(finds[0].edges, PackedStringArray(["top", "right"]))
	assert_num(finds[0].px, 10.0)

func test_scroll_axis_rows_and_slid_away() -> void:
	var recs := [
		_rec("Card", Rect2(0, 0, 400, 300), -1, {"card": true}),
		_rec("Card/Scroll", Rect2(10, 10, 380, 280), 0, {"clip": true, "scroll_v": true, "content": Rect2(10, -90, 380, 600)}),
		_rec("Card/Scroll/List", Rect2(10, -90, 380, 600), 1),
		# a row half scrolled out at the top: fine (inside the content, the card check skips the scrolled axis)
		_rec("Card/Scroll/List/Row1", Rect2(14, -10, 370, 60), 2),
		# a row scrolled wholly out of sight: skipped even though it pokes out sideways
		_rec("Card/Scroll/List/Row9", Rect2(0, 420, 400, 60), 2),
		# a row too wide for the scroll (horizontal axis does not scroll): cut
		_rec("Card/Scroll/List/Wide", Rect2(14, 100, 380, 40), 2),
	]
	var finds := ClipMath.findings(recs)
	assert_eq(finds.size(), 1, str(finds))
	assert_eq(finds[0].path, "Card/Scroll/List/Wide")
	assert_eq(finds[0].edges, PackedStringArray(["right"]))
	assert_num(finds[0].px, 4.0)
	# a content shorter than the scroll: its rect, not the content's, is the limit at the bottom
	var short := [
		_rec("Scroll", Rect2(0, 0, 300, 300), -1, {"clip": true, "scroll_v": true, "content": Rect2(0, 0, 300, 100)}),
		_rec("Scroll/Body", Rect2(0, 0, 300, 100), 0),
		_rec("Scroll/Body/Medal/Ring", Rect2(10, 60, 50, 50), 1, {"known": "Ring"}),
	]
	assert_eq(ClipMath.findings(short), [], "drawn past the content but inside the scroll: visible")

func test_parent_dedupe() -> void:
	var recs := [
		_rec("Clip", Rect2(0, 0, 100, 100), -1, {"clip": true}),
		_rec("Clip/Box", Rect2(0, 0, 100, 110), 0),
		_rec("Clip/Box/Label", Rect2(0, 80, 100, 30), 1),
		_rec("Clip/Box/Chip", Rect2(0, 90, 100, 25), 1),
	]
	var finds := ClipMath.findings(recs)
	assert_eq(finds.map(func(f): return f.path), ["Clip/Box", "Clip/Box/Chip"], "the label repeats its parent; the chip reaches further")

func test_overhang_sources() -> void:
	var flat := StyleBoxFlat.new()
	flat.expand_margin_left = 4
	flat.expand_margin_bottom = 2
	assert_eq(ClipMath.stylebox_overhang(flat), Vector4(4, 0, 0, 2))
	flat.shadow_size = 6
	flat.shadow_color = Color(0, 0, 0, 0.5)
	flat.shadow_offset = Vector2(0, 3)
	assert_eq(ClipMath.stylebox_overhang(flat), Vector4(6, 3, 6, 9))
	var slice := TdSliceBox.new().set_outset(2, 3, 2, 5)
	assert_eq(ClipMath.stylebox_overhang(slice), Vector4(2, 3, 2, 5))
	assert_eq(ClipMath.stylebox_overhang(StyleBoxEmpty.new()), Vector4.ZERO)
	var ring := ClipMath.ring_line_overhang(84.0)
	assert_true(ring.x > 5.0 and ring.x < 6.0, "an 84 px ring line reaches ~5.6 px out: %s" % ring)
	assert_true(TdTowerCard.medallion_overhang(84.0) + 0.01 >= ring.x, "the card part's room covers the ring line")
	assert_true(TdTowerCard.medallion_overhang(84.0) >= 84.0 * 0.06, "and the portrait_ring sprite / Lv chip")

func test_collect_real_tree() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var top := Control.new()
	top.name = "Top"
	top.size = Vector2(500, 400)
	var clip := Control.new()
	clip.name = "Clip"
	clip.clip_contents = true
	clip.position = Vector2(20, 20)
	clip.size = Vector2(300, 300)
	top.add_child(clip)
	var card := Panel.new()
	card.name = "Card"
	var sb := StyleBoxFlat.new()
	sb.expand_margin_left = 3
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(1, 10)
	card.size = Vector2(200, 200)
	clip.add_child(card)
	var medal := Control.new()
	medal.name = "Medal"
	medal.position = Vector2(4, 4)
	medal.size = Vector2(84, 84)
	card.add_child(medal)
	var ring := TextureRect.new()
	ring.name = "Ring"
	ring.position = Vector2(-8, -8)
	ring.size = Vector2(94, 94)
	medal.add_child(ring)
	var hidden := Control.new()
	hidden.visible = false
	hidden.position = Vector2(-50, 0)
	hidden.size = Vector2(10, 10)
	card.add_child(hidden)
	tree.root.add_child(top)
	var recs := ClipMath.collect(top)
	assert_eq(recs.map(func(r): return r.path), ["Top", "Top/Clip", "Top/Clip/Card", "Top/Clip/Card/Medal", "Top/Clip/Card/Medal/Ring"], "hidden controls left out")
	assert_true(recs[1].clip)
	assert_true(recs[2].card)
	assert_eq(recs[2].over, Vector4(3, 0, 0, 0))
	assert_eq(recs[4].known, "Ring")
	var finds := ClipMath.findings(recs)
	var paths := finds.map(func(f): return "%s %s %s" % [f.path, f.check, ",".join(f.edges)])
	# the card's expand margin is cut by the clip (overhang only); the ring leaves the card and the clip
	assert_eq(paths, ["Top/Clip/Card c left", "Top/Clip/Card/Medal/Ring c left,top", "Top/Clip/Card/Medal/Ring c left"], str(finds))
	top.queue_free()
	tree.root.remove_child(top)
