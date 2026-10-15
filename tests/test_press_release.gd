extends TestCase
## A press whose release went to another window (QA 2026-10-15, Eren: after picking from a dropdown — its PopupMenu is
## a separate Window — the Settings list followed the mouse as if the button were still held). TdDragScroll and
## TdButton drop their press state once the left button is no longer down, and a later motion never drags or clicks.
## Headless: Input.is_mouse_button_pressed(LEFT) is false, as after the popup took the release.

var _host: Control

func setup() -> void:
	_host = Control.new()
	_host.size = Vector2(800, 600)
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)

func teardown() -> void:
	_host.free()

func _press(at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = at
	e.global_position = at
	return e

func _motion(at: Vector2, mask := 0) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = mask
	return e

func test_drag_scroll_forgets_a_press_released_in_a_popup() -> void:
	var s := ScrollContainer.new()
	s.size = Vector2(400, 300)
	_host.add_child(s)
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(380, 2000)
	s.add_child(tall)
	var opt := OptionButton.new() # the Window size dropdown
	opt.add_item("1280 × 720")
	opt.add_item("1920 × 1080")
	tall.add_child(opt)
	var d := TdDragScroll.attach(s)
	d._input(_press(Vector2(50, 20)))
	assert_true(d.is_holding(), "the press on the dropdown is tracked")
	# the PopupMenu took the release; the item is chosen there
	opt.select(1)
	opt.item_selected.emit(1)
	# the mouse moves with no button held: no drag
	d._input(_motion(Vector2(50, 200)))
	assert_false(d.is_holding(), "a motion without the left button ends the press")
	assert_eq(s.scroll_vertical, 0, "the list did not follow the mouse")
	# and the _process guard alone (no motion seen yet)
	d._input(_press(Vector2(50, 20)))
	d._process(0.016)
	assert_false(d.is_holding(), "the left button is up: the press is dropped")

func test_button_unpresses_when_the_release_never_comes() -> void:
	var b := TdButton.new()
	b.text = "Apply"
	_host.add_child(b)
	var clicks := []
	b.clicked.connect(func(): clicks.append(1))
	b._gui_input(_press(Vector2(10, 10)))
	assert_true(b.pressed, "pressed by the mouse")
	b._process(0.016)
	assert_false(b.pressed, "the left button is up: un-pressed")
	assert_eq(clicks.size(), 0, "without a click")
	b.force_state(true, true)
	b._process(0.016)
	assert_true(b.pressed, "a forced press (shots) is left alone")
