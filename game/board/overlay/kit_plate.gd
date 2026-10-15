class_name KitPlate
extends Control
## The board plate drawn with the ui-kit's TdEntityStatus (status chips over the HP bar, compact / full forms,
## kit sprites, badges), adapted to what PlateLayer calls (the same calls as BoardPlate, the overlay's own
## fallback). Its origin is the HP bar's CENTRE (Unity's plate prefab: a 10-tall rect with a centre pivot placed on
## EntityView.PlateScreenPosition), and the layout is Unity's PlateLayer metrics (plate_rects), owned here so no
## stale kit size can move the bar: bar 10 thick in both forms, compact width = the tile − 8, full 164; the chip
## row's bottom 11 over the bar's top (compact: 6 lower, no pills); the full backing 8 / 6 round the bar, chips and
## pills. Everything × the zoom scale, laid out at the final pixel size (no scale transform: crisp text).

const BAR_HEIGHT := 10.0      # PlateLayer.BarHeight (both forms; user, 2026-10-10)
const FULL_WIDTH := 164.0
const ROW_GAP := 11.0         # the bar's top → the chip row's bottom (the prefab's StatusBar anchoredPosition.y)
const COMPACT_DROP := 6.0     # compact chips sit lower (no pills to clear; user, 2026-10-11)
const FULL_CHIP := 32.0
const PILL_ROOM := 13.0       # the time / stack pills reach this far over the chips (9 let the stack pill sit on
                              # the backing's rim: QA round 2)
const BACKING_PAD := Vector2(8.0, 6.0)

## StatusDef → Texture2D (the status icon), or null.
var icon_of: Callable = Callable()
var status: TdEntityStatus
## An opaque dark backing behind the full plate (the kit's backing is translucent: a neighbour's bar showed through).
var _backing: Panel
var _keys: Array = []
## key → StatusView shown in each chip (the status tooltips read it).
var views_by_key := {}
var _scale := 1.0
var _width := 96.0            # the bar's width before the zoom scale (compact: (tile − 8) / scale)
var _shown_once := false
var _hp := -1                 # the HP last given to the bar (Unity's binder tells it only about changes)
var _max_hp := -1

## The plate's parts round its origin (the bar's centre), Unity's PlateLayer metrics: full or compact, width = the
## bar's width before the scale s (ignored when full: 164), statuses = the plate shows chips. Returns
## {bar: Rect2, row_bottom: float (y of the chip row's bottom edge), backing: Rect2 (full only, else empty)}.
static func plate_rects(full: bool, width: float, s: float, statuses: bool) -> Dictionary:
	# whole, even pixel sizes: the bar sits exactly centred on the (whole-pixel) anchor
	var w := 2.0 * roundf((FULL_WIDTH if full else maxf(24.0, width)) * s * 0.5)
	var h := 2.0 * roundf(BAR_HEIGHT * s * 0.5)
	var bar := Rect2(-w * 0.5, -h * 0.5, w, h)
	var row_bottom := bar.position.y - (ROW_GAP - (0.0 if full else COMPACT_DROP)) * s
	var backing := Rect2()
	if full:
		var bh := (BACKING_PAD.y + BAR_HEIGHT + ROW_GAP + FULL_CHIP + PILL_ROOM + BACKING_PAD.y) if statuses else (BACKING_PAD.y + BAR_HEIGHT + BACKING_PAD.y)
		var bottom := bar.end.y + BACKING_PAD.y * s
		backing = Rect2(-(w + 2.0 * BACKING_PAD.x * s) * 0.5, bottom - bh * s, w + 2.0 * BACKING_PAD.x * s, bh * s)
	return {"bar": bar, "row_bottom": row_bottom, "backing": backing}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing = Panel.new()
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.085, 0.065, 0.85) # the board shows through a little
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
	# only changes reach the bar (EntityStatusBinder.Show): set_health every frame restarted its ease each frame,
	# so a hit barely moved the fill, the ghost never trailed and a heal never filled
	var mx := maxi(1, f.max_hp)
	if not _shown_once:
		status.set_health_immediate(f.hp, mx)
		_unity_bar(status.health_bar)
		_shown_once = true
	elif f.hp != _hp or mx != _max_hp: status.set_health(f.hp, mx)
	_hp = f.hp
	_max_hp = mx
	var wanted: Array = []
	views_by_key.clear()
	for s in PlateLayer.status_order(f.statuses):
		var key: String = s.def.name if s.def != null else s.name
		wanted.append(key)
		views_by_key[key] = s
		var stacks: int = s.shield if s.shield > 0 else s.stacks
		if status.has_status(key): status.update_status(key, s.turns_left, stacks, s.shield > 0)
		else:
			var tex: Texture2D = icon_of.call(s.def) if icon_of.is_valid() and s.def != null else null
			status.add_status(key, tex, s.turns_left, stacks, s.shield > 0)
	for k in _keys:
		if not wanted.has(k): status.remove_status(k)
	if wanted != _keys: status.set_status_order(wanted)
	_keys = wanted
	_ignore_pointer(status)
	_align()

