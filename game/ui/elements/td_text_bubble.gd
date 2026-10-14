class_name TdTextBubble
extends Control
## A speech bubble with a tail (port of UI_TextBubble; the "pointing line" of UI Design Rules, Dialogue): a paper box
## (tooltip_paper, ~540 wide) with the speaker on a small cobalt plate (+ optional medallion portrait) in its top-left
## corner, Skip in the top-right, the line revealed letter by letter (BBCode), a hint row ("Goes on when …" left,
## "Click or Space" right once it waits for a click), and a tail pointing at the target. This control is the area
## the bubble moves in (make it full-rect over the screen); the box itself takes the clicks.
##   show_line(speaker, text, wait_for_click, portrait := null), set_hint(left, right := ""), point_at(point_or_null)
##   (canvas coordinates; above the target, or below when there is no room; null = centred near the bottom),
##   place_at_centre(), reveal_all(), hide_bubble(), is_fully_shown(), keep_inside; signals clicked, skip_clicked.
## The placement is re-applied every frame, so the box follows a moving target (call point_at again with its new point).

signal clicked
signal skip_clicked

@export var letters_per_second := 45.0
@export var box_width := 540.0
@export var gap := 48.0
@export var margin := 24.0
@export var bottom_offset := 230.0
## A bubble pointing at something stays inside the area; off: it follows its target off screen (always above).
@export var keep_inside := true
## The tail ends exactly on the target point (stretched when the box has to sit further away), and the box keeps
## clear of `avoid` (canvas rects: the target itself, unit heads and plates, previewed tiles): above or below the
## target, slid sideways, further away when it must. Off: the plain rule (above at `gap`, below when no room).
var tail_to_target := false
var avoid: Array = []
## tail_to_target: where the tail ends when the box sits below (canvas; e.g. the bottom edge of a ring whose top edge
## is the point), null = the same point.
var target_below = null
## How much further than its natural length the tail may stretch.
const MAX_TAIL_STRETCH := 240.0

enum Placement { NONE, POINT, CENTRE }

var _box: Panel
var _plate: Panel
var _name: Label
var _medal: TextureRect
var _medal_ring: TextureRect
var _medal_mask: TextureRect
var _text: RichTextLabel
var _hint_left: Label
var _hint_right: RichTextLabel
var _divider: ColorRect
var _skip: TdButton
var _tail: TextureRect
var _patch: ColorRect
var _letters := 0
var _revealed := 0.0
var _waits := false
var _placement := Placement.NONE
var _target = null
var _built := false

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	_box = Panel.new()
	_box.mouse_filter = MOUSE_FILTER_STOP
	_box.add_theme_stylebox_override("panel", TdTheme.stylebox("tooltip_paper"))
	_box.gui_input.connect(_on_box_input)
	_box.visible = false
	add_child(_box)
	var parts := TdTooltipBox.make_tail(_box)
	_patch = parts[0]
	_tail = parts[1]
	_plate = Panel.new()
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel", TdTheme.stylebox("tag_phase_player"))
	_box.add_child(_plate)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	TdTheme.apply_type(_name, "header", Color.WHITE, 24)
	_plate.add_child(_name)
	_medal_ring = TextureRect.new()
	_medal_ring.mouse_filter = MOUSE_FILTER_IGNORE
	_medal_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal_ring.texture = TdTheme.texture("medal_ring")
	_medal_ring.visible = false
	_box.add_child(_medal_ring)
	_medal_mask = TextureRect.new()
	_medal_mask.mouse_filter = MOUSE_FILTER_IGNORE
	_medal_mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal_mask.texture = TdTheme.texture("mask_circle")
	_medal_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_medal_ring.add_child(_medal_mask)
	_medal = TextureRect.new()
	_medal.mouse_filter = MOUSE_FILTER_IGNORE
	_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_medal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_medal_mask.add_child(_medal)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	TdTheme.apply_type(_text, "body", TdTheme.color("ink"))
	_text.add_theme_font_override("bold_font", TdTheme.font("nunito_extrabold"))
	_text.add_theme_constant_override("line_separation", 4)
	_box.add_child(_text)
	_divider = ColorRect.new()
	_divider.color = Color(TdTheme.color("ink.2"), 0.3)
	_divider.mouse_filter = MOUSE_FILTER_IGNORE
	_box.add_child(_divider)
	_hint_left = Label.new()
	_hint_left.mouse_filter = MOUSE_FILTER_IGNORE
	TdTheme.apply_type(_hint_left, "small", TdTheme.color("ink.2"))
	_box.add_child(_hint_left)
	_hint_right = RichTextLabel.new()
	_hint_right.bbcode_enabled = true
	_hint_right.fit_content = true
	_hint_right.scroll_active = false
	_hint_right.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_right.mouse_filter = MOUSE_FILTER_IGNORE
	TdTheme.apply_type(_hint_right, "small", TdTheme.color("ink.2"))
	_box.add_child(_hint_right)
	_skip = TdButton.new()
	_skip.style = TdButton.Style.SECONDARY
	_skip.custom_minimum_size = Vector2(124, 40)
	_skip.size = Vector2(124, 40)
	_skip.font_size = 20
	_skip.text = "Skip"
	_box.add_child(_skip)
	_skip.set_key_hint("Esc")
	_skip.fit_to_content(100)
	_skip.clicked.connect(func() -> void: skip_clicked.emit())

