class_name TdTiredBadge
extends Control
## The "tired" mark on a tower that went on a mission today (Missions & Guild — Design § Tower energy; mockups
## mission-detail-tired, hand-select-mission): a small navy coin with a cream crescent moon and a "z". Drawn (the
## kit has no moon sprite). The tower under it is shown at 50 %.
##   TdTiredBadge.attach(figure, 88.0)        # on a miniature / medallion of that size

const NAVY := Color("#1E2A44")
const CREAM := Color("#F3E7CF")

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

## A badge d px across.
static func make(d: float) -> TdTiredBadge:
	var b := TdTiredBadge.new()
	b.custom_minimum_size = Vector2(d, d)
	b.size = b.custom_minimum_size
	return b

## Puts a badge on a picture `host_size` px across: frac of its size, centred at `at` (fractions of the host).
## Attach it to a control that is not dimmed itself (dim the picture, not its holder), so it stays full strength.
static func attach(host: Control, host_size: float, frac := 0.34, at := Vector2(0.5, 0.62)) -> TdTiredBadge:
	if host == null: return null
	var d := maxf(18.0, host_size * frac)
	var b := make(d)
	b.position = Vector2(host_size, host_size) * at - Vector2(d, d) / 2.0
	host.add_child(b)
	return b

func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c + Vector2(0, 1.5), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, NAVY)
	draw_arc(c, r - 1.0, 0, TAU, 32, Color(CREAM, 0.85), maxf(1.5, r * 0.12), true)
	# the crescent: a cream disc with a navy disc cut out of its right side
	var mr := r * 0.5
	var mc := c + Vector2(-r * 0.06, 0)
	draw_circle(mc, mr, CREAM)
	draw_circle(mc + Vector2(mr * 0.5, -mr * 0.3), mr * 0.82, NAVY)
	# the "z", top right of the moon
	var f := TdTheme.font("nunito_extrabold")
	if f != null:
		var fs := int(maxf(9.0, r * 0.62))
		draw_string(f, c + Vector2(r * 0.18, -r * 0.08), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CREAM)
