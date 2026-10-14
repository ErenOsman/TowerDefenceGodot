extends TestCase
## A HUD window (pause, info) opening over a control with a tooltip: the shown tooltip is hidden at once and a pending
## one (pointer resting on the Pause button, the window opened by key) does not open over it later.

var holder: Control
var button: Button
var trigger: TdTooltipTrigger

func setup() -> void:
	holder = Control.new()
	holder.size = Vector2(1920, 1080)
	(Engine.get_main_loop() as SceneTree).root.add_child(holder)
	button = Button.new()
	button.size = Vector2(80, 80)
	holder.add_child(button)
	trigger = TdTooltipTrigger.attach(button, "Pause", "Opens the pause menu.")
	trigger.position_mode = TdTooltipTrigger.PositionMode.MOUSE_STATIC

func teardown() -> void:
	TdTooltip.hide_immediate()
	holder.free()

## Shown, or waiting for the tooltip layer to enter the tree (it is added deferred on first use).
func _tooltip_up() -> bool:
	var l = TdTooltip._layer
	return TdTooltip.is_visible() or (is_instance_valid(l) and not l.is_inside_tree() and l._pending.is_valid())

func _popup() -> HudPopup:
	var p := HudPopup.new()
	holder.add_child(p)
	p.make("Paused", 480, false, true)
	return p

func test_open_hides_the_shown_tooltip() -> void:
	trigger._on_enter()
	trigger._process(1.0)
	assert_true(trigger.is_showing() and _tooltip_up(), "the Pause tooltip is up")
	_popup().open()
	assert_false(_tooltip_up(), "opening the pause window hides it")
	trigger._process(1.0)
	assert_false(_tooltip_up(), "and it does not come back while the pointer rests")

func test_open_cancels_a_pending_tooltip() -> void:
	trigger._on_enter()
	trigger._process(0.1) # hovering, the delay not over yet
	_popup().open()
	trigger._process(1.0)
	assert_false(trigger.is_showing())
	assert_false(_tooltip_up(), "the delayed tooltip never opens over the window")

func test_hover_again_after_the_window_shows_it() -> void:
	_popup().open()
	trigger._on_enter()
	trigger._process(1.0)
	assert_true(trigger.is_showing(), "a new hover after the window starts the tooltip as usual")
