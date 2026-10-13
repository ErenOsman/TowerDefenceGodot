extends Node
## Autoload `DevPanel`: listens for F1 and opens the dev panel (TdDevPanel, game/dev/dev_panel.gd), only in debug
## builds or when `--dev` is among the user arguments (`godot -- --dev`). Also installs the log capture (DevLog)
## then. Does nothing else; release builds without --dev never build the panel.

var enabled := false
var panel: TdDevPanel = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = is_enabled()
	set_process_input(enabled)
	if enabled: DevLog.install()

## Debug build, or `--dev` passed after `--`.
static func is_enabled() -> bool:
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if panel != null and panel.visible: panel.close_panel()
	else: open()

func open() -> TdDevPanel:
	if not enabled: return null
	if panel == null:
		panel = TdDevPanel.new()
		panel.visible = false
		add_child(panel)
	panel.open_panel()
	return panel
