class_name BoardPlate
extends Control
## The plate over one entity (UI Design Rules, board plates): an HP bar and up to 3 (compact) or 4 (full) status
## chips. Compact on the board: the bar as wide as the tile minus 8, 28 px chips without badges, 6 px apart. Full
## (hovered or selected): a 164 px bar on a dark backing, 32 px chips with time and stack pills, 12 px apart.
## Drawn in _draw (no child nodes), never takes the pointer. A minimal stand-in for the ui-kit's TdEntityStatus:
## PlateLayer only calls show_frame / set_form / set_health_preview / set_health_visible / place_at.
## The control's origin is the bar's bottom-centre point; it draws upward from there.

const BAR_HEIGHT := 10.0
const FULL_WIDTH := 164.0
const COMPACT_CHIP := 28.0
const FULL_CHIP := 32.0
const COMPACT_GAP := 6.0
const FULL_GAP := 12.0
const CHIP_LIFT := 11.0          # from the bar's top to the chips' bottom
const COMPACT_DROP := 6.0        # compact chips sit a little lower (no pills to clear)

## StatusDef → Texture2D (the status icon), or null.
var icon_of: Callable = Callable()

var hp := 0
var max_hp := 1
var shield := 0
var statuses: Array = []          # StatusView
var health_visible := true
var preview_hp = null             # int or null: the HP a previewed hit or heal would leave
var full := false
var bar_width := 64.0
var dimmed := false

var _shown_ratio := -1.0          # the fill as drawn (slides to the real ratio)
var _ghost_ratio := 0.0           # the lost part, shrinking to the fill after a moment
var _ghost_wait := 0.0
var _blink := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO

## The frame's values for this entity.
func show_frame(f: EntityFrame) -> void:
	var ratio_before := _ratio()
	hp = f.hp
	max_hp = maxi(1, f.max_hp)
	shield = f.shield
	statuses = OverlayStyle.ordered_statuses(f.statuses)
	var ratio := _ratio()
	if _shown_ratio < 0.0: _shown_ratio = ratio
	if ratio < ratio_before - 0.0001 and _ghost_ratio < ratio_before:
		_ghost_ratio = maxf(_ghost_ratio, ratio_before)
		_ghost_wait = 0.4
	queue_redraw()

func set_form(p_full: bool, width: float, p_scale: float, p_dimmed: bool) -> void:
	full = p_full
	bar_width = width
	scale = Vector2.ONE * p_scale
	dimmed = p_dimmed
	modulate.a = 0.5 if dimmed else 1.0
	queue_redraw()

func set_health_preview(v) -> void:
	preview_hp = v
	queue_redraw()

func set_health_visible(v: bool) -> void:
	health_visible = v
	queue_redraw()

## Puts the bar's bottom-centre at a canvas point.
func place_at(p: Vector2) -> void:
	position = p

var has_statuses: bool:
	get: return statuses.size() > 0

func _ratio() -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0

## Advances the bar's slide, the ghost and the preview blink (unscaled seconds).
func tick(dt: float) -> void:
	var target := _ratio()
	if _shown_ratio < 0.0: _shown_ratio = target
	var moving := absf(_shown_ratio - target) > 0.001
	_shown_ratio = move_toward(_shown_ratio, target, dt * 2.5)
	if _ghost_wait > 0.0: _ghost_wait -= dt
	elif _ghost_ratio > _shown_ratio: _ghost_ratio = move_toward(_ghost_ratio, _shown_ratio, dt * 1.5)
	_blink += dt
	if moving or _ghost_ratio > _shown_ratio or preview_hp != null: queue_redraw()

