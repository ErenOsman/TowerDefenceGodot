class_name TdTooltipBox
extends Control
## One paper tooltip box (hud-menu-spec §3 UI_TooltipBox): tooltip_paper 9-slice, padding 16 18 14 18, width 380
## (300..420), header (title Plinth 28 in its kind colour + grey subtitle, BBCode), body (Nunito Medium 22 ink,
## BBCode), an optional footer band (left label Nunito Bold 20 ink.2, right value), and an optional tail pointing at
## the anchor (tooltip_tail_down when the box is above it, _up when below). Never takes the mouse.
## Used by TdTooltip (one box) and TdTooltipStack (a column of boxes without footer or tail).

const WIDTH := 380.0
const MIN_WIDTH := 300.0
const MAX_WIDTH := 420.0
const FIT_MIN_WIDTH := 150.0 # the narrowest a short tooltip shrinks to
const PAD_TOP := 16.0
const PAD_RIGHT := 18.0
const PAD_BOTTOM := 14.0
const PAD_LEFT := 18.0
const HEADER_GAP := 6.0
const FOOTER_H := 40.0
const TAIL_INSET := 28.0  # the tail stays this far from the box's corners
## The tail's paper edge sits exactly on the inner edge of the box's rim (tooltip_paper: paper ends at the logical
## rect, 1 px rim, then 2 px transparent outset), so its first rows of paper cover the rim between its corners and its
## outline continues the rim; the rest protrudes. TAIL_TUCK = how far the sprite reaches inside the logical rect.
const TAIL_TUCK := 0.0
## The tail sprite's outline thickness at its top corners and the box rim's thickness (reference px).
const TAIL_OUTLINE := 3.5
const TAIL_RIM := 1.0
## tooltip_paper's light band just inside its top rim (sampled from the sprite).
const TOP_HIGHLIGHT := Color8(248, 240, 224)
## The tail sprites' transparent rows at the tip end (4 px in the 2x PNG).
const TAIL_EMPTY := 2.0

var _bg: Panel
var _header: RichTextLabel
var _body: RichTextLabel
var _footer: Control
var _footer_label: Label
var _footer_value: RichTextLabel
var _tail: TextureRect
var _patch: ColorRect
var _width := WIDTH

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_bg = Panel.new()
	_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_bg.add_theme_stylebox_override("panel", TdTheme.stylebox("tooltip_paper"))
	add_child(_bg)
	_header = _rich(TdTheme.font("plinth"), 28)
	_header.add_theme_font_override("bold_font", TdTheme.font("plinth"))
	add_child(_header)
	_body = _rich(TdTheme.font("nunito_medium"), 22)
	_body.add_theme_font_override("bold_font", TdTheme.font("nunito_extrabold"))
	add_child(_body)
	_footer = Panel.new()
	_footer.mouse_filter = MOUSE_FILTER_IGNORE
	var band := StyleBoxFlat.new()
	band.bg_color = TdTheme.color("paper.2")
	band.corner_radius_bottom_left = 12
	band.corner_radius_bottom_right = 12
	band.border_width_top = 2
	band.border_color = Color(TdTheme.color("ink.2"), 0.25)
	_footer.add_theme_stylebox_override("panel", band)
	add_child(_footer)
	_footer_label = Label.new()
	TdTheme.apply_type(_footer_label, "small", TdTheme.color("ink.2"))
	_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_child(_footer_label)
	_footer_value = _rich(TdTheme.font("nunito_bold"), 20)
	_footer_value.add_theme_font_override("bold_font", TdTheme.font("nunito_extrabold"))
	_footer_value.add_theme_color_override("default_color", TdTheme.color("gold.ink"))
	_footer.add_child(_footer_value)
	var parts := make_tail(self)
	_patch = parts[0]
	_tail = parts[1]

func _rich(f: Font, size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", f)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", TdTheme.color("ink"))
	r.add_theme_constant_override("line_separation", 2)
	return r

## The width of a text on one line in a rich label's font (bbcode tags stripped); 0 for an empty text.
func _line_width(r: RichTextLabel, text: String) -> float:
	if text == "": return 0.0
	var re := RegEx.new(); re.compile("\\[/?[a-zA-Z_=#\\. 0-9,-]*\\]")
	var plain := re.sub(text, "", true)
	var f: Font = r.get_theme_font("normal_font")
	var fs: int = r.get_theme_font_size("normal_font_size")
	var w := 0.0
	for line in plain.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w

## Box width (clamped 300..420).
func set_box_width(w: float) -> void:
	_width = clampf(w, MIN_WIDTH, MAX_WIDTH)

