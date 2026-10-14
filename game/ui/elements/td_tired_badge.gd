class_name TdTiredBadge
extends Control
## The "tired" mark on a tower that went on a mission today (Missions & Guild — Design § Tower energy; mockups
## mission-detail-tired, hand-select-mission): the kit's badge_tired sprite (res://art/ui/KitB/badges/badge_tired.png:
## a dark round chip with a cream crescent and a "z"), at least 20 px, at the TOP-LEFT of the tower's picture
## (opposite the form badge, bottom-right; under the cost coin where a coin sits). The tower under it is at 50 %.
##   TdTiredBadge.attach(holder, 112.0, 0.24, Vector2(0.17, 0.44))   # centre at fractions of a host of that size

const SPRITE := "res://art/ui/KitB/badges/badge_tired.png"
const MIN_SIZE := 20.0

static var _tex: Texture2D = null

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

static func texture() -> Texture2D:
	if _tex == null and ResourceLoader.exists(SPRITE): _tex = load(SPRITE)
	return _tex

## A badge d px across (never under MIN_SIZE).
static func make(d: float) -> TdTiredBadge:
	var b := TdTiredBadge.new()
	b.custom_minimum_size = Vector2.ONE * maxf(MIN_SIZE, d)
	b.size = b.custom_minimum_size
	return b

## Puts a badge on a host `host_size` px across: frac of that size, centred at `at` (fractions of the host; the
## default is the top-left). Attach it to a control that is not dimmed itself (dim the picture, not its holder).
static func attach(host: Control, host_size: float, frac := 0.3, at := Vector2(0.18, 0.18)) -> TdTiredBadge:
	if host == null: return null
	var b := make(host_size * frac)
	b.position = Vector2(host_size, host_size) * at - b.size / 2.0
	host.add_child(b)
	return b

func _draw() -> void:
	var t := texture()
	if t != null:
		draw_texture_rect(t, Rect2(Vector2.ZERO, size), false)
		return
	# no sprite (not imported yet): a plain navy coin
	draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, Color("#1E2A44"))
