extends TestCase
## TdConfirm, the one yes/no popup (UI Design Rules, Confirmations; Eren 2026-10-15): title + one line, Cancel on the
## left and the confirm on the right (Danger for destructive questions), Enter confirms, Esc / Cancel cancel, the
## answer comes once; and the questions the screens ask through it (the tutorial's Skip, the pause menu's Quit).

var _host: Control

func setup() -> void:
	_host = Control.new()
	_host.size = Vector2(1920, 1080)
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)

func teardown() -> void:
	for p in TdPopup.open_popups.duplicate():
		if is_instance_valid(p) and _host.is_ancestor_of(p): TdPopup.open_popups.erase(p)
	_host.free()

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

func test_confirm_layout_and_answer() -> void:
	var got := []
	var c := TdConfirm.ask(_host, "Quit the game?", "This level's progress is lost.", "Quit game",
		func(yes: bool): got.append(yes), {"danger": true, "cancel_text": "Keep playing"})
	assert_true(c.is_open and c.is_top(), "opens on top")
	assert_eq(c.title_label.text, "Quit the game?")
	assert_eq(c.message_label.text, "This level's progress is lost.")
	assert_eq(c.cancel_button.text, "Keep playing")
	assert_eq(c.confirm_button.text, "Quit game")
	assert_eq(c.confirm_button.style, TdButton.Style.DANGER, "destructive: danger")
	assert_true(c.cancel_button.get_index() < c.confirm_button.get_index(), "Cancel on the left, the confirm on the right")
	c._unhandled_input(_key(KEY_ENTER))
	assert_seq(got, [true], "Enter confirms")
	c.cancel()
	assert_seq(got, [true], "the answer comes once")
	assert_false(c.is_open)

func test_confirm_esc_cancels_and_default_style() -> void:
	var got := []
	var c := TdConfirm.ask(_host, "Unlock?", "", "Unlock", func(yes: bool): got.append(yes))
	assert_eq(c.confirm_button.style, TdButton.Style.PRIMARY, "not destructive: cobalt primary")
	assert_eq(c.cancel_button.text, "Cancel")
	assert_false(c.message_label.visible, "no line: hidden")
	c._unhandled_input(_key(KEY_ESCAPE))
	assert_seq(got, [false], "Esc cancels")

func test_confirm_texts_of_the_tutorial_skip() -> void:
	assert_eq(HudSequence.SKIP_TITLE, "Skip the tutorial?")
	assert_eq(HudSequence.SKIP_TEXT, "You'll play the level without guidance.")
