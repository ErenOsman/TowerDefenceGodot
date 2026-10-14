class_name TdButton
extends Control
## The kit's button (port of UI_Button + UIFeedback + UIStateVisual + AbilityButtonView), drawn from the style B
## sprites: `style` picks the sprites per state and the label colours (TdTheme.control_style), the feedback profile
## picks how it answers the pointer (hover scale/lift, press scale/sink, denied shake). The control's rect is the
## logical size from the spec; rims, bands and glows hang outside it (sprite outsets).
##
## States: Normal / Hover / Pressed / Selected / Disabled, plus the style's extra states (Ability: "Aiming",
## "Cooldown", "Held"; EndTurn: "Attention"; NamePlate: "Picked", "Placed", "PlacedHover", "Locked", "Selected";
## Row: "Locked"). Priority: extra (its "<extra>Hover" while hovered), Disabled, Pressed, Selected, Hover, Normal.
## A disabled button still answers: hovering shows `denied_reason` (unless it has a TdTooltipTrigger), a click
## shakes it and shows the reason (signal denied). Left click only; all motion on unscaled time.
##
## API: set_label(text), set_icon(tex), set_key_hint(text), set_tag(text), interactable / set_interactable(v, reason),
## set_denied_reason(reason), selectable + selected / set_selected(v), set_extra_state(name), set_attention(on),
## simulate_click() (key shortcut), set_key_held(held), play_spawn_animation(), set_ability_state(left, total, held,
## aiming, key), set_passive(active), signals clicked, denied, hover_changed(hovered).

signal clicked
signal denied
signal hover_changed(hovered: bool)

enum Style { PRIMARY, SECONDARY, DANGER, ICON, ABILITY, END_TURN, NAME_PLATE, MENU_PRIMARY, MENU_WOOD, TAB, ROW }

const STYLE_NAMES := ["Primary", "Secondary", "Danger", "Icon", "Ability", "EndTurn", "NamePlate", "MenuPrimary", "MenuWood", "Tab", "Row"]
const PROFILES := ["Button", "Button", "Button", "IconButton", "Ability", "EndTurn", "HandPiece", "MenuButton", "MenuButton", "Button", "Button"]
## Default logical sizes (hud-menu-spec §2.3).
const SIZES := [Vector2(220, 60), Vector2(220, 60), Vector2(220, 60), Vector2(56, 56), Vector2(84, 84), Vector2(168, 168),
	Vector2(108, 28), Vector2(440, 64), Vector2(440, 64), Vector2(140, 56), Vector2(400, 60)]
## Label type role and size per style.
const LABEL_FONTS := [["plinth", 28], ["plinth", 28], ["plinth", 28], ["plinth", 18], ["plinth", 18], ["plinth", 30],
	["nunito_extrabold", 18], ["plinth", 28], ["plinth", 28], ["plinth", 26], ["plinth", 26]]
const H_PADDING := 28.0
const ICON_GAP := 12.0

@export var style: Style = Style.SECONDARY:
	set(v):
		style = v
		if is_node_ready(): _restyle()
@export var text := "":
	set(v):
		text = v
		if _label: _label.text = v; _layout()
@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready(): _apply_icon(); _layout()
## Icon after the label ("Start ▶").
@export var icon_after := false
## Where the icon + label (+ key badge) sit in text buttons: centred (default) or from a fixed left inset
## (`content_inset`; the pause menu's list). Ability / EndTurn / Icon / NamePlate keep their own layout.
@export var content_align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER:
	set(v):
		content_align = v
		if is_node_ready(): _layout()
## The left inset used when content_align is LEFT.
@export var content_inset := H_PADDING:
	set(v):
		content_inset = v
		if is_node_ready(): _layout()
@export var interactable := true:
	set = _set_interactable_prop
@export var selectable := false
@export var selected := false:
	set = _set_selected_prop
## 0: the style's default.
@export var font_size := 0:
	set(v):
		font_size = v
		if is_node_ready(): _restyle()
