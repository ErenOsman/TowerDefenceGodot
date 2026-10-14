extends TestCase
## Where the dialogue box goes (HudSequence.dialogue_rect, the guided tutorial's placement rule): bottom by default,
## docked at the top when the ringed target would lie under the box, its name plate / Skip or the margin round them;
## sticky at the top until the target clears the bottom area by the hysteresis; the lesser cover when both cover it.

const SCREEN := Vector2(1920, 1080)
const BOX := Vector2(1100, 220)

func _bottom() -> Rect2:
	return Rect2((SCREEN.x - BOX.x) / 2.0, SCREEN.y - HudSequence.BOX_BOTTOM - BOX.y, BOX.x, BOX.y)

func _top() -> Rect2:
	return Rect2((SCREEN.x - BOX.x) / 2.0, HudSequence.BOX_TOP, BOX.x, BOX.y)

func test_bottom_by_default_like_the_unity_box() -> void:
	var r := HudSequence.dialogue_rect(SCREEN, BOX, null)
	assert_eq(r, _bottom())
	assert_num(r.position.x, 410.0)
	assert_num(r.end.y, 868.0) # the Unity build's box ends at ~865 over the tray
	assert_true(r.end.y <= SCREEN.y - HudLayout.TRAY_H, "the hand tray stays clear under the box")

func test_a_target_clear_of_the_box_keeps_it_at_the_bottom() -> void:
	# the tray piece (bottom-left), End turn (bottom-right), a tile high on the board
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(32, 912, 124, 168)), _bottom())
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, HudLayout.end_turn_rect(SCREEN)), _bottom())
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(900, 300, 120, 64)), _bottom())
	# the action bar in the bottom row (under the box)
	var bar := HudLayout.bottom_row(SCREEN, 1, 2, 400.0).bar as Rect2
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, bar), _bottom())

func test_a_target_under_the_box_docks_it_at_the_top() -> void:
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(900, 700, 120, 64)), _top())
	# under the name plate / Skip over the top edge only
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(1300, _bottom().position.y - 40.0, 100, 30)), _top())
	# within the margin beside the box
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(_bottom().end.x + 4.0, 700, 60, 40)), _top())
	# a raised action bar
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(700, 744, 500, 112)), _top())

func test_the_top_dock_is_sticky_until_the_target_clears_by_the_hysteresis() -> void:
	var area_top := _bottom().position.y - TdDialogueBox.OVERHANG - HudSequence.DOCK_MARGIN
	# just clear of the bottom area: bottom from the bottom, still top when docked at the top
	var near := Rect2(900, area_top - 64.0 - 8.0, 120, 64)
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, near, false), _bottom())
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, near, true), _top())
	var far := Rect2(900, area_top - 64.0 - HudSequence.DOCK_HYSTERESIS - 8.0, 120, 64)
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, far, true), _bottom())

func test_when_both_cover_the_target_the_lesser_cover_wins() -> void:
	# a tall target mostly under the bottom box, a little under the top one
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(900, 300, 100, 600)), _top())
	# mostly under the top box
	assert_eq(HudSequence.dialogue_rect(SCREEN, BOX, Rect2(900, 100, 100, 560)), _bottom())

func test_other_screen_sizes() -> void:
	var small := Vector2(1280, 720)
	var r := HudSequence.dialogue_rect(small, BOX, null)
	assert_num(r.position.x, 90.0)
	assert_num(r.end.y, 720.0 - HudSequence.BOX_BOTTOM)
	assert_num(HudSequence.dialogue_rect(small, BOX, Rect2(600, 400, 80, 40)).position.y, HudSequence.BOX_TOP)
