class_name TdHealthBar
extends Control
## A health bar (port of UI_HealthBar) from the kit's bar sprites: the fill eases to the new value (0.3 s), a ghost
## trails behind on damage (hp.ghost, waits 0.3 s then follows in 0.6 s) and runs ahead on a heal (fill catches up
## after 0.3 s); the fill colour steps by percent (hp.high > 60 % > hp.mid > 30 % > hp.low); optional numbers label
## ("20 / 20", above the bar's right end: the number never sits on the bar); optional preview stripes for a predicted
## hit or heal (set_preview). Variant INSPECTOR (hpbar_frame / _fill / _ghost, 14 tall) or PLATE (the board plate,
## hpbar_plate_*, 10 tall). Unscaled time.
##   set_health(current, max), set_health_immediate(current, max), set_preview(hp) (< 0 hides),
##   set_label_visible(visible, format := ""), get_fill_amount(), get_current_health(), get_max_health()

enum Variant { INSPECTOR, PLATE }

const FILL_TIME := 0.3
const GHOST_TIME := 0.6
const FILL_DELAY := 0.3
const GHOST_DELAY := 0.3

@export var variant: Variant = Variant.INSPECTOR:
	set(v):
		variant = v
		if is_node_ready(): _restyle()
@export var show_label := false
## {0} = current, {1} = max.
@export var label_format := "{0} / {1}"
## Text over the board: outlined numbers.
@export var outlined_label := false
## Unity's UI_HealthBar colours, opt-in (the board plates set them from the Unity plate prefab): a smooth
## gradient empty → half → full instead of the kit's steps, and the ghost colours. Defaults keep the kit look.
var unity_gradient := false
var full_color := Color(0.2, 0.85, 0.3)
var half_color := Color(0.95, 0.85, 0.15)
var empty_color := Color(0.9, 0.15, 0.15)
## Alpha 0 = the kit's token (hp.ghost / fx.heal at 55 %).
var ghost_damage_color := Color(0, 0, 0, 0)
var ghost_heal_color := Color(0, 0, 0, 0)

## UI_HealthBar.EvaluateGradient: half → full above 50 %, empty → half below.
static func gradient_for(t: float, empty: Color, half: Color, full_c: Color) -> Color:
	if t > 0.5: return half.lerp(full_c, (t - 0.5) * 2.0)
	return empty.lerp(half, t * 2.0)

var current_health := 1.0
var max_health := 1.0

var _frame: Panel
var _ghost_clip: Control
var _ghost: Panel
var _fill_clip: Control
var _fill: Panel
var _preview: TextureRect
var _label: Label
var _display := 1.0
var _ghost_v := 1.0
var _fill_from := 1.0
var _fill_to := 1.0
var _fill_t := 1.0      # < 0: waiting; >= FILL_TIME: done
var _ghost_from := 1.0
var _ghost_to := 1.0
var _ghost_t := 1.0
var _ghost_heal := false
var _has_value := false
var _preview_hp := -1.0
var _blink := 0.0
var _built := false

## The fill colour for a ratio (0..1): hp.high above 60 %, hp.mid above 30 %, else hp.low.
static func color_for(ratio: float) -> Color:
	if ratio > 0.6: return TdTheme.color("hp.high")
	if ratio > 0.3: return TdTheme.color("hp.mid")
	return TdTheme.color("hp.low")

## "{0} / {1}" with whole numbers shown without decimals.
static func format_label(fmt: String, current: float, maximum: float) -> String:
	return fmt.replace("{0}", _num(current)).replace("{1}", _num(maximum))

static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else "%.1f" % v

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	if size == Vector2.ZERO:
		size = Vector2(300, 14) if variant == Variant.INSPECTOR else Vector2(64, 10)
	_frame = _panel()
	_ghost_clip = _clip()
	_ghost = _panel(_ghost_clip)
	_fill_clip = _clip()
	_fill = _panel(_fill_clip)
	_preview = TextureRect.new()
	_preview.mouse_filter = MOUSE_FILTER_IGNORE
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_TILE
	_preview.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_preview.visible = false
	add_child(_preview)
	_label = Label.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_label)
	resized.connect(_layout)
	_restyle()

func _panel(parent: Node = self) -> Panel:
	var p := Panel.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _clip() -> Control:
	var c := Control.new()
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.clip_contents = true
	add_child(c)
	return c

func _restyle() -> void:
	_build()
	var plate: bool = variant == Variant.PLATE
	_frame.add_theme_stylebox_override("panel", TdTheme.stylebox("hpbar_plate_frame" if plate else "hpbar_frame"))
	_ghost.add_theme_stylebox_override("panel", TdTheme.stylebox("hpbar_plate_fill" if plate else "hpbar_ghost"))
	_fill.add_theme_stylebox_override("panel", TdTheme.stylebox("hpbar_plate_fill" if plate else "hpbar_fill"))
	TdTheme.apply_type(_label, "micro", TdTheme.color("cream.100"))
	if outlined_label or plate: TdTheme.outline(_label)
	_layout()

# ------------------------------------------------------------------ public API

