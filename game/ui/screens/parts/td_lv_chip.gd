class_name TdLvChip
extends PanelContainer
## The Lv chip (Upgrades — Design § Shown where; UI/UX mockup screens-b/lv-chip.html): one small cream pill, Plinth
## 16, "Lv N" in dark ink on paper with a thin dark rim. On a portrait it sits at the BOTTOM-LEFT (UI Design Rules
## badge placement: the form badge keeps the bottom-right, the tired badge the top-left, cost and key the top
## corners); inline it follows a name (inspector name row, Upgrade header, picker card). Never shown before the
## Blacksmith opens: callers check TdLvChip.shown().
##   TdLvChip.attach(portrait, level, diameter)    # level <= 0 → removes an old chip, adds nothing
##   row.add_child(TdLvChip.make(level, 18))
## Also the picker's green "ready to upgrade" mark (TdLvChip.ready_mark), the same family of small portrait badges.

const PAPER := Color("#F4E7CD")
const INK := Color("#2A1D14")
const FONT_SIZE := 16

static var _star: Texture2D = null

var level := 1
var label: Label

## Levels show (the Blacksmith is open: GameApp.blacksmith_unlocked()); false without the autoload (tests, tools).
static func shown() -> bool:
	var app := TdMenu.app()
	return app != null and app.has_method("blacksmith_unlocked") and bool(app.blacksmith_unlocked())

## A chip for a level ("Lv 3"); font_size 16 on portraits, larger beside big names.
static func make(lv: int, font_size := FONT_SIZE) -> TdLvChip:
	var c := TdLvChip.new()
	c.name = "LvChip"
	c.level = lv
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(font_size * 0.75))
	sb.content_margin_left = round(font_size * 0.45)
	sb.content_margin_right = round(font_size * 0.45)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	sb.anti_aliasing = true
	c.add_theme_stylebox_override("panel", sb)
	c.label = Label.new()
	c.label.text = UpgradeLogic.chip_text(lv)
	c.label.add_theme_font_override("font", TdTheme.font("plinth"))
	c.label.add_theme_font_size_override("font_size", font_size)
	c.label.add_theme_color_override("font_color", INK)
	c.label.mouse_filter = MOUSE_FILTER_IGNORE
	c.label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(c.label)
	c.size = c.get_combined_minimum_size()
	return c

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size_flags_horizontal = SIZE_SHRINK_BEGIN
	size_flags_vertical = SIZE_SHRINK_CENTER

## Updates the number.
func set_level(lv: int) -> void:
	level = lv
	if label != null: label.text = UpgradeLogic.chip_text(lv)
	size = get_combined_minimum_size()

## Puts a chip at the bottom-left of a portrait `diameter` px across (overlapping the ring like the mockup), replacing
## an old one; level <= 0 only removes it. at: where the chip's left-centre goes, in fractions of the diameter.
## Returns it (null for none).
static func attach(portrait: Control, lv: int, diameter: float, font_size := FONT_SIZE, at := Vector2(-0.06, 0.86)) -> TdLvChip:
	if portrait == null: return null
	var old := portrait.get_node_or_null("LvChip")
	if old != null:
		portrait.remove_child(old)
		old.queue_free()
	if lv <= 0: return null
	var c := make(lv, font_size)
	c.position = Vector2(diameter * at.x, diameter * at.y - c.size.y / 2.0).round()
	portrait.add_child(c)
	return c

## The picker's green ↑ "ready to upgrade" mark (mockup upgrade-picker: a green disc with a cream arrow and a dark
## rim at the tile's top-right), d px across.
static func ready_mark(d := 28.0) -> Control:
	var m := ReadyMark.new()
	m.name = "ReadyMark"
	m.custom_minimum_size = Vector2(d, d)
	m.size = m.custom_minimum_size
	return m

## A white five-point star (the Upgrade buttons' icon; the kit has none), rasterised once.
static func star_texture() -> Texture2D:
	if _star != null: return _star
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var pts := PackedVector2Array()
	var c := Vector2(n, n) / 2.0 + Vector2(0, 2)
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := n * 0.48 if i % 2 == 0 else n * 0.2
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for y in n:
		for x in n:
			var hits := 0
			for sx in 2:
				for sy in 2:
					if Geometry2D.is_point_in_polygon(Vector2(x + 0.25 + sx * 0.5, y + 0.25 + sy * 0.5), pts): hits += 1
			if hits > 0: img.set_pixel(x, y, Color(1, 1, 1, hits / 4.0))
	_star = ImageTexture.create_from_image(img)
	return _star

class ReadyMark extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := size.x / 2.0
		var c := Vector2(r, r)
		draw_circle(c, r, TdTheme.color("rim"))
		draw_circle(c, r - 2.0, Color("#2F8A45"))
		var cream := TdTheme.color("cream.100")
		var w := maxf(2.0, size.x * 0.1)
		draw_line(c + Vector2(0, r * 0.5), c + Vector2(0, -r * 0.45), cream, w, true)
		draw_polyline(PackedVector2Array([c + Vector2(-r * 0.38, -r * 0.06), c + Vector2(0, -r * 0.48), c + Vector2(r * 0.38, -r * 0.06)]), cream, w, true)
