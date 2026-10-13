class_name TdEntityStatus
extends Control
## A unit's plate (port of UI_EntityStatus): optional name, a status chip row and the health bar under it (nearest
## the unit). Two looks (UI Design Rules, board plate): compact (default; fits the tile: `plate_width` wide, 28 px
## chips without badges, 6 px gaps, at most 3 slots then 2 + "+N") and full (the hovered or selected unit: bar 164 x 8,
## 32 px chips with time / stack badges, 12 px gaps, 4 slots then 3 + "+N", on a thin dark backing). Text is outlined
## (it sits over the board). Composition: TdHealthBar + TdIconBar, reachable as `health_bar` / `status_bar`.
##   set_entity_name(name), set_health(cur, max), set_health_immediate(cur, max), set_health_preview(hp),
##   set_health_label(visible, format := ""), add_status(key, texture, turns_left := -1, stacks := 0,
##   always_stacks := false, animate := true), update_status(key, turns_left, stacks, always_stacks := false),
##   remove_status(key), set_status_order(keys), get_status(key), activate_status(key), has_status(key),
##   clear_statuses(), status_count(), set_full(full)

@export var plate_width := 96.0:
	set(v):
		plate_width = v
		if is_node_ready(): _layout()
@export var full := false:
	set(v):
		full = v
		if is_node_ready(): _apply_mode()

var health_bar: TdHealthBar
var status_bar: TdIconBar
var _name: Label
var _backing: Panel
var _built := false

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	_backing = Panel.new()
	_backing.mouse_filter = MOUSE_FILTER_IGNORE
	_backing.add_theme_stylebox_override("panel", TdTheme.stylebox("plate_full_backing"))
	add_child(_backing)
	_name = Label.new()
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TdTheme.apply_type(_name, "micro", TdTheme.color("cream.100"))
	TdTheme.outline(_name)
	_name.visible = false
	add_child(_name)
	status_bar = TdIconBar.new()
	status_bar.alignment = TdIconBar.Align.CENTER
	add_child(status_bar)
	health_bar = TdHealthBar.new()
	health_bar.variant = TdHealthBar.Variant.PLATE
	health_bar.outlined_label = true
	add_child(health_bar)
	_apply_mode()

func set_full(v: bool) -> void:
	full = v

func _apply_mode() -> void:
	_build()
	status_bar.badges = full
	status_bar.configure(32.0 if full else 28.0, 12.0 if full else 6.0, 0)
	status_bar.max_icons = 4 if full else 3
	for k in status_bar.keys():
		status_bar.get_icon(k).set_badges_visible(full)
	_backing.visible = full
	_layout()

func _layout() -> void:
	if not _built: return
	status_bar.relayout()
	var w := 164.0 if full else plate_width
	var bar_h := 8.0 if full else 10.0
	var y := 0.0
	if _name.visible:
		_name.position = Vector2(-40, y)
		_name.size = Vector2(w + 80, 24)
		y += 24.0
	var row: Vector2 = status_bar.custom_minimum_size
	if status_bar.count() > 0:
		status_bar.size = Vector2(w, row.y)
		status_bar.position = Vector2(0, y + (9.0 if full else 0.0))
		status_bar.relayout()
		y += row.y + (9.0 if full else 0.0) + 6.0 + (9.0 if full else 0.0)
	health_bar.position = Vector2(0, y)
	health_bar.size = Vector2(w, bar_h)
	y += bar_h
	size = Vector2(w, y)
	custom_minimum_size = size
	_backing.position = Vector2(-10, -6 if not _name.visible else 18)
	_backing.size = Vector2(w + 20, size.y - _backing.position.y + 8)

# ------------------------------------------------------------------ API

func set_entity_name(n: String) -> void:
	_build()
	_name.text = n
	_name.visible = n != ""
	_layout()

func get_entity_name() -> String:
	return _name.text if _built else ""

func set_health(current: float, maximum: float) -> void:
	_build(); health_bar.set_health(current, maximum)

func set_health_immediate(current: float, maximum: float) -> void:
	_build(); health_bar.set_health_immediate(current, maximum)

func set_health_preview(hp: float) -> void:
	_build(); health_bar.set_preview(hp)

func set_health_label(v: bool, fmt := "") -> void:
	_build(); health_bar.set_label_visible(v, fmt)

func get_current_health() -> float:
	return health_bar.get_current_health() if _built else 0.0

func get_max_health() -> float:
	return health_bar.get_max_health() if _built else 0.0

func add_status(key: String, tex: Texture2D, turns_left := -1, stacks := 0, always_stacks := false, animate := true) -> TdIconChip:
	_build()
	var c := status_bar.add_icon(key, tex, "", animate)
	c.set_badges_visible(full)
	c.set_status(turns_left, stacks, always_stacks)
	_layout()
	return c

func update_status(key: String, turns_left: int, stacks := 0, always_stacks := false) -> bool:
	_build()
	return status_bar.set_status(key, turns_left, stacks, always_stacks)

func remove_status(key: String) -> bool:
	_build()
	var ok := status_bar.remove_icon(key)
	_layout()
	return ok

func set_status_order(keys: Array) -> void:
	_build(); status_bar.set_order(keys)

func get_status(key: String) -> TdIconChip:
	return status_bar.get_icon(key) if _built else null

func activate_status(key: String) -> bool:
	return status_bar.activate_icon(key) if _built else false

func has_status(key: String) -> bool:
	return _built and status_bar.has_icon(key)

func clear_statuses() -> void:
	_build(); status_bar.clear_all(); _layout()

func status_count() -> int:
	return status_bar.count() if _built else 0