## The Unity plate prefab's UI_HealthBar settings (EntityStatus.prefab): a smooth gradient full (0.2, 0.85, 0.3) →
## half (0.95, 0.85, 0.15) → empty (0.9, 0.15, 0.15); the ghost white at 35 % on a hit, (0.3, 1, 0.5) at 35 % on a
## heal. Its timings (fill 0.3 s smoothstep at once; ghost waits 0.3 s then drains in 0.6 s; heal: ghost jumps
## ahead, fill follows after 0.3 s in 0.3 s) are TdHealthBar's constants, the same numbers.
static func _unity_bar(bar: TdHealthBar) -> void:
	if bar == null: return
	bar.unity_gradient = true
	bar.full_color = Color(0.2, 0.85, 0.3)
	bar.half_color = Color(0.95, 0.85, 0.15)
	bar.empty_color = Color(0.9, 0.15, 0.15)
	bar.ghost_damage_color = Color(1, 1, 1, 0.35)
	bar.ghost_heal_color = Color(0.3, 1, 0.5, 0.35)
	bar._layout()

func set_form(full: bool, width: float, p_scale: float, dimmed: bool) -> void:
	if status.full != full:
		# the kit plate keeps its last size as its minimum: let it shrink back to the compact width
		status.custom_minimum_size = Vector2.ZERO
		status.full = full
	# no scale transform (text would be resampled and blur): the kit plate lays out at the final pixel size
	status.set_metrics(p_scale)
	scale = Vector2.ONE
	_scale = p_scale
	_width = width
	modulate.a = 0.5 if dimmed else 1.0
	_align()

func set_health_preview(v) -> void:
	status.set_health_preview(float(v) if v != null else -1.0)

func set_health_visible(v: bool) -> void:
	if status.health_bar != null: status.health_bar.visible = v

func place_at(p: Vector2) -> void:
	position = p.round() # whole pixels: crisp text

func tick(_dt: float) -> void:
	pass

## Lays the parts out round the origin (plate_rects): the bar centred on it, the chip row centred over the bar, the
## backing round both when full. Every size comes from the form, the width and the scale, never from the kit
## controls' last size (which only grows: a plate hovered once kept its full width and slid).
func _align() -> void:
	var r := plate_rects(status.full, _width, _scale, has_statuses)
	status.position = Vector2.ZERO
	var bar: Rect2 = r.bar
	if status.health_bar != null:
		status.health_bar.position = bar.position.round()
		status.health_bar.size = bar.size.round()
	if status.status_bar != null:
		var row := status.status_bar
		row.relayout()
		row.size = row.custom_minimum_size
		row.relayout()
		row.position = Vector2(-row.size.x * 0.5, r.row_bottom - row.size.y).round()
	# the kit plate's own translucent backing and name line are not used on the board
	if status._backing != null: status._backing.visible = false
	_backing.visible = status.full
	if status.full:
		var b: Rect2 = r.backing
		_backing.position = b.position.round()
		_backing.size = b.size.round()

## The plate never takes the pointer (clicks and hover reach the unit and the tiles under it): every control in it.
func _ignore_pointer(n: Node) -> void:
	for c in n.get_children():
		if c is Control: (c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_pointer(c)

## The status chip under a canvas point: [key, chip rect], or [] (only chips that show).
func chip_at(p: Vector2) -> Array:
	if status.status_bar == null: return []
	for k in status.status_bar.keys():
		var chip: Control = status.status_bar.get_icon(k)
		if chip != null and chip.is_visible_in_tree() and chip.get_global_rect().has_point(p): return [k, chip.get_global_rect()]
	return []

## The plate's drawn rect on the canvas (its backing when full).
func plate_rect() -> Rect2:
	if _backing.visible: return _backing.get_global_rect()
	var r := Rect2(status.health_bar.get_global_rect()) if status.health_bar != null else Rect2(global_position, Vector2.ZERO)
	if has_statuses and status.status_bar != null: r = r.merge(status.status_bar.get_global_rect())
	return r
