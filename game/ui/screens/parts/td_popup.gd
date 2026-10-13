class_name TdPopup
extends Control
## A menu popup (Unity UIManager "popup" semantics): full screen, a scrim behind a window, opens with
## TdPanelTransition (unscaled time), Back closes it. Back = Esc, a right click anywhere, or a left click on the
## scrim (when close_on_scrim). Popups stack: the last one added gets Esc first (Godot hands input to the last
## child first) and marks it handled, so Esc closes only the top popup. While any popup is open, game keys are
## blocked (KeyBinds.block_keys) and stay blocked two frames after the last closes, so the Esc that closed it is
## not read by a pause menu polling KeyBinds.back_pressed().
##   var s = load("res://game/ui/screens/settings.tscn").instantiate(); add_child(s); s.open()
##   s.closed.connect(...)
## Subclasses build their window in _build() (called once from _ready) and put it in `window`.

signal closed

## The open popups (to know which one is on top).
static var open_popups: Array = []
static var _unblock_serial := 0

## Closing frees the popup (else it only hides; open() again to show it).
@export var free_on_close := false
## A left click on the scrim closes it.
@export var close_on_scrim := true
## A right click closes it.
@export var right_click_closes := true
## Shows the scrim (off for full-screen panels that draw their own background).
@export var use_scrim := true

var scrim: TdScrim
## The panel that scales in and out (subclasses set it in _build()).
var window: Control
var is_open := false
var _built := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = TdTheme.theme()
	_ensure_built()

func _ensure_built() -> void:
	if _built: return
	_built = true
	scrim = TdScrim.new()
	scrim.visible = use_scrim
	scrim.clicked.connect(func(button: int):
		if button == MOUSE_BUTTON_LEFT and close_on_scrim: back()
		elif button == MOUSE_BUTTON_RIGHT and right_click_closes: back())
	add_child(scrim)
	_build()

## Override: build the window (add it as a child and set `window`).
func _build() -> void:
	pass

## Override: refresh the content each time it opens.
func _on_open() -> void:
	pass

## Shows it (transition from 0.96 + fade).
func open() -> void:
	_ensure_built()
	if not is_inside_tree():
		push_warning("[TdPopup] add it to the tree before open()")
	is_open = true
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	open_popups.erase(self)
	open_popups.append(self)
	_block_keys()
	_on_open()
	if use_scrim: scrim.fade_in()
	if window != null:
		window.modulate.a = 0.0 # hidden until its transition starts (no full-size flash on the first frame)
		await get_tree().process_frame # the window's size is known after a frame
		if is_open and is_instance_valid(window): TdPanelTransition.open(window)

## Hides it (quick transition), then emits closed (and frees it when free_on_close).
func close() -> void:
	if not is_open: return
	is_open = false
	open_popups.erase(self)
	_release_keys()
	if use_scrim: scrim.fade_out()
	var done := func() -> void:
		visible = false
		mouse_filter = MOUSE_FILTER_IGNORE
		closed.emit()
		if free_on_close: queue_free()
	if window != null and window.visible and is_inside_tree(): TdPanelTransition.close(window, done)
	else: done.call()

## Back pressed while this is the top popup: closes it (override for other behaviour, e.g. cancel a key capture).
func back() -> void:
	close()

## Whether this is the topmost open popup.
func is_top() -> bool:
	return is_open and not open_popups.is_empty() and open_popups[open_popups.size() - 1] == self

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_top(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and right_click_closes:
		get_viewport().set_input_as_handled()
		back()

func _exit_tree() -> void:
	if is_open:
		is_open = false
		open_popups.erase(self)
		_release_keys()

# ------------------------------------------------------------------ game keys

func _block_keys() -> void:
	_unblock_serial += 1
	var kb := _key_binds()
	if kb != null: kb.block_keys = true

func _release_keys() -> void:
	if not open_popups.is_empty(): return
	_unblock_serial += 1
	var serial := _unblock_serial
	var tree := get_tree() if is_inside_tree() else null
	if tree == null: return
	_unblock_later(tree, serial, 2)

## Unblocks the game keys after `frames` frames unless a popup opened meanwhile (static: survives the popup being freed).
static func _unblock_later(tree: SceneTree, serial: int, frames: int) -> void:
	tree.process_frame.connect(func() -> void:
		if serial != _unblock_serial or not open_popups.is_empty(): return
		if frames > 1:
			_unblock_later(tree, serial, frames - 1)
			return
		var kb := _key_binds_of(tree)
		if kb != null and not settings_capturing: kb.block_keys = false, CONNECT_ONE_SHOT)

## Set by the Controls page while it captures a key (keys stay blocked then).
static var settings_capturing := false

func _key_binds() -> Node:
	return get_node_or_null("/root/KeyBinds") if is_inside_tree() else null

static func _key_binds_of(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null("KeyBinds") if tree != null else null
