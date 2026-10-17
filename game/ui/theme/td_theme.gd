class_name TdTheme
extends RefCounted
## The one place the UI's look is read from (style B "Painted Diorama"; hud-menu-spec.md §2, UI Design Rules):
## colour tokens, the type scale, kit sprites as 9-slice StyleBoxes, motion durations and curves, feedback profiles
## and control styles. Values come from TdTokens, generated from res://data/content/UITheme.json (the Unity theme)
## and the kit's slices.json by tools/build_theme.gd; the Godot Theme resource for built-in controls is
## res://game/ui/theme/td_theme.tres (TdTheme.theme()).
##
##   TdTheme.color("accent"), TdTheme.color("wood.900") == TdTheme.color("wood_900") == TdTokens.WOOD_900
##   TdTheme.font("display"), TdTheme.font_size("display") -> 64, TdTheme.apply_type(label, "body")
##   TdTheme.stylebox("btn_primary_normal"), TdTheme.texture("icon_pause"), TdTheme.kit("abilities/Shoot")
##   TdTheme.motion("quick") -> 0.18, TdTheme.eased("lift", t), TdTheme.tween(node) (unscaled time)
##   TdTheme.feedback("Button"), TdTheme.control_style("Primary")
## All UI motion uses unscaled time: TdTheme.tween(node) ignores Engine.time_scale, TdTheme.unscaled(delta) in _process.
## Fonts: Nunito/Plinth lack symbols (✓ → ● ▲ ⓘ ⧗ ✕ ⚠ …) and the web build has no system fallback, so every font's
## import settings (art/fonts/*.ttf.import `fallbacks`) chain DejaVuSans-Bold-TdSubset + NotoSansSymbols-TdSubset;
## anything loading those .ttf files gets them (tests/test_ui_theme_glyphs.gd). New fonts: add the same fallbacks.
## Godot takes a font's ascent / descent as the MAX over its fallback chain, so the two subset fonts carry small
## vertical metrics (hhea + OS/2: ascent 0.90 em, descent 0.20 em, under Nunito's and Plinth's): with their original
## metrics (NotoSansSymbols 1.48 + 0.63 em) every 22 px label was 47 px tall instead of 31 (menus QA 2026-10-15).
## A re-subset must set them again (fontTools: hhea.ascent/descent, OS/2 sTypo* and usWin*).

const THEME_PATH := "res://game/ui/theme/td_theme.tres"
const KIT_ROOT := "res://art/ui/KitB/"
## "base » now" in stat rows (see TooltipText.changed); the look, kept now that "→" draws from the fallback font.
const ARROW := "»"
## Sprites are 2x the 1920x1080 reference.
const SPRITE_SCALE := 0.5

static var _colors_norm: Dictionary = {}
static var _fonts: Dictionary = {}
static var _boxes: Dictionary = {}
static var _textures: Dictionary = {}
static var _theme: Theme
static var _rt_frame := -1
static var _rt_last := 0
static var _rt_dt := 0.0

# ------------------------------------------------------------------ colours

## Lowercase with dots, underscores, dashes and spaces dropped: "wood.900", "wood_900", "Wood900" -> "wood900".
static func normalize_token(name: String) -> String:
	return name.to_lower().replace(".", "").replace("_", "").replace("-", "").replace(" ", "")

static func has_color(name: String) -> bool:
	_index_colors()
	return _colors_norm.has(normalize_token(name))

## A colour token by name (spec names: "wood.900", "accent.fill", "gold.ink", "hp.high", "scrim"…; underscores work too).
## Unknown names warn and give magenta.
static func color(name: String) -> Color:
	_index_colors()
	var k := normalize_token(name)
	if _colors_norm.has(k):
		return _colors_norm[k]
	push_warning("TdTheme: unknown colour token '%s'" % name)
	return Color.MAGENTA

## The token as "#rrggbb" (or "#rrggbbaa") for BBCode.
static func rich(name: String) -> String:
	return hex(color(name))

static func hex(c: Color) -> String:
	return "#" + c.to_html(c.a < 0.999)

## Every token name (spec spelling).
static func color_names() -> Array:
	return TdTokens.COLORS.keys()