func set_health(current: float, maximum: float) -> void:
	_build()
	if not _has_value or not is_inside_tree():
		set_health_immediate(current, maximum)
		return
	max_health = maxf(maximum, 0.01)
	current_health = clampf(current, 0.0, max_health)
	var target := current_health / max_health
	if is_equal_approx(target, _display) and is_equal_approx(target, _fill_to):
		pass
	elif target < _fill_to or target < _display:
		# damage: the fill eases down now, the ghost trails behind after a wait
		_ghost_heal = false
		_fill_from = _display; _fill_to = target; _fill_t = 0.0
		_ghost_from = _ghost_v; _ghost_to = target; _ghost_t = -GHOST_DELAY
	else:
		# heal: the ghost jumps ahead, the fill catches up after a wait
		_ghost_heal = true
		_ghost_v = target; _ghost_from = target; _ghost_to = target; _ghost_t = GHOST_TIME
		_fill_from = _display; _fill_to = target; _fill_t = -FILL_DELAY
	_update_label()
	_layout()

func set_health_immediate(current: float, maximum: float) -> void:
	_build()
	_has_value = true
	max_health = maxf(maximum, 0.01)
	current_health = clampf(current, 0.0, max_health)
	var f := current_health / max_health
	_display = f; _ghost_v = f
	_fill_from = f; _fill_to = f; _fill_t = FILL_TIME
	_ghost_from = f; _ghost_to = f; _ghost_t = GHOST_TIME
	_update_label()
	_layout()

## Shows the HP a previewed hit or heal would leave: the lost part striped red over the fill, the gained part
## striped green past it, blinking (blink.preview). Below 0 hides it.
func set_preview(hp: float) -> void:
	_build()
	_preview_hp = -1.0 if hp < 0.0 else clampf(hp, 0.0, max_health)
	_layout()

func set_label_visible(v: bool, fmt := "") -> void:
	_build()
	show_label = v
	if fmt != "": label_format = fmt
	_update_label()

func get_fill_amount() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0

func get_current_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

## The shown (animated) fill now, 0..1.
func get_display_fill() -> float:
	return _display

# ------------------------------------------------------------------ internals

func _update_label() -> void:
	_label.visible = show_label
	_label.text = format_label(label_format, current_health, max_health)

func _process(delta: float) -> void:
	if not _built: return
	var dt := TdTheme.unscaled(delta)
	var moved := false
	if _fill_t < FILL_TIME:
		_fill_t += dt
		var t := clampf(_fill_t / FILL_TIME, 0.0, 1.0)
		_display = lerpf(_fill_from, _fill_to, t * t * (3.0 - 2.0 * t))
		moved = true
	if _ghost_t < GHOST_TIME:
		_ghost_t += dt
		var t2 := clampf(_ghost_t / GHOST_TIME, 0.0, 1.0)
		_ghost_v = lerpf(_ghost_from, _ghost_to, t2 * t2 * (3.0 - 2.0 * t2))
		moved = true
	if _ghost_heal and _fill_t >= FILL_TIME:
		_ghost_v = _display
	if _preview.visible:
		_blink += dt
		_preview.modulate.a = lerpf(1.0, 0.45, pingpong(_blink * 2.0 / TdTheme.motion("blink_preview"), 1.0))
	if moved: _layout()

func _layout() -> void:
	if not _built: return
	var s := size
	_frame.position = Vector2.ZERO
	_frame.size = s
	var min_w := 16.0 if variant == Variant.INSPECTOR else 6.0
	_fill_clip.position = Vector2.ZERO
	_fill_clip.size = Vector2(s.x * clampf(_display, 0.0, 1.0), s.y)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(maxf(_fill_clip.size.x, min_w), s.y)
	var shown_fill := clampf(_fill_to if _fill_t >= FILL_TIME else _display, 0.0, 1.0)
	_fill.self_modulate = gradient_for(shown_fill, empty_color, half_color, full_color) if unity_gradient else color_for(shown_fill)
	var g := maxf(_ghost_v, _display)
	_ghost_clip.position = Vector2.ZERO
	_ghost_clip.size = Vector2(s.x * clampf(g, 0.0, 1.0), s.y)
	_ghost.position = Vector2.ZERO
	_ghost.size = Vector2(maxf(_ghost_clip.size.x, min_w), s.y)
	_ghost.visible = g > _display + 0.001
	if _ghost_heal: _ghost.self_modulate = ghost_heal_color if ghost_heal_color.a > 0.0 else Color(TdTheme.color("fx.heal"), 0.55)
	else: _ghost.self_modulate = ghost_damage_color if ghost_damage_color.a > 0.0 else TdTheme.color("hp.ghost")
	if _preview_hp >= 0.0 and max_health > 0.0:
		var now := current_health / max_health
		var then := _preview_hp / max_health
		_preview.visible = not is_equal_approx(now, then)
		var lo := minf(now, then)
		var hi := maxf(now, then)
		_preview.texture = TdTheme.texture("stripes_damage_preview" if then < now else "stripes_heal_preview")
		_preview.position = Vector2(s.x * lo, 0)
		_preview.size = Vector2(s.x * (hi - lo), s.y)
	else:
		_preview.visible = false
	_label.size = Vector2(maxf(s.x, 120.0), 24)
	_label.position = Vector2(s.x - _label.size.x, -_label.size.y - 2)