func _draw() -> void:
	var w := bar_width
	var x0 := -w * 0.5
	var chips := statuses.size() > 0
	var chip := FULL_CHIP if full else COMPACT_CHIP
	var gap := FULL_GAP if full else COMPACT_GAP
	var slots := 4 if full else 3
	if full:
		var back_h := 6.0 + BAR_HEIGHT + 6.0
		if chips: back_h = 6.0 + BAR_HEIGHT + CHIP_LIFT + FULL_CHIP + 9.0 + 6.0
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.09, 0.07, 0.05, 0.55)
		back.set_corner_radius_all(8)
		draw_style_box(back, Rect2(x0 - 8.0, -back_h + 6.0, w + 16.0, back_h))
	if health_visible:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.12, 0.09, 0.07, 0.92)
		frame.border_color = OverlayStyle.RIM
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(4)
		draw_style_box(frame, Rect2(x0, -BAR_HEIGHT, w, BAR_HEIGHT))
		var inner := Rect2(x0 + 2.0, -BAR_HEIGHT + 2.0, w - 4.0, BAR_HEIGHT - 4.0)
		var ratio := clampf(_shown_ratio, 0.0, 1.0)
		if _ghost_ratio > ratio:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost_ratio, inner.size.y)), OverlayStyle.HP_GHOST)
		var real := _ratio()
		var col := OverlayStyle.HP_HIGH if real > 0.5 else (OverlayStyle.HP_MID if real > 0.25 else OverlayStyle.HP_LOW)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), col)
		if shield > 0:
			var s := clampf(float(shield) / float(max_hp), 0.0, 1.0)
			draw_rect(Rect2(inner.position + Vector2(0, 0), Vector2(inner.size.x * s, inner.size.y * 0.45)), Color(0.75, 0.85, 1.0, 0.9))
		if preview_hp != null:
			var after := clampf(float(preview_hp) / float(max_hp), 0.0, 1.0)
			var blink := 0.55 + 0.45 * absf(sin(_blink * 5.0))
			if after < real:
				var tex := OverlayStyle.kit("board/stripes_damage_preview")
				var r := Rect2(inner.position + Vector2(inner.size.x * after, 0), Vector2(inner.size.x * (real - after), inner.size.y))
				if tex != null: draw_texture_rect(tex, r, true, Color(1, 1, 1, blink))
				else: draw_rect(r, Color(1, 1, 1, blink * 0.8))
			elif after > real:
				var tex2 := OverlayStyle.kit("board/stripes_heal_preview")
				var r2 := Rect2(inner.position + Vector2(inner.size.x * real, 0), Vector2(inner.size.x * (after - real), inner.size.y))
				if tex2 != null: draw_texture_rect(tex2, r2, true, Color(1, 1, 1, blink))
				else: draw_rect(r2, Color(OverlayStyle.FX_HEAL, blink * 0.8))
	if not chips: return
	var overflow := statuses.size() > slots
	var n := slots if not overflow else slots - 1 # 4+ in 3 slots: 2 chips + "+N"
	n = mini(n, statuses.size())
	var cells := n + (1 if overflow else 0)
	var row_w := cells * chip + (cells - 1) * gap
	var y := -BAR_HEIGHT - CHIP_LIFT - chip + (0.0 if full else COMPACT_DROP)
	if not health_visible: y = -chip
	var x := -row_w * 0.5
	for i in n:
		_draw_chip(statuses[i], Rect2(x, y, chip, chip))
		x += chip + gap
	if overflow:
		var r := Rect2(x, y, chip, chip)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.13, 0.1, 0.08, 0.92)
		box.border_color = OverlayStyle.RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		draw_style_box(box, r)
		var f := OverlayStyle.font()
		draw_string(f, Vector2(r.position.x, r.position.y + chip * 0.66), "+%d" % (statuses.size() - n), HORIZONTAL_ALIGNMENT_CENTER, chip, int(chip * 0.5), OverlayStyle.CREAM)

func _draw_chip(s: StatusView, r: Rect2) -> void:
	var bg_name := "board/chip_unit_status"
	if s.def != null:
		if s.def.has_tag("Buff"): bg_name = "board/chip_unit_buff"
		elif s.def.has_tag("Debuff"): bg_name = "board/chip_unit_debuff"
	var bg := OverlayStyle.kit(bg_name)
	if bg != null: draw_texture_rect(bg, r, false)
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = OverlayStyle.CHIP_STATUS_BG
		box.border_color = OverlayStyle.RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		draw_style_box(box, r)
	var icon: Texture2D = icon_of.call(s.def) if icon_of.is_valid() and s.def != null else null
	if icon != null: draw_texture_rect(icon, r.grow(-r.size.x * 0.14), false)
	else:
		var f := OverlayStyle.font(OverlayStyle.BODY_FONT)
		draw_string(f, r.position + Vector2(0, r.size.y * 0.68), s.name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.55), OverlayStyle.CREAM)
	if not full: return
	if s.turns_left > 0: _pill(str(s.turns_left), r.position, true)
	var stacks := s.shield if s.shield > 0 else s.stacks
	if stacks > 1 or (s.shield > 0 and stacks > 0): _pill(_short(stacks), r.position + r.size, false)

## A badge pill centred on a chip corner: cream (time, top-left) or dark (stacks, bottom-right).
func _pill(text: String, centre: Vector2, cream: bool) -> void:
	var f := OverlayStyle.font()
	var fs := 14
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := 18.0
	var w := maxf(h, tw + 8.0)
	var r := Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = OverlayStyle.PAPER if cream else Color(0.13, 0.1, 0.08)
	box.border_color = OverlayStyle.RIM
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	draw_style_box(box, r)
	draw_string(f, Vector2(r.position.x, r.position.y + h * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, OverlayStyle.INK if cream else OverlayStyle.CREAM)

static func _short(n: int) -> String:
	if n < 1000: return str(n)
	return "%.1fk" % (n / 1000.0)