static func _index_colors() -> void:
	if not _colors_norm.is_empty(): return
	for n in TdTokens.COLORS:
		_colors_norm[normalize_token(n)] = TdTokens.COLORS[n]

# ------------------------------------------------------------------ type

## The font of a type role ("display", "plaque_title", "h1", "h2", "h3", "header", "button", "body", "small", "micro",
## "plate") or of a family key ("plinth", "nunito_medium", "nunito_bold", "nunito_extrabold", "nunito_regular").
## Sizes are separate in Godot: font_size(role) / apply_type().
static func font(role_or_family: String, _size := 0) -> Font:
	var key := role_or_family
	if TdTokens.TYPE.has(role_or_family):
		key = TdTokens.TYPE[role_or_family]["font"]
	elif not TdTokens.FONT_FILES.has(key):
		key = {"display": "plinth", "nunito": "nunito_medium"}.get(key, "nunito_medium")
	if not _fonts.has(key):
		_fonts[key] = load(TdTokens.FONT_FILES[key])
	return _fonts[key]

## The role's size at the 1920x1080 reference (never under TdTokens.MIN_FONT_SIZE except where the spec says so).
static func font_size(role: String) -> int:
	return int(TdTokens.TYPE[role]["size"]) if TdTokens.TYPE.has(role) else 22

## The role's default colour.
static func type_color(role: String) -> Color:
	return TdTokens.TYPE[role]["color"] if TdTokens.TYPE.has(role) else color("cream.200")

static func has_type(role: String) -> bool:
	return TdTokens.TYPE.has(role)

## Puts a type role on a Label / RichTextLabel / Button / LineEdit: font, size (size > 0 overrides) and colour
## (a colour with alpha 0 keeps the role's).
static func apply_type(c: Control, role: String, col := Color(0, 0, 0, 0), size := 0) -> void:
	var f := font(role)
	var s := size if size > 0 else font_size(role)
	var colr := col if col.a > 0.0 else type_color(role)
	if c is RichTextLabel:
		c.add_theme_font_override("normal_font", f)
		c.add_theme_font_size_override("normal_font_size", s)
		c.add_theme_font_size_override("bold_font_size", s)
		c.add_theme_color_override("default_color", colr)
	else:
		c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", s)
		c.add_theme_color_override("font_color", colr)

## A Label in a type role (convenience for code-built screens).
static func label(text: String, role := "body", col := Color(0, 0, 0, 0), size := 0) -> Label:
	var l := Label.new()
	l.text = text
	apply_type(l, role, col, size)
	return l

## Text over the board gets an outline (UI rules: 0.2 at rim 80 %).
static func outline(c: Control, px := 6) -> void:
	c.add_theme_constant_override("outline_size", px)
	c.add_theme_color_override("font_outline_color", Color(color("rim"), 0.8))

# ------------------------------------------------------------------ sprites

static func has_sprite(name: String) -> bool:
	return TdTokens.SPRITES.has(name)

## A kit sprite's texture by its kit name ("btn_primary_normal", "icon_pause", "cd_badge"…).
static func texture(name: String) -> Texture2D:
	if not TdTokens.SPRITES.has(name):
		push_warning("TdTheme: unknown kit sprite '%s'" % name)
		return null
	var path: String = TdTokens.SPRITES[name][0]
	return _load_tex(path)

## Any kit PNG by its path under res://art/ui/KitB without ".png" ("abilities/Shoot", "statuses/Burn",
## "abilities_face/Shoot", "statuses/parts/chip_Burn"); null when missing.
static func kit(rel: String) -> Texture2D:
	var path := KIT_ROOT + rel + ".png"
	if not ResourceLoader.exists(path): return null
	return _load_tex(path)

static func _load_tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

## The sprite's size at the reference (PNG px / 2), outsets included.
static func sprite_size(name: String) -> Vector2:
	if not TdTokens.SPRITES.has(name): return Vector2.ZERO
	var d: Array = TdTokens.SPRITES[name]
	return Vector2(d[1], d[2]) * SPRITE_SCALE

## The 9-slice border in PNG px [l, t, r, b].
static func sprite_border(name: String) -> Array:
	return TdTokens.SPRITES[name][3] if TdTokens.SPRITES.has(name) else [0, 0, 0, 0]

