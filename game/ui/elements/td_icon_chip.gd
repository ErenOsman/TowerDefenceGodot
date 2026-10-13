class_name TdIconChip
extends Control
## An icon chip (port of UI_IconPro + StatusChip). The kit's ability / status / passive icons already carry their chip
## (colour + shape: ability = rounded square, passive = double-rim, status = circle, buff = double-rim circle), so
## set_icon(full_icon) is the usual call; set_glyph(glyph, chip) composes a bare glyph on a chip sprite instead
## (default chip per shape). Optional caption under the chip (`set_label`).
##
## Badges (UI Design Rules, status chips): time left = a cream pill at the top-left corner (none when permanent),
## stacks = a dark pill at the bottom-right corner (hidden when empty), each centred on the chip's edge just inside
## its corner; round for one digit, growing equally both ways for more; 4+ digits read "1.2k". Sizes follow the chip:
## 32 -> pill 18 / number 14, 40 -> 22 / 16, 48 -> 24 / 18. Compact chips (badges false) show none.
##
## Animations (unscaled): hover bob + scale punch (not on status shapes: status chips are still, only their tooltip
## answers), pop-in (play_spawn_animation), activate pulse (play_activate_animation), value bump (the stacks pill and
## caption; automatic when the stacks number changes).

enum ChipShape { ABILITY, PASSIVE, STATUS, BUFF }

const DEFAULT_CHIPS := {
	ChipShape.ABILITY: "abilities/parts/chip_move",
	ChipShape.PASSIVE: "passives/parts/chip_defence",
	ChipShape.STATUS: "statuses/parts/chip_Unknown",
	ChipShape.BUFF: "statuses/parts/chip_Shield",
}

@export var chip_size := 40.0:
	set(v):
		chip_size = v
		if is_node_ready(): _layout()
@export var shape: ChipShape = ChipShape.STATUS:
	set(v):
		shape = v
		pointer_effects = shape == ChipShape.ABILITY or shape == ChipShape.PASSIVE
		if is_node_ready(): _layout()
## Hover bob / scale (off for statuses by default).
@export var pointer_effects := false
@export var badges := true
## Buff statuses carry their double rim in the icon art; true adds the separate outer ring to them too.
@export var outer_rim_on_buffs := false

var _content: Control
var _chip: TextureRect
var _icon: TextureRect
var _glow: Panel
var _rim_outer: Panel
var _rim_inner: Panel
var _time: Panel
var _time_label: Label
var _stack: Panel
var _stack_label: Label
var _caption: Label
var _hovered := false
var _bob_t := 0.0
var _anim := ""      # "spawn", "activate"
var _anim_t := 0.0
var _scale_anim := 1.0
var _hover_scale := 1.0
var _hover_target := 1.0
var _shake_x := 0.0
var _bump_t := -1.0
var _glow_a := 0.0
var _built := false

## A pill number: as is up to 3 digits, then one decimal + k (1250 -> "1.2k", 9999 -> "9.9k"), 10000+ -> "12k".
static func short_number(value: int) -> String:
	if value < 1000: return str(value)
	if value < 10000:
		return "%.1fk" % (floorf(value / 100.0) / 10.0)
	return "%dk" % int(floorf(value / 1000.0))

## Text for a pill: numbers shortened (short_number), other text as is.
static func badge_text(v) -> String:
	if v is int or v is float: return short_number(int(v))
	var s := str(v)
	return short_number(int(s)) if s.is_valid_int() else s

## Pill height and number size for a chip size (32 -> [18, 14], 40 -> [22, 16], 48 -> [24, 18]).
static func badge_metrics(chip: float) -> Array:
	var s := maxf(chip, 24.0)
	if s >= 46.0: return [24.0, 18]
	if s >= 38.0: return [22.0, 16]
	return [18.0, 14]

## The pill's width for its text width: round (= height) for one digit, else text + 0.55 x height.
static func pill_width(text_width: float, height: float) -> float:
	var w := text_width + height * 0.55
	return height if w < height * 1.15 else w

func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	_content = Control.new()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_content)
	_glow = Panel.new()
	_glow.mouse_filter = MOUSE_FILTER_IGNORE
	_glow.add_theme_stylebox_override("panel", TdTheme.stylebox("glow_r14", TdTheme.color("gold.light")))
	_glow.modulate.a = 0.0
	_content.add_child(_glow)
	# the passive's double rim (rule: passive = double-rim rounded square): a separate outer ring with a gap, so the
	# shape reads as "always on" even at 32 px where the icon's own thin second rim disappears
	_rim_outer = _ring(TdTheme.color("rim"))
	_rim_inner = _ring(TdTheme.color("cream.100"))
	_chip = _tr(); _chip.visible = false; _content.add_child(_chip)
	_icon = _tr(); _content.add_child(_icon)
	_time = _pill("status_time_pill", TdTheme.color("ink"), false)
	_time_label = _time.get_child(0)
	_stack = _pill("status_stack_pill", TdTheme.color("cream.100"), true)
	_stack_label = _stack.get_child(0)
	_caption = Label.new()
	_caption.mouse_filter = MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TdTheme.apply_type(_caption, "small")
	_caption.visible = false
	add_child(_caption)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	resized.connect(_layout)
	if size == Vector2.ZERO: size = Vector2(chip_size, chip_size)
	_layout()

