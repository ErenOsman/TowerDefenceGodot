extends TestCase
## UI kit: the tooltip placement solver (port of TooltipPlacement): asked side, opposite, rest; slide inside; avoid rects.

const S = TdTooltipPlacement.Side
const SCREEN := Rect2(0, 0, 1920, 1080)

func teardown() -> void:
	TdTooltipPlacement.clear_avoid()

func test_opens_on_the_asked_side_top_level_with_the_anchor() -> void:
	var a := Rect2(400, 300, 100, 40)
	var r := TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), a, a, S.RIGHT, [])
	assert_eq(r["side"], S.RIGHT)
	assert_eq(r["position"], Vector2(508, 300))
	r = TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), a, a, S.LEFT, [])
	assert_eq(r["position"], Vector2(400 - 8 - 380, 300))

func test_auto_opens_away_from_the_screen_side() -> void:
	var right := Rect2(1500, 300, 100, 40)
	assert_eq(TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), right, right, S.AUTO, [])["side"], S.LEFT)
	var left := Rect2(200, 300, 100, 40)
	assert_eq(TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), left, left, S.AUTO, [])["side"], S.RIGHT)

func test_no_room_flips_to_the_opposite_side() -> void:
	var a := Rect2(1700, 300, 100, 40)
	var r := TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), a, a, S.RIGHT, [])
	assert_eq(r["side"], S.LEFT)
	assert_eq(r["position"], Vector2(1700 - 8 - 380, 300))

func test_above_centred_slides_inside_and_never_changes_side() -> void:
	var a := Rect2(20, 900, 84, 84)
	var r := TdTooltipPlacement.solve(SCREEN, Vector2(380, 300), a, a, S.ABOVE_CENTRED, [])
	assert_eq(r["side"], S.ABOVE_CENTRED)
	assert_eq(r["position"], Vector2(8, 900 - 8 - 300)) # slid right to the padding
	# even when it would cover the anchor (no room above), it stays above, slid down inside the screen
	var top := Rect2(900, 20, 84, 84)
	var r2 := TdTooltipPlacement.solve(SCREEN, Vector2(380, 300), top, top, S.ABOVE_CENTRED, [])
	assert_eq(r2["side"], S.ABOVE_CENTRED)
	assert_eq(r2["position"].y, 8.0)

func test_above_starts_at_the_anchor_left_and_below_lines_up_right_sides() -> void:
	var a := Rect2(600, 600, 100, 40)
	var edge := Rect2(500, 560, 600, 120) # e.g. the bar the anchor sits in
	assert_eq(TdTooltipPlacement.beside(Vector2(380, 200), a, edge, S.ABOVE).position, Vector2(600, 560 - 8 - 200))
	assert_eq(TdTooltipPlacement.beside(Vector2(380, 200), a, edge, S.BELOW).position, Vector2(1100 - 380, 680 + 8))

func test_slides_a_tall_box_keeping_its_top_on_screen() -> void:
	# right of an anchor near the bottom would spill (slid up): a side where it fits whole wins (above)
	var a := Rect2(400, 900, 100, 40)
	var r := TdTooltipPlacement.solve(SCREEN, Vector2(380, 400), a, a, S.RIGHT, [])
	assert_eq(r["side"], S.ABOVE)
	assert_eq(r["position"], Vector2(400, 900 - 8 - 400))
	# nowhere fits whole: the least covering try, slid inside with its top on screen
	var b := Rect2(400, 300, 100, 40)
	var r2 := TdTooltipPlacement.solve(Rect2(0, 0, 1920, 500), Vector2(380, 700), b, b, S.RIGHT, [])
	assert_eq(r2["position"].y, 8.0)
	var huge := TdTooltipPlacement.slide(Rect2(0, 500, 380, 2000), SCREEN)
	assert_eq(huge.position.y, 8.0)

func test_avoid_rects_push_it_to_another_side() -> void:
	var a := Rect2(800, 400, 100, 40)
	var blocked := Rect2(908, 380, 400, 300) # the board tiles a preview shows, right of the anchor
	var r := TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), a, a, S.RIGHT, [blocked])
	assert_eq(r["side"], S.LEFT)
	# registered avoid rects are used when none are passed
	TdTooltipPlacement.set_avoid(self, [blocked])
	assert_eq(TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), a, a, S.RIGHT)["side"], S.LEFT)
	TdTooltipPlacement.set_avoid(self, [])
	assert_eq(TdTooltipPlacement.solve(SCREEN, Vector2(380, 200), a, a, S.RIGHT)["side"], S.RIGHT)

func test_side_order() -> void:
	var e := Rect2(100, 100, 10, 10)
	assert_seq(TdTooltipPlacement.order_for(S.ABOVE, e, SCREEN), [S.ABOVE, S.BELOW, S.LEFT, S.RIGHT])
	assert_seq(TdTooltipPlacement.order_for(S.AUTO, e, SCREEN), [S.RIGHT, S.LEFT, S.ABOVE, S.BELOW])

func test_follow_mouse_is_clamped() -> void:
	assert_eq(TdTooltipPlacement.at_point(SCREEN, Vector2(380, 200), Vector2(100, 100)), Vector2(116, 116))
	assert_eq(TdTooltipPlacement.at_point(SCREEN, Vector2(380, 200), Vector2(1900, 1070)), Vector2(1920 - 8 - 380, 1080 - 8 - 200))