## How far the sprite reaches past its control's rect, reference px [l, t, r, b].
static func sprite_outset(name: String) -> Array:
	return TdTokens.SPRITES[name][4] if TdTokens.SPRITES.has(name) else [0.0, 0.0, 0.0, 0.0]

## The sprite's logical size (what the control's rect should be): reference size minus outsets.
static func logical_size(name: String) -> Vector2:
	var o := sprite_outset(name)
	return sprite_size(name) - Vector2(o[0] + o[2], o[1] + o[3])

## A 9-slice StyleBox (TdSliceBox) for a kit sprite, drawn at reference size with its outset; cached per sprite, tint
## and padding. padding = [l, t, r, b] content margins (reference px), or empty for none.
static func stylebox(name: String, tint := Color.WHITE, padding: Array = []) -> StyleBox:
	var key := "%s|%s|%s" % [name, tint.to_html(), str(padding)]
	if _boxes.has(key):
		return _boxes[key]
	var box: StyleBox
	if not TdTokens.SPRITES.has(name):
		push_warning("TdTheme: unknown kit sprite '%s'" % name)
		box = StyleBoxEmpty.new()
	else:
		var d: Array = TdTokens.SPRITES[name]
		var b := TdSliceBox.new()
		b.texture = _load_tex(d[0])
		b.set_border(d[3][0], d[3][1], d[3][2], d[3][3])
		b.set_outset(d[4][0], d[4][1], d[4][2], d[4][3])
		b.modulate_color = tint
		if padding.size() == 4:
			b.set_padding(padding[0], padding[1], padding[2], padding[3])
		box = b
	_boxes[key] = box
	return box

## The deep menu buttons are a face block with a thick band under it (the side of the plinth). For the pressed "sink"
## the two are drawn as separate layers: the face block (the sprite without its bottom `band_px` texture rows, so it
## ends at the face's own dark outline) moves; the band (the bottom outset rows) stays put and the face covers it.
static func stylebox_face(name: String, band_px: int) -> StyleBox:
	var key := "%s|face%d" % [name, band_px]
	if _boxes.has(key): return _boxes[key]
	var base := stylebox(name)
	if not (base is TdSliceBox): return base
	var b: TdSliceBox = base.duplicate()
	var ts := b.texture.get_size()
	b.region = Rect2(0, 0, ts.x, ts.y - band_px)
	b.border_bottom = maxi(0, b.border_bottom - band_px)
	b.outset_bottom = b.outset_bottom - band_px * SPRITE_SCALE
	_boxes[key] = b
	return b

## The band layer of stylebox_face(): the sprite's bottom outset rows only, drawn in a rect exactly the outset tall
## placed under the control's logical rect.
static func stylebox_band(name: String) -> StyleBox:
	var key := "%s|band" % name
	if _boxes.has(key): return _boxes[key]
	var base := stylebox(name)
	if not (base is TdSliceBox): return base
	var b: TdSliceBox = base.duplicate()
	var ts := b.texture.get_size()
	var rows := int(round(b.outset_bottom / SPRITE_SCALE))
	b.region = Rect2(0, ts.y - rows, ts.x, rows)
	b.border_top = 0
	b.border_bottom = rows
	b.outset_top = 0.0
	b.outset_bottom = 0.0
	_boxes[key] = b
	return b

## An ability's icon with its chip and dark rim (kit abilities/<Name>), for rows, lists and tooltips: the Codex, Info
## and inspector rows. (ability_face() is the bare full-face picture for under the action bar's overlay frame.)
static func ability_icon(icon_name: String) -> Texture2D:
	var t := kit("abilities/" + icon_name)
	if t != null: return t
	var p := "res://art/icons/Abilities/%s.png" % icon_name
	return load(p) if ResourceLoader.exists(p) else null

