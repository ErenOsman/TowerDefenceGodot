class_name TdConfirm
extends TdPopup
## The one yes/no question popup (UI Design Rules, Confirmations; Eren 2026-10-15): a small window (760 wide) over a
## scrim with an optional icon or portrait, the title, one line saying what happens (BBCode allowed), Cancel on the
## LEFT and the confirm button on the RIGHT (Danger for destructive actions — Quit, Reset, Kick —, Primary/cobalt
## otherwise). Enter confirms; Esc, a right click or a click on the scrim cancel. The look is the Workshop unlock
## confirm's (the first one built). A TdPopup, so it works in the menus and in the HUD alike (add it to any Control /
## CanvasLayer); while it is open the game keys are blocked (KeyBinds.block_keys), so Enter does not end the turn and
## Esc does not reach the pause menu under it.
##   TdConfirm.ask(self, "Skip the tutorial?", "You'll play the level without guidance.", "Skip",
##       func(yes: bool): if yes: ..., {"cancel_text": "Keep going"})
## The answer comes once: `answered(yes)` and the callback, before the window closes; then it frees itself.

signal answered(yes: bool)

var title_text := ""
## One line saying what happens (BBCode).
var message := ""
var confirm_text := "OK"
var cancel_text := "Cancel"
## Danger style for a destructive confirm (Quit game, Reset to defaults, Kick); else Primary.
var danger := false
## Optional: the confirm button's icon.
var confirm_icon: Texture2D = null
## Optional: a Control shown above the title (a portrait, a medallion, an icon).
var icon: Control = null
## null until answered, then true / false.
var answer = null

var title_label: Label
var message_label: RichTextLabel
var confirm_button: TdButton
var cancel_button: TdButton
var _box: VBoxContainer
var _icon_holder: CenterContainer
var _row: HBoxContainer
var _on_answer := Callable()

const WIDTH := 760.0
const BUTTON := Vector2(220, 60)

## Opens a confirm over `parent`. opts: cancel_text, danger, icon (Control), confirm_icon (Texture2D).
static func ask(parent: Node, title: String, text: String, confirm: String, on_answer := Callable(), opts := {}) -> TdConfirm:
	var c := TdConfirm.new()
	c.title_text = title
	c.message = text
	c.confirm_text = confirm
	c.cancel_text = str(opts.get("cancel_text", "Cancel"))
	c.danger = bool(opts.get("danger", false))
	c.icon = opts.get("icon", null)
	c.confirm_icon = opts.get("confirm_icon", null)
	c._on_answer = on_answer
	c.free_on_close = true
	c.name = "Confirm"
	parent.add_child(c)
	c.open()
	return c

func _build() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 30)
	p.custom_minimum_size = Vector2(WIDTH, 0)
	c.add_child(p)
	window = p
	_box = TdMenu.vbox(12)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(_box)
	_icon_holder = CenterContainer.new()
	_box.add_child(_icon_holder)
	title_label = TdMenu.label("", "h2", TdTheme.color("cream.100"), 34)
	title_label.add_theme_font_override("font", TdTheme.font("plinth"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(WIDTH - 70.0, 0)
	_box.add_child(title_label)
	message_label = TdMenu.rich("", "body", TdTheme.color("cream.200"), 22)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size = Vector2(WIDTH - 70.0, 0)
	_box.add_child(message_label)
	_row = TdMenu.hbox(16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(_row)
	cancel_button = TdMenu.button(TdButton.Style.SECONDARY, "Cancel", BUTTON)
	cancel_button.name = "Cancel"
	cancel_button.clicked.connect(cancel)
	_row.add_child(cancel_button)
	confirm_button = TdMenu.button(TdButton.Style.PRIMARY, "OK", BUTTON)
	confirm_button.name = "Confirm"
	confirm_button.clicked.connect(confirm)
	_row.add_child(confirm_button)

func _on_open() -> void:
	answer = null
	for ch in _icon_holder.get_children(): ch.queue_free()
	if icon != null:
		if icon.get_parent() != null: icon.get_parent().remove_child(icon)
		_icon_holder.add_child(icon)
	_icon_holder.visible = icon != null
	title_label.text = title_text
	message_label.text = message
	message_label.visible = message != ""
	cancel_button.text = cancel_text
	cancel_button.fit_to_content(BUTTON.x)
	confirm_button.style = TdButton.Style.DANGER if danger else TdButton.Style.PRIMARY
	confirm_button.text = confirm_text
	if confirm_icon != null: confirm_button.icon = confirm_icon
	confirm_button.set_key_hint("Enter")
	confirm_button.fit_to_content(BUTTON.x)

## Yes (the confirm button, Enter).
func confirm() -> void:
	_answer(true)

## No (Cancel, Esc, right click, the scrim).
func cancel() -> void:
	_answer(false)

func back() -> void:
	cancel()

func _answer(yes: bool) -> void:
	if answer != null: return
	answer = yes
	answered.emit(yes)
	if _on_answer.is_valid(): _on_answer.call(yes)
	close()

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open or not is_top() or answer != null: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		confirm()
