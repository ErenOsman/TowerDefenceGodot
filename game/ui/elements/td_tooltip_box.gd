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
const PAD_TOP := 16.0
const PAD_RIGHT := 18.0
const PAD_BOTTOM := 14.0
const PAD_LEFT := 18.0
const HEADER_GAP := 6.0
const FOOTER_H := 40.0
const TAIL_INSET := 28.0  # the tail stays this far from the box's corners
const TAIL_TUCK := 6.0    # how far the tail reaches into the box (over its rim)

var _bg: Panel
var _header: RichTextLabel
var _body: RichTextLabel
var _footer: Control
var _footer_label: Label
var _footer_value: RichTextLabel
var _tail: TextureRect
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
	_tail = TextureRect.new()
	_tail.mouse_filter = MOUSE_FILTER_IGNORE
	_tail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tail.stretch_mode = TextureRect.STRETCH_SCALE
	_tail.visible = false
	add_child(_tail)

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

## Box width (clamped 300..420).
func set_box_width(w: float) -> void:
	_width = clampf(w, MIN_WIDTH, MAX_WIDTH)

## Fills the box and lays it out; its size is then final (read `size`).
func set_content(header: String, body: String, footer_label := "", footer_value := "") -> void:
	var inner_w := _width - PAD_LEFT - PAD_RIGHT
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
		_footer.size = Vector2(_width - 2, FOOTER_H)
		_footer_label.text = footer_label
		_footer_label.position = Vector2(PAD_LEFT - 1, 0)
		_footer_label.size = Vector2(inner_w * 0.55, FOOTER_H)
		_footer_value.text = "[right]%s[/right]" % footer_value
		_footer_value.position = Vector2(PAD_LEFT - 1 + inner_w * 0.35, 0)
		_footer_value.size = Vector2(inner_w * 0.65, 0)
		var vh := _footer_value.get_content_height()
		_footer_value.position.y = (FOOTER_H - vh) * 0.5
		y += FOOTER_H - 4
	size = Vector2(_width, ceilf(y))
	_bg.position = Vector2.ZERO
	_bg.size = size

## Shows the tail at the anchor's x (box-local), pointing down when the box is above its anchor (up: below);
## pointing = false hides it.
func set_tail(pointing: bool, down := true, anchor_x := 0.0) -> void:
	_tail.visible = pointing
	if not pointing: return
	var name := "tooltip_tail_down" if down else "tooltip_tail_up"
	_tail.texture = TdTheme.texture(name)
	var ts := TdTheme.sprite_size(name)
	_tail.size = ts
	var x := clampf(anchor_x, TAIL_INSET, maxf(TAIL_INSET, size.x - TAIL_INSET))
	_tail.position = Vector2(x - ts.x / 2.0, size.y - TAIL_TUCK if down else -ts.y + TAIL_TUCK)

## How far the tail sticks out of the box (for placement gaps).
func tail_length(down := true) -> float:
	return TdTheme.sprite_size("tooltip_tail_down" if down else "tooltip_tail_up").y - TAIL_TUCK