## A plain texture shown at reference size: a TextureRect sized to the sprite (or `size`), filtered smoothly.
static func sprite_rect(tex: Texture2D, size := Vector2.ZERO, tint := Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var s := size
	if s == Vector2.ZERO and tex != null: s = tex.get_size() * SPRITE_SCALE
	r.size = s
	r.custom_minimum_size = s
	return r

## The theme's named sprite (TdTokens.ROLES: "panel", "window", "tooltip", "cd_badge", "clock_ring.3_1",
## "stat_icon.Power", "tooltip_tail_down"…) -> kit sprite name ("" when none).
static func role_sprite(role: String) -> String:
	return TdTokens.ROLES.get(role, "")

## An ability's full-face picture (kit abilities_face/<Name>), else its icon (the same name under abilities/). Only for
## the ability BUTTON, whose overlay sprite draws the rim around it; elsewhere use ability_icon().
static func ability_face(icon_name: String) -> Texture2D:
	var t := kit("abilities_face/" + icon_name)
	return t if t != null else kit("abilities/" + icon_name)

## The cooldown clock ring sprite for an ability: segments 1..3, recovered turns (or ready).
static func clock_ring_name(total: int, left: int, held: bool) -> String:
	var segments := clampi(total, 1, 3)
	if held: return "clock_ring_%d_0" % segments
	if left <= 0: return "clock_ring_%d_ready" % segments
	var t := maxi(1, total)
	var recovered := t - left if t <= 3 else int(floor(3.0 * float(t - left) / float(t)))
	return "clock_ring_%d_%d" % [segments, clampi(recovered, 0, segments - 1)]

# ------------------------------------------------------------------ motion

## A duration token in seconds: "instant" 0.10, "quick" 0.18, "normal" 0.25, "slow" 0.5, "tooltip_delay" 0.4,
## ping-pong periods "pulse_attention" 1.6, "pulse_soon" 1.1, "pulse_target" 0.9, "pulse_threat" 1.2, "blink_preview" 0.7.
static func motion(name: String) -> float:
	return float(TdTokens.MOTION.get(name.replace(".", "_"), 0.25))

## The easing curves (spec 2.4) as CSS cubic-beziers: "out" (.2,.8,.2,1: things appearing), "lift" (.2,.9,.3,1.25:
## overshoot ~1.06, hover/press/pop), "in_out" (.4,0,.2,1), "in" (.4,0,1,1: things leaving), "linear", "smooth"
## (smoothstep, the Unity default). t in 0..1.
static func eased(name: String, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	match name:
		"out", "ease_out", "ease.out": return bezier(0.2, 0.8, 0.2, 1.0, t)
		"lift", "ease_lift", "ease.lift": return bezier(0.2, 0.9, 0.3, 1.25, t)
		"in_out", "ease_in_out", "ease.inOut", "inout": return bezier(0.4, 0.0, 0.2, 1.0, t)
		"in", "ease_in": return bezier(0.4, 0.0, 1.0, 1.0, t)
		"linear": return t
		_: return t * t * (3.0 - 2.0 * t)

## CSS cubic-bezier(x1, y1, x2, y2) evaluated at progress x (solves x(s) = x by Newton + bisection).
static func bezier(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0
	var s := x
	for i in 8:
		var cx := _bz(x1, x2, s) - x
		if absf(cx) < 1e-6: return _bz(y1, y2, s)
		var d := _bz_d(x1, x2, s)
		if absf(d) < 1e-6: break
		s -= cx / d
	if s < 0.0 or s > 1.0 or absf(_bz(x1, x2, s) - x) > 1e-4:
		var lo := 0.0
		var hi := 1.0
		s = x
		for i in 30:
			var v := _bz(x1, x2, s)
			if absf(v - x) < 1e-6: break
			if v < x: lo = s
			else: hi = s
			s = (lo + hi) * 0.5
	return _bz(y1, y2, s)

static func _bz(p1: float, p2: float, s: float) -> float:
	var u := 1.0 - s
	return 3.0 * u * u * s * p1 + 3.0 * u * s * s * p2 + s * s * s

static func _bz_d(p1: float, p2: float, s: float) -> float:
	var u := 1.0 - s
	return 3.0 * u * u * p1 + 6.0 * u * s * (p2 - p1) + 3.0 * s * s * (1.0 - p2)

## A Curve resource sampled from an easing (for AnimationPlayer / Curve users).
static func curve(name: String, points := 16) -> Curve:
	var c := Curve.new()
	c.min_value = -0.5
	c.max_value = 1.5
	for i in points + 1:
		var t := float(i) / points
		c.add_point(Vector2(t, eased(name, t)))
	return c

## A Tween on the node that ignores Engine.time_scale (UI motion is never sped up by the game speed).
static func tween(node: Node) -> Tween:
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	return tw

## Puts a theme easing on a PropertyTweener (custom interpolator), returns it for chaining.
static func ease_tweener(tw: PropertyTweener, name: String) -> PropertyTweener:
	return tw.set_custom_interpolator(func(t: float) -> float: return eased(name, t))

## The frame's delta in unscaled time, from a scaled _process delta.
static func unscaled(delta: float) -> float:
	if Engine.time_scale > 0.001:
		return delta / Engine.time_scale
	return real_delta()

## Wall-clock seconds since the previous frame (clamped to 0.1 s), the same for every caller in a frame.
static func real_delta() -> float:
	var f := Engine.get_process_frames()
	if f != _rt_frame:
		var now := Time.get_ticks_usec()
		_rt_dt = 0.0 if _rt_last == 0 else clampf(float(now - _rt_last) / 1000000.0, 0.0, 0.1)
		_rt_last = now
		_rt_frame = f
	return _rt_dt

# ------------------------------------------------------------------ profiles and styles

## A feedback profile ("Button", "MenuButton", "IconButton", "Ability", "HandPiece", "EndTurn"): hover_scale,
## hover_lift, press_scale, press_sink, denied_shake, denied_time, spawn_scale.
static func feedback(profile: String) -> Dictionary:
	return TdTokens.FEEDBACK.get(profile, TdTokens.FEEDBACK["Button"])

## A control style ("Primary", "Secondary", "Danger", "Icon", "Ability", "EndTurn", "NamePlate", "Field", "Tab",
## "Row", "MenuPrimary", "MenuWood"): sprite per state, extra states, label colours.
static func control_style(name: String) -> Dictionary:
	return TdTokens.STYLES.get(name, {})

## The sprite a style shows for a state set (UIStateVisual priority: the extra state (its "<extra>Hover" while hovered),
## Disabled, Pressed, Selected, Hover, Normal; a state without a sprite falls back to Normal).
static func pick_sprite(style: Dictionary, hovered: bool, pressed: bool, selected: bool, disabled: bool, extra := "") -> String:
	if style.is_empty(): return ""
	var ex: Dictionary = style.get("extra", {})
	if extra != "":
		if hovered and ex.has(extra + "Hover"): return ex[extra + "Hover"]
		if ex.has(extra): return ex[extra]
	if disabled and style["disabled"] != "": return style["disabled"]
	if pressed and style["pressed"] != "": return style["pressed"]
	if selected and style["selected"] != "": return style["selected"]
	if hovered and style["hover"] != "": return style["hover"]
	return style["normal"]

## The Godot Theme for built-in controls (fonts, colours, kit 9-slices; type variations such as "PrimaryButton",
## "WindowPanel", "PaperCard", "H1Label", "InkLabel", "TextButton"). Set it on a screen's root Control.
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH)
		_widen_scrollbars(_theme)
	return _theme

## Every scroll bar at least SCROLLBAR_W wide (thick enough to grab; user, 2026-10-14): the track and grabber
## styles get content margins so their minimum size reaches it.
const SCROLLBAR_W := 12.0

static func _widen_scrollbars(th: Theme) -> void:
	for t in ["VScrollBar", "PaperVScrollBar", "HScrollBar"]:
		for st in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
			if not th.has_stylebox(st, t): continue
			var sb: StyleBox = th.get_stylebox(st, t).duplicate()
			if t == "HScrollBar":
				sb.content_margin_top = maxf(sb.content_margin_top, SCROLLBAR_W / 2.0)
				sb.content_margin_bottom = maxf(sb.content_margin_bottom, SCROLLBAR_W / 2.0)
			else:
				sb.content_margin_left = maxf(sb.content_margin_left, SCROLLBAR_W / 2.0)
				sb.content_margin_right = maxf(sb.content_margin_right, SCROLLBAR_W / 2.0)
			th.set_stylebox(st, t, sb)

## Spacing grid: step(1) = 4 … step(12) = 48 (space.N = N*4).
static func space(n: int) -> int:
	return n * 4
