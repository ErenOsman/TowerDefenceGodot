extends TestCase
## KeyBinds (InputBindings.cs + GameKeys.cs): defaults, binding, conflicts, modifiers, names, {key:Id} text,
## and reading pressed/held/released from fed key events.

var kb: Node

func setup() -> void:
	kb = load("res://game/app/key_binds.gd").new()
	kb.settings_override = SettingsData.new()

func teardown() -> void:
	kb.free()

func _key(code: int, down: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = down
	return e

func test_defaults_follow_game_keys() -> void:
	assert_eq(kb.describe("EndRound"), "Enter · Shift+Space")
	assert_eq(kb.describe("Skip"), "Space")
	assert_eq(kb.describe("Pause"), "P")
	assert_eq(kb.describe("Ability1"), "1")
	assert_eq(kb.describe("Ability9"), "9")
	assert_eq(kb.describe("CameraUp"), "W · Up")
	assert_eq(kb.describe("CameraLeft"), "A · Left")
	assert_eq(kb.describe("RotateLeft"), "Q")
	assert_eq(kb.describe("RotateRight"), "E")
	assert_eq(kb.get_modifier("Aim"), Modifiers.None)
	assert_eq(kb.get_modifier("QuickCast"), Modifiers.Shift)
	assert_eq(kb.get_modifier("Hand"), Modifiers.Ctrl)
	assert_eq(kb.actions.size(), 3 + 9 + 6)
	assert_eq(kb.modifier_actions.size(), 3)
	assert_eq(kb.describe("Nope"), "")
	assert_eq(kb.first("Nope"), "unbound")

func test_no_conflicts_by_default() -> void:
	assert_eq(kb.all_conflicts(), [])

func test_set_bind_and_conflicts() -> void:
	kb.set_bind("Pause", 0, KeyCombo.new(KEY_SPACE))
	assert_eq(kb.describe("Pause"), "Space")
	assert_true(kb.conflicts("Pause", 0))
	assert_true(kb.conflicts("Skip", 0))
	assert_false(kb.conflicts("EndRound", 1), "Shift+Space is not Space")
	kb.set_bind("Pause", 0, KeyCombo.new(KEY_SPACE, Modifiers.Shift))
	assert_true(kb.conflicts("EndRound", 1))
	assert_false(kb.conflicts("Skip", 0))
	kb.set_bind("Pause", 0, KeyCombo.new(KEY_W, Modifiers.Ctrl))
	assert_true(kb.conflicts("Pause", 0), "a bare key clashes under any combination")
	assert_true(kb.conflicts("CameraUp", 0))
	assert_eq(kb.settings_override.key_binds.size(), 1, "one saved entry per changed action")
	assert_eq(kb.get_bind("Pause", 1).key, KEY_NONE, "the other slot kept as it was")

func test_bare_actions_drop_the_combination() -> void:
	kb.set_bind("Ability1", 0, KeyCombo.new(KEY_F, Modifiers.Ctrl))
	assert_eq(kb.get_bind("Ability1", 0).modifiers, Modifiers.None)
	assert_eq(kb.describe("Ability1"), "F")

func test_set_modifier_swaps() -> void:
	kb.set_modifier("Aim", Modifiers.Shift)
	assert_eq(kb.get_modifier("Aim"), Modifiers.Shift)
	assert_eq(kb.get_modifier("QuickCast"), Modifiers.None, "took Aim's old one")
	assert_eq(kb.get_modifier("Hand"), Modifiers.Ctrl)
	kb.reset_all()
	assert_eq(kb.get_modifier("Aim"), Modifiers.None)
	assert_eq(kb.get_modifier("QuickCast"), Modifiers.Shift)
	assert_eq(kb.settings_override.modifier_binds.size(), 0)

func test_names_and_texts() -> void:
	assert_eq(kb.combo_text(KeyCombo.new(KEY_SPACE, Modifiers.CtrlShift)), "Ctrl+Shift+Space")
	assert_eq(kb.combo_text(KeyCombo.none()), "-")
	assert_eq(kb.key_name(KEY_KP_3), "Num 3")
	assert_eq(kb.key_name(KEY_ESCAPE), "Esc")
	assert_eq(kb.key_name(KEY_PAGEUP), "Page Up")
	assert_eq(kb.key_name(KEY_F5), "F5")
	assert_eq(kb.combo("QuickCast", "Ability2"), "Shift+2")
	assert_eq(kb.combo("Aim", "Ability2"), "2")
	assert_eq(kb.click_text("QuickCast"), "Shift-click")
	assert_eq(kb.click_text("Aim"), "Click")
	assert_eq(kb.fill_keys("Press {key:EndRound} to end, {key:Skip} to skip; {click:QuickCast} to cast, {click:Aim} to aim."),
		"Press Enter to end, Space to skip; Shift-click to cast, click to aim.")
	assert_eq(kb.fill_keys("no keys"), "no keys")
	assert_eq(kb.fill_keys(""), "")

func test_saved_binds_survive_json() -> void:
	kb.set_bind("Skip", 1, KeyCombo.new(KEY_BACKSPACE, Modifiers.Alt))
	kb.set_modifier("Hand", Modifiers.Alt)
	var g := GameData.new()
	g.settings = kb.settings_override
	var back := GameData.from_json(g.to_json())
	kb.settings_override = back.settings
	assert_eq(kb.describe("Skip"), "Space · Alt+Backspace")
	assert_eq(kb.get_modifier("Hand"), Modifiers.Alt)

func test_pressed_held_released_with_exact_modifiers() -> void:
	kb.feed(_key(KEY_ENTER, true))
	assert_false(kb.pressed("EndRound"), "not before the frame starts")
	kb.next_frame()
	assert_true(kb.pressed("EndRound"))
	assert_true(kb.held("EndRound"))
	kb.next_frame()
	assert_false(kb.pressed("EndRound"), "pressed lasts one frame")
	assert_true(kb.held("EndRound"))
	kb.feed(_key(KEY_ENTER, false))
	kb.next_frame()
	assert_true(kb.released("EndRound"))
	assert_false(kb.held("EndRound"))
	# Shift+Space ends the round; Space alone skips
	kb.feed(_key(KEY_SHIFT, true))
	kb.feed(_key(KEY_SPACE, true))
	kb.next_frame()
	assert_true(kb.pressed("EndRound"))
	assert_false(kb.pressed("Skip"))
	assert_true(kb.modifier_held("QuickCast"))
	assert_false(kb.modifier_held("Aim"))
	kb.feed(_key(KEY_SPACE, false))
	kb.feed(_key(KEY_SHIFT, false))
	kb.next_frame()
	kb.feed(_key(KEY_SPACE, true))
	kb.next_frame()
	assert_true(kb.pressed("Skip"))
	assert_false(kb.pressed("EndRound"))
	assert_true(kb.modifier_held("Aim"))

func test_bare_keys_match_with_any_modifier_and_block_keys() -> void:
	kb.feed(_key(KEY_CTRL, true))
	kb.feed(_key(KEY_3, true))
	kb.next_frame()
	assert_true(kb.pressed("Ability3"))
	assert_true(kb.modifier_held("Hand"))
	kb.block_keys = true
	assert_false(kb.pressed("Ability3"))
	assert_false(kb.held("Ability3"))
	kb.block_keys = false
	kb.feed(_key(KEY_ALT, true))
	assert_eq(kb.held_modifiers(), -1, "Ctrl+Alt is not offered")

func test_combo_from_event() -> void:
	var e := _key(KEY_SPACE, true)
	e.shift_pressed = true
	var c: KeyCombo = kb.combo_from_event(e)
	assert_true(c.equals(KeyCombo.new(KEY_SPACE, Modifiers.Shift)))
	assert_null(kb.combo_from_event(_key(KEY_SHIFT, true)), "a modifier alone is no key")
	assert_null(kb.combo_from_event(_key(KEY_A, false)))
