extends TestCase
## The board plates' pure rules against Unity's (PlateLayer.cs, EntityStatusBinder.cs, EntityView.PlateScreenPosition):
## when the HP bar shows, the plate's form at a zoom, its layout round the anchor (the bar's centre), a hover not
## moving the bar, only HP changes reaching the bar (its ease plays out), and the anchor over the unit's head.

func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root

# ------------------------------------------------------------------ the HP bar rule

func test_plate_bar_rule_matches_unity() -> void:
	var after := 1.5
	assert_false(PlateLayer.bar_rule(true, false, false, false, -1.0, after), "an untouched unit: no bar")
	assert_true(PlateLayer.bar_rule(true, true, false, false, -1.0, after), "Always Show Health")
	assert_true(PlateLayer.bar_rule(true, false, true, false, -1.0, after), "hovered or selected")
	assert_true(PlateLayer.bar_rule(true, false, false, true, -1.0, after), "a previewed hit or heal")
	assert_true(PlateLayer.bar_rule(true, false, false, false, 0.0, after), "just hit")
	assert_true(PlateLayer.bar_rule(true, false, false, false, 1.5, after), "still at health_bar_after_hit")
	assert_false(PlateLayer.bar_rule(true, false, false, false, 1.51, after), "gone after health_bar_after_hit")
	assert_true(PlateLayer.bar_rule(false, false, false, false, -1.0, after), "dying: the bar drains")

# ------------------------------------------------------------------ form and layout

func test_plate_form_scales_with_the_zoom_like_unity() -> void:
	var m: Array = PlateLayer.form_metrics(104.0, 104.0, false)
	assert_num(m[0], 1.0, "compact at the default framing: designed size")
	assert_num(m[1], 96.0, "compact: the tile − 8")
	m = PlateLayer.form_metrics(52.0, 104.0, false)
	assert_num(m[0], 0.5, "compact zoomed out: shrinks with the board")
	assert_num(m[1] * m[0], 44.0, "compact zoomed out: still the tile − 8 on screen")
	m = PlateLayer.form_metrics(52.0, 104.0, true)
	assert_num(m[0], 1.0, "full zoomed out: never below its designed size")
	assert_num(m[1], 164.0)
	m = PlateLayer.form_metrics(400.0, 104.0, true)
	assert_num(m[0], WorldUi.MAX_SCALE, "zoomed in: up to MAX_SCALE")
	m = PlateLayer.form_metrics(400.0, 104.0, false)
	assert_num(snappedf(m[1] * m[0], 0.001), 392.0, "compact zoomed in: the tile − 8 on screen")

func test_plate_layout_round_the_bar_centre() -> void:
	var r: Dictionary = KitPlate.plate_rects(false, 96.0, 1.0, true)
	var bar: Rect2 = r.bar
	assert_eq(bar.get_center(), Vector2.ZERO, "the bar's centre is the anchor (Unity's centre pivot)")
	assert_eq(bar.size, Vector2(96, 10), "compact: the tile − 8 wide, 10 thick")
	assert_num(r.row_bottom, -10.0, "compact chips 5 over the bar (11 − 6)")
	assert_eq(r.backing, Rect2(), "no backing when compact")
	r = KitPlate.plate_rects(true, 50.0, 2.0, true)
	bar = r.bar
	assert_eq(bar.size, Vector2(328, 20), "full: 164 × 10, × the scale (the width given is ignored)")
	assert_num(r.row_bottom, -32.0, "full chips 11 over the bar, × the scale")
	var b: Rect2 = r.backing
	assert_eq(b.size, Vector2((164 + 16) * 2, 78 * 2), "backing: 8 / 6 padding round the bar, chips and pills")
	assert_num(b.end.y, bar.end.y + 12.0, "the backing 6 under the bar")
	assert_num(b.get_center().x, 0.0)
	r = KitPlate.plate_rects(true, 0.0, 1.0, false)
	assert_eq((r.backing as Rect2).size, Vector2(180, 22), "no statuses: the backing only rounds the bar")

func _frame(hp: int, statuses: Array = []) -> EntityFrame:
	var f := EntityFrame.new()
	f.has_hp = true
	f.hp = hp
	f.max_hp = 20
	f.life = LifeState.Alive
	for n in statuses:
		var sv := StatusView.new()
		sv.name = n
		sv.stacks = 1
		sv.turns_left = 2
		f.statuses.append(sv)
	return f

func test_plate_hover_does_not_move_the_bar() -> void:
	var p := KitPlate.new()
	_root().add_child(p)
	p.place_at(Vector2(500, 400))
	var f := _frame(12, ["A", "B"])
	p.set_form(false, 90.0, 1.0, false)
	p.show_frame(f)
	var before := p.status.health_bar.get_global_rect()
	var chips_before := p.status.status_bar.get_global_rect()
	assert_num(before.get_center().x, 500.0, "compact bar centred on the unit")
	assert_num(before.get_center().y, 400.0, "the bar's centre on the anchor")
	assert_num(chips_before.get_center().x, 500.0, "chips centred over the bar")
	p.set_form(true, 164.0, 1.3, false)
	p.show_frame(f)
	var full := p.status.health_bar.get_global_rect()
	assert_num(full.get_center().x, 500.0, "full bar centred too (an even width: no half pixel)")
	assert_num(full.size.y, 14.0, "full bar 10 thick × the scale (13, made even)")
	p.set_form(false, 90.0, 1.0, false)
	p.show_frame(f)
	assert_eq(p.status.health_bar.get_global_rect(), before, "after a hover the bar is where it was")
	assert_eq(p.status.status_bar.get_global_rect(), chips_before, "after a hover the chips are where they were")
	# zoomed out with a row wider than the bar: the chips stay centred over it
	p.set_form(false, 70.0, 0.8, false)
	p.show_frame(_frame(12, ["A", "B", "C"]))
	assert_num(p.status.health_bar.get_global_rect().get_center().x, 500.0)
	assert_num(p.status.status_bar.get_global_rect().get_center().x, 500.0, "a wide chip row centred, not pushed right")
	p.free()

## (The bar's ease, ghost and the camera's projection need a live scene tree: tools/plate_check.gd checks them.)

# ------------------------------------------------------------------ the anchor over the head

func test_plate_anchor_maths() -> void:
	var a := EntityView.plate_anchor(Vector2(400, 300), [250.0, 240.0, 262.0], 1.0)
	assert_eq(a, Vector2(400, 240 - EntityView.PLATE_GAP_PIXELS), "x on the centre, 12 px over the highest outline point")
	a = EntityView.plate_anchor(Vector2(400, 300), [240.0], 0.5)
	assert_eq(a.y, 240.0 - EntityView.PLATE_GAP_PIXELS, "zoomed out: the gap never below its designed size")
	a = EntityView.plate_anchor(Vector2(400, 300), [240.0], 2.0)
	assert_eq(a.y, 240.0 - EntityView.PLATE_GAP_PIXELS * 2.0, "zoomed in: the gap grows with the zoom")
	a = EntityView.plate_anchor(Vector2(400, 300), [], 1.0)
	assert_eq(a, Vector2(400, 300 - EntityView.PLATE_GAP_PIXELS), "no outline: over the centre")
	# following: the same body moved on screen moves its anchor by the same amount (no jump)
	var b := EntityView.plate_anchor(Vector2(437, 281), [221.0, 231.0], 1.0)
	assert_eq(b - EntityView.plate_anchor(Vector2(400, 300), [240.0, 250.0], 1.0), Vector2(37, -19))