@export var spawn_animation := false
## Takes keyboard focus (menus): focus ring, Enter / Space clicks.
@export var keyboard_focus := false:
	set(v):
		keyboard_focus = v
		focus_mode = FOCUS_ALL if v else FOCUS_NONE
## Why it is disabled: shown on hover and on a denied click.
@export var denied_reason := ""
enum Bleed { AUTO, ON, OFF }
## Room for what grows past the face (sprite outsets, the selected ring, hover / press scale, the denied shake, the
## ability ring and badges, the focus ring) kept INSIDE the control, so a clipping parent (ScrollContainer, a panel
## with clip_contents) never cuts it. AUTO: on when the parent is a Container (lists, rows, menus, tabs), off when the
## button is placed by hand; ABILITY and END_TURN (HUD bars with fixed widths) only reserve it with ON. When on, the face keeps its logical size (custom_minimum_size) and sits inset
## by bleed(); the control's minimum size grows by it.
@export var bleed_mode: Bleed = Bleed.AUTO:
	set(v):
		bleed_mode = v
		if is_node_ready(): update_minimum_size(); _layout()

var hovered := false
var pressed := false

var _content: Control
var _glow: Control
var _face: TextureRect
var _bg: Panel
var _ring: TextureRect
var _icon: TextureRect
var _label: Label
var _key: Panel
var _key_label: Label
var _tag: Label
var _cd: TextureRect
var _cd_label: Label
var _cd_lock: TextureRect
var _focus: Panel
var _motion := TdMotion.new()
var _extra := ""
var _attention := false
var _held_key := false
var _tap_until := 0.0
var _showing_reason := false
var _cd_soon := false
var _clock := 0.0
var _built := false
var _face_origin := Vector2.ZERO

func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE

func _ready() -> void:
	_build()
	if spawn_animation: play_spawn_animation()

func _build() -> void:
	if _built: return
	_built = true
	if size == Vector2.ZERO and custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = SIZES[style]
		size = SIZES[style]
	_content = _ctl()
	add_child(_content)
	_glow = Panel.new(); _glow.mouse_filter = MOUSE_FILTER_IGNORE; _glow.modulate.a = 0.0
	_content.add_child(_glow)
	_face = _tex_rect(); _content.add_child(_face)
	_bg = Panel.new(); _bg.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(_bg)
	_ring = _tex_rect(); _content.add_child(_ring)
	_icon = _tex_rect(); _content.add_child(_icon)
	_label = Label.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text = text
	_content.add_child(_label)
	_key = Panel.new(); _key.mouse_filter = MOUSE_FILTER_IGNORE; _key.visible = false
	_key_label = Label.new(); _key_label.mouse_filter = MOUSE_FILTER_IGNORE
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.apply_type(_key_label, "micro", TdTheme.color("ink"))
	_key.add_child(_key_label)
	_content.add_child(_key)
	_tag = Label.new(); _tag.mouse_filter = MOUSE_FILTER_IGNORE; _tag.visible = false
	TdTheme.apply_type(_tag, "micro", TdTheme.color("cream.100"))
	_content.add_child(_tag)
	_cd = _tex_rect(); _cd.visible = false
	_cd_label = Label.new(); _cd_label.mouse_filter = MOUSE_FILTER_IGNORE
	_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.apply_type(_cd_label, "micro", TdTheme.color("cream.100"), 22)
	_cd.add_child(_cd_label)
	_cd_lock = _tex_rect(); _cd_lock.texture = TdTheme.texture("icon_lock"); _cd_lock.modulate = TdTheme.color("gold")
	_cd.add_child(_cd_lock)
	_content.add_child(_cd)
	_focus = Panel.new(); _focus.mouse_filter = MOUSE_FILTER_IGNORE; _focus.visible = false
	_focus.add_theme_stylebox_override("panel", TdTheme.stylebox("focus_ring_r14", TdTheme.color("accent")))
	_content.add_child(_focus)
	_motion.to(TdMotion.ALPHA, 1.0, 0.0)
	resized.connect(_layout)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_redraw)
	focus_exited.connect(_redraw)
	_restyle()