# ------------------------------------------------------------------ API

func is_fully_shown() -> bool:
	return _revealed >= _letters

func is_shown() -> bool:
	return _built and _box.visible

func show_line(speaker: String, line: String, wait_for_click := true, portrait: Texture2D = null) -> void:
	_build()
	_box.visible = true
	_name.text = speaker
	_plate.visible = speaker != ""
	_medal.texture = portrait
	_medal_ring.visible = portrait != null
	_text.text = line
	_text.visible_characters = 0
	_letters = _text.get_total_character_count()
	_revealed = 0.0
	_waits = wait_for_click
	if letters_per_second <= 0.0: reveal_all()
	_update_hint()
	_layout_box()
	_place()

## The hint row: left = how it goes on ("Goes on when a tower moves"), right = the click hint (BBCode; shown once the
## line is fully shown and waits for a click). Read key names from KeyBinds.
func set_hint(left: String, right := "") -> void:
	_build()
	_hint_left.text = left
	_hint_right.text = right
	_update_hint()
	_layout_box()

func set_skip_key(t: String) -> void:
	_build()
	_skip.set_key_hint(t)
	_skip.fit_to_content(100)
	_layout_box()

func set_skip_visible(v: bool) -> void:
	_build()
	_skip.visible = v

func reveal_all() -> void:
	_revealed = _letters
	if _text: _text.visible_characters = -1
	_update_hint()

func hide_bubble() -> void:
	_build()
	_placement = Placement.NONE
	_box.visible = false

func place_at_centre() -> void:
	_placement = Placement.CENTRE
	_place()

## Points the tail at a point (canvas coordinates) or null (centred near the bottom, no tail).
func point_at(point) -> void:
	_placement = Placement.POINT
	_target = point
	_place()

func box_rect() -> Rect2:
	return Rect2(_box.position + position, _box.size) if _built else Rect2()

# ------------------------------------------------------------------ internals

func _update_hint() -> void:
	if _hint_right: _hint_right.visible = _waits and is_fully_shown() and _hint_right.text != ""

func _layout_box() -> void:
	var w := box_width
	var top := 52.0 if _plate.visible else 18.0
	_plate.position = Vector2(14 + (44.0 if _medal_ring.visible else 0.0), -18)
	var nf: Font = TdTheme.font("plinth")
	_plate.size = Vector2(maxf(120.0, nf.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0), 44)
	_name.position = Vector2.ZERO
	_name.size = _plate.size - Vector2(0, 2)
	_medal_ring.position = Vector2(2, -30)
	_medal_ring.size = Vector2(60, 60)
	_medal_mask.position = Vector2(6, 6)
	_medal_mask.size = Vector2(48, 48)
	_medal.position = Vector2(-4, -2)
	_medal.size = Vector2(56, 56)
	_skip.position = Vector2(w - _skip.size.x - 14, 10)
	_text.position = Vector2(18, top)
	_text.size = Vector2(w - 36, 0)
	var th := _text.get_content_height()
	_text.size.y = th
	var y := top + th + 12.0
	var has_hint := _hint_left.text != "" or _hint_right.text != ""
	_divider.visible = has_hint
	if has_hint:
		_divider.position = Vector2(18, y)
		_divider.size = Vector2(w - 36, 2)
		y += 8.0
		_hint_left.position = Vector2(18, y)
		_hint_left.size = Vector2(w * 0.6, 28)
		_hint_right.size = Vector2.ZERO
		var hw := _hint_right.get_content_width()
		_hint_right.position = Vector2(w - 18 - hw, y + 1)
		_hint_right.size = Vector2(hw + 2, 28)
		y += 32.0
	_box.size = Vector2(w, y + 10.0)

