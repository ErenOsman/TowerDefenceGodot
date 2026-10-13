extends TestCase
## Battle HUD bottom row (UI Design Rules, Bottom row layout): tray width, the 130 × pieces + 110 × abilities > 1372
## rule, the bar centred on the free area / slid right of the tray / raised a row, the hint under the bar.

const SCREEN := Vector2(1920, 1080)

func test_tray_width_grows_with_pieces() -> void:
	assert_num(HudLayout.tray_width(4), 4 * 124 + 3 * 6 + 44)
	assert_num(HudLayout.tray_width(5), 688.0)
	assert_num(HudLayout.tray_width(0), HudLayout.tray_width(1))
	var r := HudLayout.tray_rect(SCREEN, 4)
	assert_num(r.position.x, 32.0)
	assert_num(r.end.y, 1080.0)

func test_raise_rule_at_1920() -> void:
	# the doc's count rule with the bled ability width (147 per ability)
	assert_num(HudLayout.ABILITY_COST, 147.0)
	assert_false(HudLayout.bar_raised(4, 2))   # 520 + 294
	assert_false(HudLayout.bar_raised(6, 3))   # 780 + 441 = 1221
	assert_true(HudLayout.bar_raised(8, 3))    # 1040 + 441 = 1481
	assert_true(HudLayout.bar_raised(6, 5))
	assert_false(HudLayout.bar_raised(8, 3, 2560.0))

func test_bar_width() -> void:
	assert_num(HudLayout.bar_width(0), 32.0 + 110.0)
	assert_num(HudLayout.bar_width(2), 32.0 + 110.0 + 54.0 + 2.0 * 143.0 + 4.0)
	assert_num(HudLayout.bar_width(1, 150.0), 32.0 + 150.0 + 54.0 + 143.0)

func test_bar_centred_on_the_screen() -> void:
	var w := HudLayout.bar_width(2)
	var row := HudLayout.bottom_row(SCREEN, 2, 2, w)
	var bar: Rect2 = row["bar"]
	assert_false(row["raised"])
	assert_false(row["slid"])
	assert_num(bar.get_center().x, 960.0)
	assert_num(bar.end.y, 1080.0 - 62.0)
	assert_true(row["hint_centred"])
	assert_num(row["hint_x"], bar.get_center().x)
	assert_true(row["hint_y"] >= bar.end.y)
	assert_num(row["bottom_inset"], 168.0)

func test_bar_pushed_right_of_a_wide_tray() -> void:
	var w := HudLayout.bar_width(2)
	var row := HudLayout.bottom_row(SCREEN, 5, 2, w)
	var bar: Rect2 = row["bar"]
	assert_true(row["slid"])
	assert_num(bar.position.x, HudLayout.tray_rect(SCREEN, 5).end.x + 24.0)
	assert_true(bar.get_center().x > 960.0) # never left of centre
	assert_false(row["hint_centred"])
	assert_num(row["hint_x"], bar.position.x)
	assert_true(bar.end.x <= HudLayout.end_turn_rect(SCREEN).position.x)

func test_bar_raises_above_the_tray() -> void:
	var w := HudLayout.bar_width(6)
	var row := HudLayout.bottom_row(SCREEN, 6, 6, w)
	var bar: Rect2 = row["bar"]
	assert_true(row["raised"])
	assert_true(bar.end.y + HudLayout.HINT_H <= HudLayout.tray_rect(SCREEN, 6).position.y)
	assert_num(bar.get_center().x, 960.0)
	assert_true(row["bottom_inset"] > 168.0)

func test_hint_without_bar() -> void:
	var h := HudLayout.hint_without_bar(SCREEN, 2, 300.0)
	assert_true(h["centred"])
	assert_num(h["x"], 960.0)
	var long := HudLayout.hint_without_bar(SCREEN, 6, 600.0)
	assert_false(long["centred"])
	assert_num(long["x"], HudLayout.tray_rect(SCREEN, 6).end.x + 24.0)

func test_screen_zones() -> void:
	var e := HudLayout.end_turn_rect(SCREEN)
	assert_eq(e, Rect2(1920 - 32 - 168, 1080 - 20 - 168, 168, 168))
	var i := HudLayout.inspector_rect(SCREEN, 500)
	assert_num(i.end.x, 1920.0 - 32.0)
	assert_num(i.position.y, 96.0)

func test_portrait_cover_uv() -> void:
	assert_eq(HudPortrait.cover_uv(Vector2(100, 100)), Rect2(0, 0, 1, 1))
	assert_eq(HudPortrait.cover_uv(Vector2(200, 100)), Rect2(0.25, 0, 0.5, 1))
	var tall := HudPortrait.cover_uv(Vector2(100, 200), -1.0)
	assert_num(tall.position.y, 0.0)
	assert_num(tall.size.y, 0.5)

func test_hint_never_crosses_the_tray() -> void:
	var tray_end := HudLayout.tray_rect(SCREEN, 4).end.x
	# a centred hint that would reach over the tray moves right of it, left-aligned with a bar in the row
	assert_num(HudLayout.hint_left(560.0, 500.0, SCREEN, 4, true, 640.0), 640.0)
	assert_num(HudLayout.hint_left(560.0, 500.0, SCREEN, 4, false, 0.0), tray_end + 24.0)
	assert_num(HudLayout.hint_left(700.0, 300.0, SCREEN, 4, true, 650.0), 700.0)

func test_ring_rect_stays_on_screen() -> void:
	var r := HudSequence.ring_rect(Rect2(1720, 892, 168, 168), SCREEN)
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(r))
	assert_eq(HudSequence.ring_rect(Rect2(500, 500, 100, 50), SCREEN), Rect2(490, 490, 120, 70))
