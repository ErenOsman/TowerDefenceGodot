class_name TdIconBar
extends Control
## A row (or rows) of TdIconChips by key (port of UI_IconBar): positions them in code (no container, so chip
## animations never fight a layout), wraps at max_per_row, aligns rows left / centre / right, grows rows down or up,
## and with max_icons collapses the rest into a "+N" chip. Chips are evenly spaced with a fixed gap, never by their
## badges' width (board plate 32 px + 12 gap, compact 28 + 6, right bar 40 + 12).
##   add_icon(key, texture, label := "", animate := true) -> TdIconChip
##   remove_icon(key), update_icon(key, label), set_icon(key, texture), set_status(key, turns_left, stacks, always),
##   activate_icon(key), has_icon(key), get_icon(key), clear_all(), set_order(keys), configure(size, gap, per_row),
##   count(), keys(). The bar's size follows its content (custom_minimum_size).

enum Align { LEFT, CENTER, RIGHT }
enum Rows { DOWN, UP }

@export var icon_size := 32.0
@export var h_spacing := 12.0
@export var v_spacing := 12.0
## 0 = one row.
@export var max_per_row := 0
## 0 = no limit; else from the max_icons-th on: (max_icons - 1) chips + "+N".
@export var max_icons := 0
@export var alignment: Align = Align.LEFT
@export var row_direction: Rows = Rows.DOWN
@export var shape: TdIconChip.ChipShape = TdIconChip.ChipShape.STATUS
@export var badges := true

var _chips: Dictionary = {}   # key -> TdIconChip
var _order: Array = []
var _overflow: Panel
var _overflow_label: Label

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	_relayout()

func count() -> int:
	return _order.size()

func keys() -> Array:
	return _order.duplicate()

func has_icon(key: String) -> bool:
	return _chips.has(key)

func get_icon(key: String) -> TdIconChip:
	return _chips.get(key)

## Adds a chip (or updates the one with that key) and pops it in.
func add_icon(key: String, tex: Texture2D, label := "", animate := true) -> TdIconChip:
	if _chips.has(key):
		var c: TdIconChip = _chips[key]
		c.set_icon(tex)
		c.set_label(label)
		return c
	var chip := TdIconChip.new()
	chip.shape = shape
	chip.chip_size = icon_size
	chip.badges = badges
	chip.size = Vector2(icon_size, icon_size)
	chip.name = "Chip_" + key.validate_node_name()
	add_child(chip)
	chip.set_icon(tex)
	if label != "": chip.set_label(label)
	_chips[key] = chip
	_order.append(key)
	_relayout()
	if animate: chip.play_spawn_animation()
	return chip

func remove_icon(key: String) -> bool:
	if not _chips.has(key): return false
	var c: TdIconChip = _chips[key]
	_chips.erase(key)
	_order.erase(key)
	c.queue_free()
	_relayout()
	return true

func update_icon(key: String, label: String) -> bool:
	if not _chips.has(key): return false
	(_chips[key] as TdIconChip).set_label(label)
	return true

func set_icon(key: String, tex: Texture2D) -> bool:
	if not _chips.has(key): return false
	(_chips[key] as TdIconChip).set_icon(tex)
	return true

## The chip's status badges (TdIconChip.set_status).
func set_status(key: String, turns_left: int, stacks := 0, always_stacks := false) -> bool:
	if not _chips.has(key): return false
	(_chips[key] as TdIconChip).set_status(turns_left, stacks, always_stacks)
	return true

func activate_icon(key: String) -> bool:
	if not _chips.has(key): return false
	(_chips[key] as TdIconChip).play_activate_animation()
	return true

func clear_all() -> void:
	for k in _chips: (_chips[k] as TdIconChip).queue_free()
	_chips.clear()
	_order.clear()
	_relayout()

## Puts the chips in this order of keys (which ones get the visible slots); unknown keys are skipped, the rest keep
## their order after them.
func set_order(order: Array) -> void:
	var out := []
	for k in order:
		if _chips.has(k) and not out.has(k): out.append(k)
	for k in _order:
		if not out.has(k): out.append(k)
	_order = out
	_relayout()

func configure(size_px: float, spacing: float, per_row: int) -> void:
	icon_size = size_px
	h_spacing = spacing
	v_spacing = spacing
	max_per_row = per_row
	for k in _chips:
		var c: TdIconChip = _chips[k]
		c.chip_size = icon_size
	_relayout()

func relayout() -> void:
	_relayout()

## Slot positions (top-left) for n chips: the pure layout (also used by tests).
static func slots(n: int, icon: float, hgap: float, vgap: float, per_row: int, align: int, rows_up: bool, width := -1.0) -> Array:
	var out := []
	if n <= 0: return out
	var per := per_row if per_row > 0 else n
	var rows := int(ceil(float(n) / per))
	var full_w := per * icon + (per - 1) * hgap
	var w := width if width >= 0.0 else full_w
	for i in n:
		var r := floori(float(i) / per)
		var c := i % per
		var in_row := mini(per, n - r * per)
		var row_w := in_row * icon + (in_row - 1) * hgap
		var x0 := 0.0
		if align == Align.CENTER: x0 = (w - row_w) / 2.0
		elif align == Align.RIGHT: x0 = w - row_w
		var ry := r if not rows_up else (rows - 1 - r)
		out.append(Vector2(x0 + c * (icon + hgap), ry * (icon + vgap)))
	return out

func _relayout() -> void:
	var shown := _order.size()
	var extra := 0
	if max_icons > 0 and _order.size() > max_icons:
		shown = max_icons - 1
		extra = _order.size() - shown
	var n := shown + (1 if extra > 0 else 0)
	var per := max_per_row if max_per_row > 0 else maxi(n, 1)
	var cols := mini(per, maxi(n, 1))
	var rows := int(ceil(float(maxi(n, 1)) / per))
	var w := cols * icon_size + (cols - 1) * h_spacing
	var h := rows * icon_size + (rows - 1) * v_spacing
	custom_minimum_size = Vector2(maxf(w, 0.0), maxf(h, 0.0)) if n > 0 else Vector2.ZERO
	var width := maxf(size.x, w)
	var pos := slots(n, icon_size, h_spacing, v_spacing, max_per_row, alignment, row_direction == Rows.UP, width)
	for i in _order.size():
		var c: TdIconChip = _chips[_order[i]]
		c.visible = i < shown
		if i < shown:
			c.position = pos[i]
			c.size = Vector2(icon_size, icon_size)
	if extra > 0:
		_ensure_overflow()
		_overflow.visible = true
		_overflow.position = pos[n - 1]
		_overflow.size = Vector2(icon_size, icon_size)
		_overflow_label.text = "+%d" % extra
		_overflow_label.size = _overflow.size
		_overflow_label.add_theme_font_size_override("font_size", 18 if icon_size >= 32 else 16)
	elif _overflow != null:
		_overflow.visible = false

func _ensure_overflow() -> void:
	if _overflow != null: return
	_overflow = Panel.new()
	_overflow.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(TdTheme.color("wood.900"), 0.9)
	sb.set_corner_radius_all(64)
	sb.border_color = TdTheme.color("wood.500")
	sb.set_border_width_all(2)
	_overflow.add_theme_stylebox_override("panel", sb)
	_overflow_label = Label.new()
	_overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overflow_label.add_theme_font_override("font", TdTheme.font("plinth"))
	_overflow_label.add_theme_color_override("font_color", TdTheme.color("cream.100"))
	_overflow.add_child(_overflow_label)
	add_child(_overflow)
