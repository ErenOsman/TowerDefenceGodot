class_name KitPlate
extends Control
## The board plate drawn with the ui-kit's TdEntityStatus (status chips over the HP bar, compact / full forms,
## kit sprites, badges), adapted to what PlateLayer calls (the same calls as BoardPlate, the overlay's own
## fallback). Its origin is the HP bar's bottom-centre point; the kit plate hangs above it.

## StatusDef → Texture2D (the status icon), or null.
var icon_of: Callable = Callable()
var status: TdEntityStatus
## An opaque dark backing behind the full plate (the kit's backing is translucent: a neighbour's bar showed through).
var _backing: Panel
var _keys: Array = []
var _shown_once := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing = Panel.new()
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.085, 0.065, 0.94)
	box.border_color = OverlayStyle.RIM
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	_backing.add_theme_stylebox_override("panel", box)
	_backing.visible = false
	add_child(_backing)
	status = TdEntityStatus.new()
	add_child(status)

var has_statuses: bool:
	get: return status.status_count() > 0

func show_frame(f: EntityFrame) -> void:
	if not _shown_once:
		status.set_health_immediate(f.hp, maxi(1, f.max_hp))
		_shown_once = true
	else: status.set_health(f.hp, maxi(1, f.max_hp))
	var wanted: Array = []
	for s in PlateLayer.status_order(f.statuses):
		var key: String = s.def.name if s.def != null else s.name
		wanted.append(key)
		var stacks: int = s.shield if s.shield > 0 else s.stacks
		if status.has_status(key): status.update_status(key, s.turns_left, stacks, s.shield > 0)
		else:
			var tex: Texture2D = icon_of.call(s.def) if icon_of.is_valid() and s.def != null else null
			status.add_status(key, tex, s.turns_left, stacks, s.shield > 0)
	for k in _keys:
		if not wanted.has(k): status.remove_status(k)
	if wanted != _keys: status.set_status_order(wanted)
	_keys = wanted
	_align()

func set_form(full: bool, width: float, p_scale: float, dimmed: bool) -> void:
	if status.full != full:
		# the kit plate keeps its last size as its minimum: let it shrink back to the compact width
		status.custom_minimum_size = Vector2.ZERO
		status.full = full
	if not full and absf(status.plate_width - width) > 0.5: status.plate_width = width
	scale = Vector2.ONE * p_scale
	modulate.a = 0.5 if dimmed else 1.0
	_align()

func set_health_preview(v) -> void:
	status.set_health_preview(float(v) if v != null else -1.0)

func set_health_visible(v: bool) -> void:
	if status.health_bar != null: status.health_bar.visible = v

func place_at(p: Vector2) -> void:
	position = p

func tick(_dt: float) -> void:
	pass

## Hangs the kit plate above the origin (its bar's bottom edge on it, centred).
func _align() -> void:
	# centred on the unit for both widths: from the form's own width and the bar's bottom, never a stale size
	var w := 164.0 if status.full else status.plate_width
	var bottom := status.size.y
	if status.health_bar != null: bottom = status.health_bar.position.y + status.health_bar.size.y
	status.position = Vector2(-w * 0.5, -bottom)
	_backing.visible = status.full
	if status.full:
		_backing.position = status.position - Vector2(10, 8)
		_backing.size = status.size + Vector2(20, 14)
