@tool
extends EditorPlugin
## The TD Tools editor plugin: adds the "TD Tools" bottom panel (TdToolsDock) and is its host for the
## editor-only calls (play a scene, select a file in the FileSystem dock, rescan, open a file outside).

const Dock := preload("res://addons/td_tools/td_tools_dock.gd")

var dock: Control

func _enter_tree() -> void:
	dock = Dock.new()
	dock.name = "TD Tools"
	dock.host = self
	add_control_to_bottom_panel(dock, "TD Tools")

func _exit_tree() -> void:
	if dock != null:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null

# ---------------------------------------------------------------- host API (the dock calls these; tests stub them)

func play_scene(path: String) -> void:
	EditorInterface.play_custom_scene(path)

func select_file(path: String) -> void:
	EditorInterface.select_file(path)

func open_external(path: String) -> void:
	OS.shell_open(ProjectSettings.globalize_path(path))

func rescan() -> void:
	EditorInterface.get_resource_filesystem().scan()
