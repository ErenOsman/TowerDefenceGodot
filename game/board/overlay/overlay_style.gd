class_name OverlayStyle
extends RefCounted
## The board overlay's tokens (UITheme.json colours and type, kit sprites), kept here so the overlay draws without
## the ui-kit theme; swap for the theme's named constants when it exists.

const RIM := Color(0.0706, 0.0471, 0.0353)
const CREAM := Color(0.9608, 0.9176, 0.8392)
const PAPER := Color(0.9333, 0.8863, 0.7765)
const INK := Color(0.1804, 0.1294, 0.0902)
const INK_850 := Color(0.129, 0.098, 0.0745, 0.92)
const FX_DAMAGE := Color(1.0, 0.302, 0.251)
const FX_HEAL := Color(0.4, 1.0, 0.451)
const FX_STATUS := Color(0.851, 0.6, 1.0)
const GOOD := Color(0.494, 0.878, 0.541)
const BAD := Color(1.0, 0.478, 0.42)
const ACCENT := Color(0.302, 0.561, 0.902)
const ACCENT_LIGHT := Color(0.553, 0.733, 1.0)
const GOLD := Color(1.0, 0.831, 0.42)
const HP_HIGH := Color(0.2, 0.851, 0.302)
const HP_MID := Color(0.949, 0.851, 0.149)
const HP_LOW := Color(0.902, 0.149, 0.149)
const HP_GHOST := Color(1.0, 0.302, 0.251, 0.55)
const CHIP_STATUS_BG := Color(0.1647, 0.1216, 0.2275)
const CHIP_GOOD_BG := Color(0.1137, 0.2, 0.1333)
const CHIP_BAD_BG := Color(0.2275, 0.1137, 0.1012)

const DISPLAY_FONT := "res://art/fonts/Plinth-Bold.ttf"
const BODY_FONT := "res://art/fonts/Nunito-ExtraBold.ttf"

static var _fonts := {}
static var _textures := {}

static func font(path: String = DISPLAY_FONT) -> Font:
	if _fonts.has(path): return _fonts[path]
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_fonts[path] = f
	return f

## A kit sprite (res://art/ui/KitB/<group>/<name>.png); null when missing.
static func kit(group_name: String) -> Texture2D:
	if _textures.has(group_name): return _textures[group_name]
	var p := "res://art/ui/KitB/%s.png" % group_name
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_textures[group_name] = t
	return t

## Label settings for text drawn straight over the board: an outline in the rim colour and a soft drop shadow.
static func world_label(size: int, color: Color, path: String = DISPLAY_FONT, outline: int = -1) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font(path)
	s.font_size = size
	s.font_color = color
	s.outline_size = outline if outline >= 0 else maxi(4, size / 6)
	s.outline_color = RIM
	s.shadow_size = 2
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_offset = Vector2(0, 3)
	return s

## Status tags by plate slot priority (UI rules: defensive buffs → control → damage over time → the rest).
const DEFENSIVE_TAGS := ["Shield", "Defensive", "Armor", "Guard", "Ward", "Barrier"]
const CONTROL_TAGS := ["Rooted", "Taunted", "Stunned", "Stun", "Frozen", "Slowed", "Silenced", "Control", "Feared"]
const DOT_TAGS := ["Poison", "Fire", "Burn", "Bleed", "Acid", "DoT"]

## A status's slot group: 0 defensive buff, 1 control, 2 damage over time, 3 the rest.
static func status_group(s: StatusView) -> int:
	var d: StatusDef = s.def
	if s.shield > 0: return 0
	if d == null: return 3
	for t in DEFENSIVE_TAGS:
		if d.has_tag(t) or d.name == t: return 0
	for t in CONTROL_TAGS:
		if d.has_tag(t): return 1
	for t in DOT_TAGS:
		if d.has_tag(t): return 2
	return 3

## A frame's statuses in plate slot order: by group, the newest first within a group (the frame lists them in the
## order they were applied).
static func ordered_statuses(list: Array) -> Array:
	var keyed := []
	for i in list.size(): keyed.append([status_group(list[i]), -i, list[i]])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out := []
	for k in keyed: out.append(k[2])
	return out
