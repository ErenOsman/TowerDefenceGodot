@tool
extends VBoxContainer
## Base of a TD Tools tab: built in _init (so it can be made without the editor), filled on first show.

const D := preload("res://addons/td_tools/td_tools_dock.gd")

var dock = null # TdToolsDock
var status: Label
var _shown := false

func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	build()
	status = Label.new()
	status.clip_text = true
	status.modulate = Color(1, 1, 1, 0.8)
	add_child(status)

## Builds the controls (override).
func build() -> void:
	pass

## The tab became visible: fills it the first time (override fill()).
func on_shown() -> void:
	if not _shown:
		_shown = true
		fill()

## Fills from the content / files (override).
func fill() -> void:
	pass

func on_content_reloaded() -> void:
	if _shown: fill()

func say(text: String) -> void:
	status.text = text