## Fills the box and lays it out; its size is then final (read `size`).
func set_content(header: String, body: String, footer_label := "", footer_value := "") -> void:
	# a short tooltip fits its text (Eren 2026-10-17: a one-liner in a 380 px box has "very open sides"); a footer
	# tooltip (stats) keeps the full width, and anything wider than the box wraps at the box width as before
	var box_w := _width
	if footer_label == "" and footer_value == "":
		var need := maxf(_line_width(_header, header), _line_width(_body, body))
		box_w = clampf(ceilf(need) + PAD_LEFT + PAD_RIGHT, FIT_MIN_WIDTH, _width)
	var inner_w := box_w - PAD_LEFT - PAD_RIGHT
	var y := PAD_TOP
	_header.visible = header != ""
	if _header.visible:
		_header.text = header
		_header.position = Vector2(PAD_LEFT, y)
		_header.size = Vector2(inner_w, 0)
		_header.reset_size()
		_header.size.x = inner_w
		var hh := _header.get_content_height()
		_header.size.y = hh
		y += hh + HEADER_GAP
	_body.visible = body != ""
	if _body.visible:
		_body.text = body
		_body.position = Vector2(PAD_LEFT, y)
		_body.size = Vector2(inner_w, 0)
		var bh := _body.get_content_height()
		_body.size.y = bh
		y += bh
	y += PAD_BOTTOM
	var has_footer := footer_label != "" or footer_value != ""
	_footer.visible = has_footer
	if has_footer:
		_footer.position = Vector2(1, y - 2)
		_footer.size = Vector2(_width - 2, FOOTER_H - 2) # ends at the rim's inner edge (never over the rim)
		_footer_label.text = footer_label
		_footer_label.position = Vector2(PAD_LEFT - 1, 0)
		_footer_label.size = Vector2(inner_w * 0.55, FOOTER_H)
		_footer_value.text = "[right]%s[/right]" % footer_value
		_footer_value.position = Vector2(PAD_LEFT - 1 + inner_w * 0.35, 0)
		_footer_value.size = Vector2(inner_w * 0.65, 0)
		var vh := _footer_value.get_content_height()
		_footer_value.position.y = (FOOTER_H - vh) * 0.5
		y += FOOTER_H - 4
	size = Vector2(box_w, ceilf(y))
	_bg.position = Vector2.ZERO
	_bg.size = size

## Shows the tail at the anchor's x (box-local), pointing down when the box is above its anchor (up: below);
## pointing = false hides it.
func set_tail(pointing: bool, down := true, anchor_x := 0.0) -> void:
	_tail.visible = pointing
	_patch.visible = pointing
	if not pointing: return
	# a down tail joins the bottom edge: the footer band's paper.2 when the band shows, else the plain paper bottom
	var edge := TdTheme.color("paper.2") if (down and _footer.visible) else TdTheme.color("paper.bottom")
	place_tail(_tail, _patch, size, anchor_x, down, edge)

## The tail's two nodes under a box (call once; add them after the box's other children): [patch ColorRect, tail].
static func make_tail(parent: Control) -> Array:
	var patch := ColorRect.new()
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.visible = false
	parent.add_child(patch)
	var tail := TextureRect.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tail.stretch_mode = TextureRect.STRETCH_SCALE
	tail.visible = false
	parent.add_child(tail)
	return [patch, tail]

## Places a tail on a paper box of box_size so box + tail read as one shape: the tail at anchor_x (clamped 28 px from
## the corners), whole pixels, its paper edge on the rim's inner edge; a patch in the joined edge's colour covers the
## rim between the tail's top corners (no half pixel of rim shows through the scaled sprite); the tail's paper is
## tinted to that edge colour (edge / the sprite's paper.bottom fill; the dark outline stays dark). Up tails always use
## TOP_HIGHLIGHT, the colour of tooltip_paper's top band.
static func place_tail(tail: TextureRect, patch: ColorRect, box_size: Vector2, anchor_x: float, down: bool, edge: Color) -> void:
	var name := "tooltip_tail_down" if down else "tooltip_tail_up"
	tail.texture = TdTheme.texture(name)
	var ts := TdTheme.sprite_size(name)
	tail.size = ts
	var x := roundf(clampf(anchor_x, TAIL_INSET, maxf(TAIL_INSET, box_size.x - TAIL_INSET)))
	tail.position = Vector2(roundf(x - ts.x / 2.0), roundf(box_size.y - TAIL_TUCK if down else -ts.y + TAIL_TUCK))
	var fill := TdTheme.color("paper.bottom") # the tail sprite's paper colour
	if not down: edge = TOP_HIGHLIGHT # an up tail joins the paper's light top band
	var tint := Color(edge.r / fill.r, edge.g / fill.g, edge.b / fill.b, 1.0) # may exceed 1: a lighter edge brightens the paper
	tail.self_modulate = tint
	patch.color = Color(fill.r * tint.r, fill.g * tint.g, fill.b * tint.b, 1.0)
	var pw := ts.x - 2.0 * TAIL_OUTLINE
	patch.size = Vector2(pw, TAIL_RIM + 1.0)
	patch.position = Vector2(roundf(x - pw / 2.0), box_size.y - 1.0 if down else -TAIL_RIM)

## How far the tail sticks out of the box (for placement gaps).
func tail_length(down := true) -> float:
	return TdTheme.sprite_size("tooltip_tail_down" if down else "tooltip_tail_up").y - TAIL_TUCK - TAIL_EMPTY
