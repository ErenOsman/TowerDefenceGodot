class_name CoopJoinPopup
extends TdPopup
## Join a password room (mockups lobby-join / -join-wrong / -join-full): the room line, the password field with
## Show, Join. Wrong password turns the field red with "Wrong password. Ask the host for it again."; a full room
## says so and Join stays off. Closes itself once the relay puts you in the room.

var net: Node = null
var room_info: Dictionary = {}
var _password: LineEdit
var _warn: HBoxContainer
var _join: TdButton
var _line: RichTextLabel

func _build() -> void:
	var w := CoopUi.window(self, Vector2(760, 0), 32)
	window = w.panel
	var body: VBoxContainer = w.body
	var head := CoopUi.title_row("Join room", "", 48)
	head.close.clicked.connect(close)
	body.add_child(head.row)
	_line = TdMenu.rich("", "body", TdTheme.color("cream.200"), 22)
	body.add_child(_line)
	body.add_child(TdMenu.label("Password", "h3", TdTheme.color("cream.100"), 24))
	var row := TdMenu.hbox(10)
	body.add_child(row)
	_password = CoopUi.field("Password", 0, true, 64)
	_password.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_password.text_submitted.connect(func(_t): join())
	_password.text_changed.connect(func(_t):
		CoopUi.field_error(_password, false)
		CoopUi.set_warning(_warn, ""))
	row.add_child(_password)
	var show := TdMenu.wood_button("Show", Vector2(110, 56))
	show.pressed.connect(func():
		_password.secret = not _password.secret
		show.text = "Hide" if not _password.secret else "Show")
	row.add_child(show)
	_warn = CoopUi.warning()
	body.add_child(_warn)
	var jr := TdMenu.hbox(0)
	jr.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(jr)
	_join = TdMenu.button(TdButton.Style.PRIMARY, "Join", Vector2(222, 62))
	_join.font_size = 28
	_join.clicked.connect(join)
	jr.add_child(_join)

func _on_open() -> void:
	var host := str(room_info.get("host_name", ""))
	_line.text = "[b]%s[/b] · %s%s" % [room_info.get("name", ""), CoopLevels.level_name(str(room_info.get("level", ""))), (" · host " + host) if host != "" else ""]
	if net != null:
		if not net.error_received.is_connected(_on_error): net.error_received.connect(_on_error)
		if not net.room_changed.is_connected(_on_room): net.room_changed.connect(_on_room)
	var full: bool = NetProtocol.int_of(room_info, "players") >= NetProtocol.int_of(room_info, "count")
	if full: show_error("full")
	_password.grab_focus.call_deferred()

func join() -> void:
	if net == null: return
	net.join_room(str(room_info.get("id", "")), _password.text, CoopLevels.my_hand_types(CoopLevels.hand_cap(str(room_info.get("level", "")))))

## Shows a relay error the way the mockups do (tests and tools call it too).
func show_error(code: String) -> void:
	CoopUi.set_warning(_warn, NetProtocol.error_text(code))
	CoopUi.field_error(_password, code == "wrong_password")
	if code == "full" or code == "started" or code == "not_found":
		_join.set_interactable(false, NetProtocol.error_text(code))

func _on_error(code: String, _text: String) -> void:
	if is_open: show_error(code)

func _on_room(room: Dictionary) -> void:
	if is_open and not room.is_empty(): close()

func _exit_tree() -> void:
	super._exit_tree()
	if net != null:
		if net.error_received.is_connected(_on_error): net.error_received.disconnect(_on_error)
		if net.room_changed.is_connected(_on_room): net.room_changed.disconnect(_on_room)