func _ctl() -> Control:
	var c := Control.new()
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c

func _tex_rect() -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r

# ------------------------------------------------------------------ public API

func style_name() -> String:
	return STYLE_NAMES[style]

func profile() -> Dictionary:
	return TdTheme.feedback(PROFILES[style])

func set_label(t: String) -> void:
	text = t

func get_label() -> String:
	return text

## The icon (Ability: the full-face picture; Icon: the glyph, tinted cream).
func set_icon(tex: Texture2D) -> void:
	icon = tex

func set_icon_visible(v: bool) -> void:
	_build()
	_icon.visible = v and icon != null and style != Style.ABILITY
	_face.visible = v and icon != null and style == Style.ABILITY

## A key badge ("Enter", "1", "Esc"): Ability top-left, EndTurn under the label, others after the label. "" hides it.
func set_key_hint(t: String) -> void:
	_build()
	_key.visible = t != ""
	_key_label.text = t
	_layout()

## A small tag at the bottom-right (icon buttons: "1x").
func set_tag(t: String) -> void:
	_build()
	_tag.visible = t != ""
	_tag.text = t
	_layout()

## Styles drawn with the UI rules' one Disabled look when not interactable (UI Design Rules § States: `ink.700` at
## 60 %, label `text.disabled`, no hover; the reason goes on a line near it and on hover), never a dimmed sprite.
const FLAT_DISABLED := [Style.PRIMARY, Style.SECONDARY, Style.DANGER, Style.MENU_PRIMARY, Style.MENU_WOOD, Style.TAB]
const DISABLED_LABEL := Color("#7A8296")
const INK_700 := Color("#262B3A")

## The Disabled fill (also used by look-alike disabled actions, e.g. TdTowerCard.disabled_button).
static func disabled_box(radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_700, 0.6) # no outline (UI Design Rules § States: Disabled)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb

## Enables or disables it; a disabled one still answers the pointer (reason on hover, shake on click).
func set_interactable(v: bool, reason = null) -> void:
	if v: denied_reason = ""
	elif reason != null: denied_reason = str(reason)
	interactable = v

func _set_interactable_prop(v: bool) -> void:
	var was := interactable
	interactable = v
	if not _built or was == v: return
	if v:
		pressed = false
		_hide_reason()
	elif hovered and TdTooltipTrigger.find_on(self) == null:
		_show_reason()
	_pose()
	_redraw()

func set_denied_reason(reason: String) -> void:
	denied_reason = reason

func set_selected(v: bool) -> void:
	selected = v

func _set_selected_prop(v: bool) -> void:
	selected = v
	if _built: _redraw()

## Is it shown selected (selectable and selected)?
func is_selected() -> bool:
	return selectable and selected

## One of the style's extra states ("Aiming", "Cooldown", "Held", "Picked", "Placed"…) or "" for none.
func set_extra_state(state: String) -> void:
	if _extra == state: return
	_extra = state
	if _built: _redraw()

func get_extra_state() -> String:
	return _extra

## Asks for attention (End turn when nothing is left to do, Start on Welcome): a slow breathe (scale 1.00..1.03,
## pulse.attention 1.6 s) and a glow pulse (alpha 0.35..0.9), plus the style's "Attention" sprite when it has one.
func set_attention(on: bool) -> void:
	if _attention == on: return
	_attention = on
	if not _built: return
	_motion.pulse(0.03 if on else 0.0, TdTheme.motion("pulse_attention"))
	if not on: _glow.modulate.a = 0.0
	_redraw()

func has_attention() -> bool:
	return _attention

## A click without the pointer (its key): the press motion and `clicked`; disabled: shake + reason (`denied`).
func simulate_click() -> void:
	_build()
	if not interactable:
		_deny()
		return
	_tap()
	clicked.emit()

## While its key is held the button shows pressed, like a held mouse button.
func set_key_held(held: bool) -> void:
	_build()
	_held_key = held and interactable
	_set_pressed(_held_key or (pressed and hovered))