func _place() -> void:
	if not _built or not _box.visible: return
	var r := Rect2(Vector2.ZERO, size)
	var bs := _box.size
	var centre: Vector2
	var has_target := _placement == Placement.POINT and _target is Vector2
	var target: Vector2 = (_target - global_position) if has_target else Vector2.ZERO
	var above := true
	if _placement == Placement.CENTRE:
		centre = r.get_center()
	elif not has_target:
		centre = Vector2(r.get_center().x, r.end.y - bottom_offset - bs.y / 2.0)
	elif tail_to_target:
		_place_avoiding(r, bs, target)
		return
	else:
		above = not keep_inside or target.y - gap - bs.y >= r.position.y + margin
		centre = Vector2(target.x, target.y - gap - bs.y / 2.0 if above else target.y + gap + bs.y / 2.0)
	if keep_inside or not has_target:
		centre.x = clampf(centre.x, r.position.x + margin + bs.x / 2.0, r.end.x - margin - bs.x / 2.0)
		centre.y = clampf(centre.y, r.position.y + margin + bs.y / 2.0, r.end.y - margin - bs.y / 2.0)
	_box.position = (centre - bs / 2.0).round()
	_tail.visible = has_target
	_patch.visible = has_target
	if has_target:
		TdTooltipBox.place_tail(_tail, _patch, bs, target.x - _box.position.x, above, TdTheme.color("paper.bottom"))

## tail_to_target: the place (above / below, slid, the tail stretched) that covers the least of `avoid` and spills
## nothing past the area; ties go to a short tail, the tail near the box's middle, above.
func _place_avoiding(r: Rect2, bs: Vector2, target: Vector2) -> void:
	var natural := TdTheme.sprite_size("tooltip_tail_down").y - TdTooltipBox.TAIL_TUCK - TdTooltipBox.TAIL_EMPTY
	var inner := r.grow(-margin)
	var keep := []
	for a in avoid: keep.append(Rect2(a.position - global_position, a.size))
	var inset := TdTooltipBox.TAIL_INSET
	var best := Vector2.ZERO
	var best_above := true
	var best_score := INF
	var below_target: Vector2 = (target_below - global_position) if target_below is Vector2 else target
	for above in [true, false]:
		var t: Vector2 = target if above else below_target
		for k in 13:
			var extra := k * MAX_TAIL_STRETCH / 12.0
			var y: float = t.y - natural - extra - bs.y if above else t.y + natural + extra
			for j in 9:
				var fx := 0.1 + j * 0.1
				var x: float = t.x - clampf(bs.x * fx, inset, bs.x - inset)
				var box := Rect2(x, y, bs.x, bs.y)
				var inside := box.intersection(inner).get_area() if box.intersects(inner) else 0.0
				var score := (box.get_area() - inside) * 50.0 + extra * 2.0 + absf(fx - 0.5) * 120.0 + (0.0 if above else 150.0)
				# the tail must not cross what is kept clear either (but what holds its tip — the target's own ring)
				var tail_r := Rect2(t.x - 8.0, y + bs.y, 16.0, t.y - y - bs.y) if above else Rect2(t.x - 8.0, t.y, 16.0, y - t.y)
				for a in keep:
					if box.intersects(a): score += box.intersection(a).get_area()
					if not a.grow(1.0).has_point(t) and tail_r.intersects(a): score += tail_r.intersection(a).get_area() * 3.0
				if score < best_score:
					best_score = score
					best = Vector2(x, y)
					best_above = above
	_box.position = best.round()
	if not best_above: target = below_target
	_tail.visible = true
	_patch.visible = true
	TdTooltipBox.place_tail(_tail, _patch, bs, target.x - _box.position.x, best_above, TdTheme.color("paper.bottom"))
	# stretch the tail so its tip lands on the target
	var ts := _tail.size
	var reach: float = (target.y - (_box.position.y + bs.y)) if best_above else (_box.position.y - target.y)
	var k2 := maxf(0.2, (reach + TdTooltipBox.TAIL_TUCK) / maxf(1.0, ts.y - TdTooltipBox.TAIL_EMPTY))
	_tail.size.y = roundf(ts.y * k2)
	_tail.position.y = roundf(bs.y - TdTooltipBox.TAIL_TUCK) if best_above else roundf(-_tail.size.y + TdTooltipBox.TAIL_TUCK)

func _process(delta: float) -> void:
	if not is_shown(): return
	if not is_fully_shown() and letters_per_second > 0.0:
		_revealed = minf(_letters, _revealed + letters_per_second * TdTheme.unscaled(delta))
		_text.visible_characters = int(floor(_revealed))
		if is_fully_shown(): _update_hint()
	if _placement != Placement.NONE: _place()

func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not is_fully_shown(): reveal_all()
		else: clicked.emit()
		_box.accept_event()