func _on_enter() -> void:
	_hovered = true
	_hover_target = 1.05 if pointer_effects else 1.0

func _on_exit() -> void:
	_hovered = false
	_hover_target = 1.0

func _ring(col: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	_content.add_child(p)
	return p

## Whether the chip draws the separate outer rim (passives; BUFF only with outer_rim_on_buffs).
func has_outer_rim() -> bool:
	return shape == ChipShape.PASSIVE or (shape == ChipShape.BUFF and outer_rim_on_buffs)

func _tr() -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r

func _pill(sprite: String, col: Color, outlined: bool) -> Panel:
	var p := Panel.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", TdTheme.stylebox(sprite))
	p.visible = false
	var l := Label.new()
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	l.add_theme_color_override("font_color", col)
	if outlined:
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_color_override("font_outline_color", TdTheme.color("wood.900"))
	p.add_child(l)
	_content.add_child(p)
	return p

# ------------------------------------------------------------------ public API

## The full icon (chip baked in, e.g. res://art/icons/Statuses/Burn.png or TdTheme.kit("abilities/Shoot")).
func set_icon(tex: Texture2D) -> void:
	_build()
	_icon.texture = tex
	_chip.visible = false
	_icon_inset = 0.0
	_layout()

var _icon_inset := 0.0

## A bare glyph on a chip sprite (null: the shape's default chip). The glyph sits at 64 % of the chip.
func set_glyph(glyph: Texture2D, chip: Texture2D = null) -> void:
	_build()
	_chip.texture = chip if chip != null else TdTheme.kit(DEFAULT_CHIPS[shape])
	_chip.visible = true
	_icon.texture = glyph
	_icon_inset = 0.18
	_layout()

func get_icon() -> Texture2D:
	return _icon.texture if _built else null

## A caption under the chip ("" hides it); a changed caption bumps.
func set_label(t: String) -> void:
	_build()
	var changed := _caption.text != t and _caption.text != ""
	_caption.text = t
	_caption.visible = t != ""
	_layout()
	if changed: play_value_bump()

func get_label() -> String:
	return _caption.text if _built else ""

func set_label_with_bump(t: String) -> void:
	set_label(t)

## The status badges: turns_left < 0 = permanent (no time pill); stacks shown when > 1, or > 0 with always_stacks
## (Shield: the points it still absorbs). A changed stacks number bumps.
func set_status(turns_left: int, stacks := 0, always_stacks := false) -> void:
	set_time_badge(str(turns_left) if turns_left >= 0 else "")
	set_stack_badge(str(stacks) if (stacks > 1 or (always_stacks and stacks > 0)) else "")

## The time pill text ("" hides it); numbers shortened.
func set_time_badge(t: String) -> void:
	_build()
	_set_pill(_time, _time_label, t)

## The stacks pill text ("" hides it); numbers shortened; a change bumps.
func set_stack_badge(t: String) -> void:
	_build()
	var before := _stack_label.text if _stack.visible else ""
	_set_pill(_stack, _stack_label, t)
	if _stack.visible and before != "" and before != _stack_label.text: play_value_bump()

func time_badge_text() -> String:
	return _time_label.text if _built and _time.visible else ""

func stack_badge_text() -> String:
	return _stack_label.text if _built and _stack.visible else ""

func set_badges_visible(v: bool) -> void:
	badges = v
	_layout()

func set_pointer_effects(on: bool) -> void:
	pointer_effects = on

## Pop in: 0.3 -> 1.25 (ease out) -> 1 over 0.3 s, with a glow flash.
func play_spawn_animation() -> void:
	_build()
	_anim = "spawn"
	_anim_t = 0.0
	_scale_anim = 0.3
	_apply()

## The effect fired (a poison tick, a buff triggering): punch to 1.15 with a small shake and a glow flash, 0.25 s.
func play_activate_animation() -> void:
	_build()
	_anim = "activate"
	_anim_t = 0.0

## The value changed: the stacks pill (and caption) scale to 1.3 and back over 0.2 s.
func play_value_bump() -> void:
	_bump_t = 0.0

func is_animation_locked() -> bool:
	return _anim != ""

# ------------------------------------------------------------------ internals

func _set_pill(p: Panel, l: Label, t: String) -> void:
	var txt := badge_text(t) if t != "" else ""
	l.text = txt
	p.visible = txt != "" and badges
	_layout()

func _layout() -> void:
	if not _built: return
	var s := Vector2(chip_size, chip_size)
	if size.x < s.x or size.y < s.y: size = s
	custom_minimum_size = s + (Vector2(0, 26) if _caption.visible else Vector2.ZERO)
	_content.size = s
	_content.pivot_offset = s / 2.0
	var rim := has_outer_rim()
	var rim_w := maxf(1.5, chip_size / 24.0)   # 2 px at 48, 1.5 at 32
	var gap := maxf(1.5, chip_size / 24.0)
	var outer := rim_w * 2.0 + gap             # rim + cream + gap before the icon
	var base := Vector2.ONE * (outer if rim else 0.0)
	var inner_s := s - base * 2.0
	var inset := inner_s * _icon_inset
	_icon.position = base + inset
	_icon.size = inner_s - inset * 2.0
	_chip.position = base
	_chip.size = inner_s
	_rim_outer.visible = rim
	_rim_inner.visible = rim
	if rim:
		var circle := shape == ChipShape.BUFF
		var radius := int(chip_size / 2.0) if circle else int(round(chip_size * 0.27))
		for pair in [[_rim_outer, 0.0, rim_w * 2.0], [_rim_inner, rim_w * 0.5, rim_w]]:
			var p: Panel = pair[0]
			var o: float = pair[1]
			var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
			sb.set_border_width_all(int(ceil(pair[2])))
			sb.set_corner_radius_all(maxi(1, radius - int(o)))
			p.position = Vector2(o, o)
			p.size = s - Vector2(o, o) * 2.0
	_glow.position = Vector2.ZERO
	_glow.size = s
	var m := badge_metrics(chip_size)
	var h: float = m[0]
	var fs: int = m[1]
	for pair in [[_time, _time_label, true], [_stack, _stack_label, false]]:
		var p: Panel = pair[0]
		var l: Label = pair[1]
		p.visible = l.text != "" and badges
		l.add_theme_font_size_override("font_size", fs)
		var tw := TdTheme.font("plinth").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := pill_width(tw, h)
		var centre := h * 0.4 # centred on the chip edge, just inside its corner; wider pills grow both ways around it
		var c := Vector2(centre, 0.0) if pair[2] else Vector2(s.x - centre, s.y)
		p.size = Vector2(w, h)
		p.position = (c - p.size / 2.0).round()
		p.pivot_offset = p.size / 2.0
		l.position = Vector2(0, -1)
		l.size = p.size
	_caption.position = Vector2(-20, s.y + 2)
	_caption.size = Vector2(s.x + 40, 24)
	_caption.pivot_offset = _caption.size / 2.0

func _process(delta: float) -> void:
	if not _built: return
	var dt := TdTheme.unscaled(delta)
	var moving := false
	# hover scale punch + bob
	_hover_scale = move_toward(_hover_scale, _hover_target, dt / 0.15 * 0.08)
	var bob := 0.0
	if _hovered and pointer_effects:
		_bob_t += dt * 2.5
		bob = sin(_bob_t * TAU) * 4.0
		moving = true
	else:
		_bob_t = 0.0
	_shake_x = 0.0
	if _anim == "spawn":
		_anim_t += dt
		var d := 0.3
		if _anim_t < d * 0.6:
			var t := _anim_t / (d * 0.6)
			_scale_anim = lerpf(0.3, 1.25, 1.0 - (1.0 - t) * (1.0 - t))
		elif _anim_t < d:
			var t2 := (_anim_t - d * 0.6) / (d * 0.4)
			_scale_anim = lerpf(1.25, 1.0, t2 * t2 * (3.0 - 2.0 * t2))
			_glow_a = 0.6 * (1.0 - t2)
		else:
			_scale_anim = 1.0
			_anim = ""
			_glow_a = 0.0
		moving = true
	elif _anim == "activate":
		_anim_t += dt
		var d2 := 0.25
		var t3 := clampf(_anim_t / d2, 0.0, 1.0)
		_scale_anim = 1.0 + 0.15 * sin(t3 * PI)
		_shake_x = sin(t3 * 6.0 * PI) * 3.0 * (1.0 - t3)
		_glow_a = 0.6 * (1.0 - t3)
		if t3 >= 1.0:
			_anim = ""
			_scale_anim = 1.0
			_glow_a = 0.0
		moving = true
	var bump := 1.0
	if _bump_t >= 0.0:
		_bump_t += dt
		var t4 := clampf(_bump_t / 0.2, 0.0, 1.0)
		bump = 1.0 + 0.3 * sin(t4 * PI)
		if t4 >= 1.0: _bump_t = -1.0
		moving = true
	_stack.scale = Vector2.ONE * bump
	_caption.scale = Vector2.ONE * bump
	_content.position = Vector2(_shake_x, bob)
	_content.scale = Vector2.ONE * (_scale_anim * _hover_scale)
	_glow.modulate.a = _glow_a
	if not moving and is_equal_approx(_hover_scale, _hover_target): return

func _apply() -> void:
	_content.scale = Vector2.ONE * _scale_anim