## Pops in: from the profile's spawn scale and transparent to its rest look (motion.normal, ease lift).
func play_spawn_animation() -> void:
	_build()
	var p := profile()
	_motion.to(TdMotion.SCALE, p["spawn_scale"], 0.0)
	_motion.to(TdMotion.ALPHA, 0.0, 0.0)
	_motion.to(TdMotion.SCALE, 1.0, TdTheme.motion("normal"), "lift")
	_motion.to(TdMotion.ALPHA, 1.0, TdTheme.motion("normal"), "out")
	_apply_motion()

## Ability buttons (AbilityButtonView): the clock ring (one segment per turn, up to 3), the corner badge with the
## turns left (pulsing between cd_badge and cd_badge_soon when 1 is left) or a lock while held, the key badge, the
## face dimmed to 45 % while cooling, and the extra state (Aiming > Held > Cooldown).
func set_ability_state(left: int, total: int, held := false, aiming := false, key := "") -> void:
	_build()
	var cooling := not held and left > 0
	_ring.visible = true
	_ring.texture = TdTheme.texture(TdTheme.clock_ring_name(total, left, held))
	var badge := held or cooling
	_cd.visible = badge
	_cd_label.visible = cooling
	_cd_label.text = str(left)
	_cd_lock.visible = held
	_cd_soon = cooling and left == 1
	_cd.texture = TdTheme.texture("cd_badge")
	set_key_hint(key)
	_face.modulate = Color(1, 1, 1, 0.45 if badge else 1.0)
	# aimed (Eren 2026-10-14): the cooldown marks turn gold with the aiming rim (ability_overlay_aiming is already a
	# gold rim; the kit's clock ring and badge rim are blue, so they are recoloured, not swapped)
	var gold_mat: Material = gold_tint_material() if aiming else null
	_ring.material = gold_mat
	_cd.material = gold_mat
	set_extra_state("Aiming" if aiming else ("Held" if held else ("Cooldown" if cooling else "")))
	_layout()

## Is the clock ring drawn gold now (the ability is aimed)?
func ring_is_gold() -> bool:
	return _ring != null and _ring.material != null

static var _gold_tint: ShaderMaterial = null
const GOLD_TINT_SHADER := "shader_type canvas_item;
uniform vec4 gold : source_color;
void fragment() {
	vec4 c = COLOR; // texture x modulate
	// blue-dominant pixels (the kit's lit ring segments, the badge rim) take the gold token, keeping their light;
	// dark unlit segments and the wooden badge stay as they are
	float blue = clamp((c.b - max(c.r, c.g * 0.8)) * 2.5, 0.0, 1.0);
	float light = clamp(max(c.b, c.g) * 1.1, 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, gold.rgb * light, blue), c.a);
}"

## The shared material that recolours the kit's blue ring / badge rim to TdTheme gold.
static func gold_tint_material() -> ShaderMaterial:
	if _gold_tint == null:
		var sh := Shader.new()
		sh.code = GOLD_TINT_SHADER
		_gold_tint = ShaderMaterial.new()
		_gold_tint.shader = sh
		_gold_tint.set_shader_parameter("gold", TdTheme.color("gold"))
	return _gold_tint

## A passive on an ability button: only its face (no ring, badge or key), dimmed while its condition is off.
func set_passive(active: bool) -> void:
	_build()
	_ring.visible = false
	_cd.visible = false
	_cd_soon = false
	set_key_hint("")
	_face.modulate = Color(1, 1, 1, 1.0 if active else 0.45)
	set_extra_state("")

## The width its content needs (label + icon + key badge + padding 28 each side), at least min_width.
func content_width(min_width := 0.0) -> float:
	_build()
	var f: Font = _label.get_theme_font("font")
	var fs: int = _label.get_theme_font_size("font_size")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if text != "" else 0.0
	if icon != null and style != Style.ABILITY: w += 26.0 + (ICON_GAP if text != "" else 0.0)
	if _key.visible:
		w += 10.0 + maxf(24.0, TdTheme.font("plinth").get_string_size(_key_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 12.0)
	var pad := H_PADDING if size.y >= 52.0 else 18.0
	return maxf(min_width, ceilf(w + pad * 2.0))

## Sizes the button to its content (keeps the height).
func fit_to_content(min_width := 0.0) -> void:
	var w := content_width(min_width)
	custom_minimum_size.x = w
	size.x = w

## Shows a hover / pressed look without a pointer (kit demo, screenshots, tests).
func force_state(hover: bool, press: bool) -> void:
	_build()
	hovered = hover
	pressed = press and interactable
	_pose(true)
	_motion.snap()
	_redraw()
	_layout()
	_apply_motion()

# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if interactable:
				_set_pressed(true)
			accept_event()
		else:
			var inside := face_rect().has_point(event.position)
			var was := pressed
			_set_pressed(_held_key)
			if inside:
				if interactable and was:
					clicked.emit()
				elif not interactable:
					_deny()
			accept_event()
	elif keyboard_focus and event.is_action_pressed("ui_accept") and has_focus():
		simulate_click()
		accept_event()

func _on_mouse_entered() -> void:
	hovered = true
	if not interactable and TdTooltipTrigger.find_on(self) == null: _show_reason()
	_pose()
	_redraw()
	hover_changed.emit(true)

func _on_mouse_exited() -> void:
	hovered = false
	_set_pressed(_held_key)
	_hide_reason()
	_pose()
	_redraw()
	hover_changed.emit(false)

func _set_pressed(v: bool) -> void:
	if pressed == v: return
	pressed = v
	_pose()
	_redraw()
	_layout()

## The denied shake alone (no reason, no `denied`): the guided tutorial's refusal of a ringed button.
func shake() -> void:
	var p := profile()
	_motion.shake(p["denied_shake"], p["denied_time"])

func _deny() -> void:
	var p := profile()
	_motion.shake(p["denied_shake"], p["denied_time"])
	_show_reason()
	denied.emit()

func _tap() -> void:
	var p := profile()
	var t := TdTheme.motion("instant")
	_motion.to(TdMotion.SCALE, p["press_scale"], t)
	_tap_until = _clock + t
	_redraw()
	_layout()

func _show_reason() -> void:
	if denied_reason == "" or not is_inside_tree(): return
	# clear of what hangs outside the rect (ability ring and badge, end turn glow)
	var r := face_global_rect()
	var grow := 20.0 if style == Style.ABILITY else (8.0 if style == Style.END_TURN else 0.0)
	TdTooltip.show_beside(r.grow(grow), TdTooltipPlacement.Side.ABOVE_CENTRED, null, TooltipText.colored(TooltipText.harmful_color(), denied_reason))
	TdTooltip.own(self)
	_showing_reason = true

func _hide_reason() -> void:
	if not _showing_reason: return
	_showing_reason = false
	TdTooltip.hide(self)

# ------------------------------------------------------------------ look

func _process(delta: float) -> void:
	if not _built: return
	var dt := TdTheme.unscaled(delta)
	_clock += dt
	if _tap_until > 0.0 and _clock >= _tap_until:
		_tap_until = 0.0
		_pose()
		_redraw()
		_layout()
	_motion.step(dt)
	_apply_motion()
	if _attention:
		_glow.modulate.a = lerpf(0.35, 0.9, _motion.pulse_phase())
	if _cd_soon and _cd.visible:
		var soon := pingpong(_clock * 2.0 / TdTheme.motion("pulse_soon"), 1.0) > 0.5
		_cd.texture = TdTheme.texture("cd_badge_soon" if soon else "cd_badge")

func _apply_motion() -> void:
	_content.position = _face_origin + _motion.offset()
	_content.scale = Vector2.ONE * _motion.scale_value()
	_content.modulate.a = _motion.alpha

func _pose(instant := false) -> void:
	var p := profile()
	var hover := hovered and interactable
	var sc: float = p["press_scale"] * (p["hover_scale"] if hover else 1.0) if pressed else (p["hover_scale"] if hover else 1.0)
	var lift: float = (p["hover_lift"] if hover else 0.0)
	var t := 0.0 if instant else (TdTheme.motion("instant") if pressed else TdTheme.motion("quick"))
	_motion.to(TdMotion.SCALE, sc, t, "" if pressed else "lift")
	_motion.to(TdMotion.LIFT, lift, t, "" if pressed else "lift")

func _style() -> Dictionary:
	return TdTheme.control_style(STYLE_NAMES[style])

func _restyle() -> void:
	_build()
	var f: Array = LABEL_FONTS[style]
	_label.add_theme_font_override("font", TdTheme.font(f[0]))
	_label.add_theme_font_size_override("font_size", font_size if font_size > 0 else int(f[1]))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if style == Style.END_TURN else TextServer.AUTOWRAP_OFF
	if style == Style.END_TURN:
		_label.add_theme_constant_override("line_spacing", -6)
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if style == Style.NAME_PLATE else TextServer.OVERRUN_NO_TRIMMING
	var kb := "badge_key"
	_key.add_theme_stylebox_override("panel", TdTheme.stylebox(kb))
	if style == Style.END_TURN:
		_glow.add_theme_stylebox_override("panel", TdTheme.stylebox("endturn_glow", TdTheme.color("gold")))
	else:
		_glow.add_theme_stylebox_override("panel", TdTheme.stylebox("glow_r14", TdTheme.color("gold")))
	_face.visible = style == Style.ABILITY and icon != null
	_ring.visible = false
	_apply_icon()
	_redraw()
	_layout()

func _apply_icon() -> void:
	if style == Style.ABILITY:
		_face.texture = icon
		_face.visible = icon != null
		_icon.visible = false
	else:
		_icon.texture = icon
		_icon.visible = icon != null

func _sprite_now() -> String:
	var shown_pressed := pressed or _tap_until > 0.0
	var extra := _extra
	if _attention and _style().get("extra", {}).has("Attention"): extra = "Attention"
	return TdTheme.pick_sprite(_style(), hovered and interactable, shown_pressed and interactable, is_selected(), not interactable, extra)

func _redraw() -> void:
	if not _built: return
	var st := _style()
	var sprite := _sprite_now()
	if sprite != "":
		# the deep menu sprites' pressed variants draw a lighter side band ABOVE the sunk face (8 px rows in the PNG):
		# leave it out so the face simply sits 4 px lower under its rim
		var menu_pressed := (style == Style.MENU_PRIMARY or style == Style.MENU_WOOD) and sprite.ends_with("_pressed")
		_bg.add_theme_stylebox_override("panel", TdTheme.stylebox_cut_top(sprite, 8) if menu_pressed else TdTheme.stylebox(sprite))
	var flat_disabled := not interactable and style in FLAT_DISABLED
	if flat_disabled: _bg.add_theme_stylebox_override("panel", disabled_box())
	var col: Color = st.get("label", Color.WHITE) if interactable else st.get("label_disabled", TdTheme.color("cream.300"))
	if flat_disabled: col = DISABLED_LABEL
	if style == Style.END_TURN and not interactable: col = TdTheme.color("cream.300")
	_label.add_theme_color_override("font_color", col)
	if style == Style.ICON:
		_icon.modulate = TdTheme.color("gold") if is_selected() else (TdTheme.color("cream.100") if interactable else TdTheme.color("cream.300"))
	elif style != Style.ABILITY:
		_icon.modulate = col
	_focus.visible = keyboard_focus and has_focus()

func _sinks() -> bool:
	# the deep menu sprites draw their pressed face 4 px lower: the label and icon move with it
	return (style == Style.MENU_PRIMARY or style == Style.MENU_WOOD) and (pressed or _tap_until > 0.0) and interactable

func _layout() -> void:
	if not _built: return
	var fr := face_rect()
	_face_origin = fr.position
	var s := fr.size
	_content.size = s
	_content.pivot_offset = Vector2(0, s.y / 2.0) if (style == Style.MENU_PRIMARY or style == Style.MENU_WOOD) else s / 2.0
	_bg.position = Vector2.ZERO
	_bg.size = s
	_focus.position = Vector2(-1, -1) if style != Style.END_TURN else Vector2(-6, -6)
	_focus.size = s + (Vector2(2, 2) if style != Style.END_TURN else Vector2(12, 12))
	_glow.position = Vector2.ZERO
	_glow.size = s
	_face.position = Vector2.ZERO
	_face.size = s
	var ro := 17.0 * s.x / 84.0 # the ring's outset scales with the button
	_ring.position = Vector2(-ro, -ro)
	_ring.size = s + Vector2(ro, ro) * 2.0
	var sink := float(profile()["press_sink"]) if _sinks() else 0.0
	if style == Style.MENU_PRIMARY or style == Style.MENU_WOOD: sink = 4.0 if _sinks() else 0.0
	# key badge size
	var key_w := 0.0
	if _key.visible:
		var kf: Font = TdTheme.font("plinth")
		key_w = maxf(24.0, kf.get_string_size(_key_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 12.0)
		_key.size = Vector2(key_w, 24)
		_key_label.position = Vector2.ZERO
		_key_label.size = _key.size
	match style:
		Style.ABILITY:
			_label.visible = false
			_icon.visible = false
			_key.position = Vector2(-6, -6)
			var cd := 38.0
			_cd.size = Vector2(cd, cd) + Vector2(22, 22) # sprite outset 11 all round
			_cd.position = Vector2(s.x - cd / 2.0 + 4.0, -cd / 2.0 - 4.0) - Vector2(11, 11)
			_cd_label.position = Vector2(11, 9)
			_cd_label.size = Vector2(cd, cd)
			_cd_lock.position = Vector2(11 + 9, 11 + 9)
			_cd_lock.size = Vector2(20, 20)
		Style.END_TURN:
			_label.visible = text != ""
			_label.size = Vector2(s.x - 36, s.y * 0.5)
			var label_h := _label.get_minimum_size().y
			_label.size.y = label_h
			var total := label_h + (6.0 + 24.0 if _key.visible else 0.0)
			var y0 := (s.y - total) / 2.0
			_label.position = Vector2(18, y0 + sink)
			_key.position = Vector2((s.x - key_w) / 2.0, y0 + label_h + 6.0 + sink)
			_icon.visible = false
		Style.ICON:
			_label.visible = text != ""
			var isz := 26.0 if s.x >= 48.0 else 22.0
			_icon.size = Vector2(isz, isz)
			_icon.position = (s - _icon.size) / 2.0 + Vector2(0, sink)
			_label.position = Vector2.ZERO
			_label.size = s
			_tag.position = Vector2(s.x - _tag.get_minimum_size().x - 4, s.y - 22)
			_key.position = Vector2(s.x - key_w + 6, -6)
		_:
			_label.visible = text != ""
			var f: Font = _label.get_theme_font("font")
			var fs: int = _label.get_theme_font_size("font_size")
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if text != "" else 0.0
			var iw := 26.0 if icon != null and _icon.visible else 0.0
			if style == Style.NAME_PLATE: iw = 0.0
			var gap := ICON_GAP if iw > 0.0 and tw > 0.0 else 0.0
			var kgap := 10.0 if key_w > 0.0 else 0.0
			var total := tw + iw + gap + kgap + key_w
			var x := (s.x - total) / 2.0
			if content_align == HORIZONTAL_ALIGNMENT_LEFT: x = content_inset
			if style == Style.ROW: x = 16.0
			var lx := x + (0.0 if icon_after else iw + gap)
			var ix := x + tw + gap if icon_after else x
			_icon.size = Vector2(iw, iw)
			_icon.position = Vector2(ix, (s.y - iw) / 2.0 + sink)
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_label.position = Vector2(lx, sink)
			_label.size = Vector2(maxf(tw + 2.0, 1.0), s.y)
			if style == Style.NAME_PLATE:
				_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_label.position = Vector2(3, -1 + sink)
				_label.size = Vector2(s.x - 6, s.y)
			_key.position = Vector2(x + tw + iw + gap + kgap, (s.y - 24.0) / 2.0 + sink)
			_tag.position = Vector2(s.x - _tag.get_minimum_size().x - 6, s.y - 24)

func _get_minimum_size() -> Vector2:
	var b := bleed()
	return custom_minimum_size + Vector2(b.x + b.z, b.y + b.w) if (b.x + b.y + b.z + b.w) > 0.0 else Vector2.ZERO

## Is the bleed room reserved now (bleed_mode, or AUTO inside a Container)?
func bleed_active() -> bool:
	if bleed_mode == Bleed.ON: return true
	if bleed_mode == Bleed.OFF: return false
	if style == Style.ABILITY or style == Style.END_TURN: return false
	return get_parent() is Container

## The room kept around the face (left, top, right, bottom); zero when bleed is off.
func bleed() -> Vector4:
	if not bleed_active(): return Vector4.ZERO
	return bleed_for(style, custom_minimum_size if custom_minimum_size != Vector2.ZERO else SIZES[style], keyboard_focus)

## The room a style needs around a face of `face` size (left, top, right, bottom): the largest sprite outset of its
## states, hover / press / attention scale growth (menu buttons grow from their left edge), the denied shake, the
## focus ring, and for abilities the clock ring, key badge and cooldown badge.
static func bleed_for(st: int, face: Vector2, focus := false) -> Vector4:
	var style_d := TdTheme.control_style(STYLE_NAMES[st])
	var o := 0.0
	for k in ["normal", "hover", "pressed", "disabled", "selected"]:
		var n: String = style_d.get(k, "")
		if n != "": for v in TdTheme.sprite_outset(n): o = maxf(o, float(v))
	for n in style_d.get("extra", {}).values():
		for v in TdTheme.sprite_outset(n): o = maxf(o, float(v))
	var p := TdTheme.feedback(PROFILES[st])
	var grow := maxf(float(p["hover_scale"]), 1.0) * (1.03 if st == Style.END_TURN or st == Style.PRIMARY or st == Style.MENU_PRIMARY else 1.0) - 1.0
	var gx := grow * face.x / 2.0
	var gy := grow * face.y / 2.0
	var menu := st == Style.MENU_PRIMARY or st == Style.MENU_WOOD
	var shake := float(p["denied_shake"])
	var l := maxf(o, 0.0) + (0.0 if menu else gx) + shake
	var r := maxf(o, 0.0) + (gx * 2.0 if menu else gx) + shake
	var t := o + gy
	var b := o + gy
	if focus:
		l = maxf(l, 8.0); r = maxf(r, 8.0); t = maxf(t, 8.0); b = maxf(b, 8.0)
	if st == Style.ABILITY:
		var ro := 17.0 * face.x / 84.0
		l = maxf(l, maxf(ro, 6.0)) + shake; b = maxf(b, ro)
		t = maxf(t, 24.0); r = maxf(r, 24.0) + shake # the cooldown badge (38 round, centred 4 px out of the top-right corner)
	return Vector4(ceilf(l), ceilf(t), ceilf(r), ceilf(b))

## The node that holds the face (it moves, scales and shakes with the button's feedback). Add decorations here
## (a lock icon, a "new" dot) at face coordinates, so they stay on the face whatever the bleed room.
func face_node() -> Control:
	_build()
	return _content

## The face's rect in the control (inside the bleed room).
func face_rect() -> Rect2:
	var b := bleed()
	return Rect2(Vector2(b.x, b.y), size - Vector2(b.x + b.z, b.y + b.w))

## The face's rect in canvas coordinates (tooltips anchor to this, not to the bleed room).
func face_global_rect() -> Rect2:
	var r := face_rect()
	return Rect2(get_global_transform() * r.position, r.size * get_global_transform().get_scale())

func _has_point(point: Vector2) -> bool:
	return face_rect().has_point(point)

func _notification(what: int) -> void:
	# the bleed room depends only on the style, the face size, keyboard_focus and the parent kind (never on hover,
	# press, selection or focus state), so it is settled the moment the button gets a parent: the container lays it
	# out at its final size from the first frame
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_minimum_size()
		if _built: _layout()
