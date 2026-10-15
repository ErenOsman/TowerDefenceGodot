extends SceneTree
## Builds the UI theme from the Unity theme's values and the sprite kit:
##   godot --headless --path . -s tools/build_theme.gd
## Reads res://data/content/UITheme.json (colours, type, motion, feedback profiles, control styles: which sprite per
## state), res://game/ui/theme/kit_slices.json (a copy of ~/uiux/kit-b/slices.json: every sprite's 9-slice border and
## outset) and, when present, ~/uiux/kit-b/tokens.json (the kit's extra colour stops). Writes
##   res://game/ui/theme/td_tokens.gd   class TdTokens: the tokens as constants (TdTheme reads them)
##   res://game/ui/theme/td_theme.tres  a Godot Theme: fonts, colours and TdSliceBox 9-slices for the built-in
##                                       controls (Button, Label, PanelContainer, LineEdit, sliders, tabs…) + type variations.
## Re-run it after changing UITheme.json or the kit. Self-contained (does not use TdTheme, which needs TdTokens).

const UITHEME := "res://data/content/UITheme.json"
const SLICES := "res://game/ui/theme/kit_slices.json"
const KIT_TOKENS := "/home/ubuntu/uiux/kit-b/tokens.json"
const OUT_TOKENS := "res://game/ui/theme/td_tokens.gd"
const OUT_THEME := "res://game/ui/theme/td_theme.tres"
const KIT := "res://art/ui/KitB/"
const SLICE_BOX := "res://game/ui/theme/td_slice_box.gd"

const FONT_FILES := {
	"plinth": "res://art/fonts/Plinth-Bold.ttf",
	"nunito_medium": "res://art/fonts/Nunito-Medium.ttf",
	"nunito_bold": "res://art/fonts/Nunito-Bold.ttf",
	"nunito_extrabold": "res://art/fonts/Nunito-ExtraBold.ttf",
	"nunito_regular": "res://art/fonts/Nunito-Regular.ttf",
}

## Status pill borders (manifest_ui.json statusParts; not in slices.json).
const EXTRA_SPRITES := {
	"status_time_pill": {"file": "statuses/parts/status_time_pill.png", "w": 56, "h": 48, "border": [24, 22, 24, 22], "outset": [0, 0, 0, 0]},
	"status_stack_pill": {"file": "statuses/parts/status_stack_pill.png", "w": 56, "h": 48, "border": [24, 22, 24, 22], "outset": [0, 0, 0, 0]},
	"status_time_badge": {"file": "statuses/parts/status_time_badge.png", "w": 44, "h": 44, "border": [0, 0, 0, 0], "outset": [0, 0, 0, 0]},
	"status_stack_badge": {"file": "statuses/parts/status_stack_badge.png", "w": 48, "h": 48, "border": [0, 0, 0, 0], "outset": [0, 0, 0, 0]},
	"icon_clock_status": {"file": "statuses/parts/icon_clock.png", "w": 48, "h": 48, "border": [0, 0, 0, 0], "outset": [0, 0, 0, 0]},
}

var colors := {}      # dotted name -> Color
var type_scale := {}  # role -> {font, size, color}
var sprites := {}     # name -> {path, w, h, border [l,t,r,b], outset [l,t,r,b]}
var slice_script: Script

func _initialize() -> void:
	slice_script = load(SLICE_BOX)
	var theme_json: Dictionary = _read_json(UITHEME)["assets"]["Settings/UITheme"]
	_read_colors(theme_json)
	_read_sprites()
	var src := _tokens_source(theme_json)
	var f := FileAccess.open(OUT_TOKENS, FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var theme := _build_theme(theme_json)
	var err := ResourceSaver.save(theme, OUT_THEME)
	print("build_theme: %d colours, %d sprites, %d type roles -> %s, %s (save %s)" % [colors.size(), sprites.size(), type_scale.size(), OUT_TOKENS, OUT_THEME, error_string(err)])
	quit(0 if err == OK else 1)

# ------------------------------------------------------------------ reading

func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())

## "wood900" -> "wood.900", "chipStatusBg" -> "chip.status.bg", "paper2" -> "paper.2"
static func dotted(camel: String) -> String:
	var out := ""
	for i in camel.length():
		var c := camel[i]
		if i > 0:
			var p := camel[i - 1]
			var up := c != c.to_lower() and c == c.to_upper()
			var digit := c.is_valid_int()
			var pdigit := p.is_valid_int()
			if up or (digit and not pdigit) or (not digit and pdigit):
				out += "."
		out += c.to_lower()
	return out

func _parse_css_color(s: String) -> Variant:
	s = s.strip_edges()
	if s.begins_with("#"):
		return Color.html(s)
	if s.begins_with("rgba(") or s.begins_with("rgb("):
		var inner := s.substr(s.find("(") + 1).trim_suffix(")")
		var p := inner.split(",")
		var a := float(p[3]) if p.size() > 3 else 1.0
		return Color(float(p[0]) / 255.0, float(p[1]) / 255.0, float(p[2]) / 255.0, a)
	return null

func _read_colors(theme_json: Dictionary) -> void:
	var kit = _read_json(KIT_TOKENS)
	if kit is Dictionary:
		for k in kit:
			var c = _parse_css_color(str(kit[k]))
			if c != null: colors[k] = c
	var src: Dictionary = theme_json["colors"]
	for k in src:
		var v: Array = src[k]
		colors[dotted(k)] = Color(v[0], v[1], v[2], v[3])
	for role in theme_json["type"]:
		var t = theme_json["type"][role]
		if not (t is Dictionary): continue
		type_scale[role] = {"font": _font_key(t["font"]), "size": int(t["size"]), "color": Color(t["color"][0], t["color"][1], t["color"][2], t["color"][3])}
	if not type_scale.has("header"): # the kit's tabs / chapter headers / section heads
		type_scale["header"] = {"font": "plinth", "size": 26, "color": colors["cream.100"]}
	if not type_scale.has("plaque_title") and type_scale.has("plaqueTitle"):
		type_scale["plaque_title"] = type_scale["plaqueTitle"]
		type_scale.erase("plaqueTitle")

func _font_key(unity_path: String) -> String:
	if "ExtraBold" in unity_path: return "nunito_extrabold"
	if "Nunito-Bold" in unity_path: return "nunito_bold"
	if "Nunito-Medium" in unity_path: return "nunito_medium"
	if "Nunito" in unity_path: return "nunito_regular"
	return "plinth"

func _read_sprites() -> void:
	var s: Dictionary = _read_json(SLICES)["sprites"]
	for name in s:
		var d: Dictionary = s[name]
		var path := KIT + str(d["file"]).trim_prefix("png/")
		if not ResourceLoader.exists(path): continue
		var b = d.get("border")
		var o = d.get("outsetRef")
		sprites[name] = {
			"path": path, "w": int(d["sizePx"]["w"]), "h": int(d["sizePx"]["h"]),
			"border": [int(b["l"]), int(b["t"]), int(b["r"]), int(b["b"])] if b is Dictionary else [0, 0, 0, 0],
			"outset": [float(o["l"]), float(o["t"]), float(o["r"]), float(o["b"])] if o is Dictionary else [0.0, 0.0, 0.0, 0.0],
		}
	for name in EXTRA_SPRITES:
		var e: Dictionary = EXTRA_SPRITES[name]
		var path: String = KIT + e["file"]
		if ResourceLoader.exists(path):
			sprites[name] = {"path": path, "w": e["w"], "h": e["h"], "border": e["border"], "outset": e["outset"]}

## "art/ui/KitB/buttons/btn_primary_normal.png" (or the old "Assets/Art/UI/KitB/…png#btn_primary_normal") -> "btn_primary_normal"
static func sprite_name(ref) -> String:
	if ref == null: return ""
	var s := str(ref)
	if "#" in s: return s.get_slice("#", 1)
	return s.get_file().get_basename()

# ------------------------------------------------------------------ td_tokens.gd

static func const_name(dotted_name: String) -> String:
	return dotted_name.replace(".", "_").replace("-", "_").to_upper()

static func lit_color(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [_f(c.r), _f(c.g), _f(c.b), _f(c.a)]

static func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0")
	if s.ends_with("."): s += "0"
	return s

func _tokens_source(theme_json: Dictionary) -> String:
	var L: PackedStringArray = []
	L.append("class_name TdTokens")
	L.append("## GENERATED by tools/build_theme.gd from res://data/content/UITheme.json and the kit's slices.json. Do not edit.")
	L.append("## Read through TdTheme (TdTheme.color(\"accent\"), TdTheme.font(\"display\")…); the constants are here for code")
	L.append("## that wants them directly (TdTokens.ACCENT).")
	L.append("")
	var names := colors.keys()
	names.sort()
	for n in names:
		L.append("const %s := %s" % [const_name(n), lit_color(colors[n])])
	L.append("")
	L.append("## Colour tokens by their spec name (\"wood.900\", \"accent.fill\", \"gold.ink\"…).")
	L.append("const COLORS := {")
	for n in names:
		L.append("\t\"%s\": %s," % [n, const_name(n)])
	L.append("}")
	L.append("")
	L.append("const FONT_FILES := {")
	for k in FONT_FILES:
		L.append("\t\"%s\": \"%s\"," % [k, FONT_FILES[k]])
	L.append("}")
	L.append("")
	L.append("## Type scale: role -> {font (FONT_FILES key), size (reference px), color}. Nothing under MIN_FONT_SIZE.")
	L.append("const TYPE := {")
	for role in type_scale:
		var t: Dictionary = type_scale[role]
		L.append("\t\"%s\": {\"font\": \"%s\", \"size\": %d, \"color\": %s}," % [role, t["font"], t["size"], lit_color(t["color"])])
	L.append("}")
	L.append("const MIN_FONT_SIZE := %d" % int(theme_json["type"].get("minimum", 18)))
	L.append("")
	L.append("const SAFE_MARGIN_X := %d" % int(theme_json.get("safeMarginX", 32)))
	L.append("const SAFE_MARGIN_Y := %d" % int(theme_json.get("safeMarginY", 16)))
	L.append("const SPACING := [4, 8, 12, 16, 20, 24, 32, 48]")
	L.append("")
	L.append("## Motion: seconds (unscaled time) and ping-pong periods.")
	L.append("const MOTION := {")
	var m: Dictionary = theme_json["motion"]
	for k in m:
		L.append("\t\"%s\": %s," % [_snake(k), _f(float(m[k]))])
	L.append("}")
	L.append("")
	L.append("## Feedback profiles (how a control kind answers the pointer).")
	L.append("const FEEDBACK := {")
	for p in theme_json["feedback"]:
		L.append("\t\"%s\": {\"hover_scale\": %s, \"hover_lift\": %s, \"press_scale\": %s, \"press_sink\": %s, \"denied_shake\": %s, \"denied_time\": %s, \"spawn_scale\": %s}," % [
			p["name"], _f(p["hoverScale"]), _f(p["hoverLift"]), _f(p["pressScale"]), _f(p["pressSink"]), _f(p["deniedShake"]), _f(p["deniedTime"]), _f(p["spawnScale"])])
	L.append("}")
	L.append("")
	L.append("## Control styles: sprite name per state (\"\" = none: falls back to normal), extra states, label colours.")
	L.append("const STYLES := {")
	for s in theme_json["styles"]:
		var extra := []
		for e in s.get("extra", []):
			extra.append("\"%s\": \"%s\"" % [e["state"], sprite_name(e["sprite"])])
		var lab: Array = s["label"]
		var dis: Array = s["labelDisabled"]
		L.append("\t\"%s\": {\"normal\": \"%s\", \"hover\": \"%s\", \"pressed\": \"%s\", \"disabled\": \"%s\", \"selected\": \"%s\", \"extra\": {%s}, \"label\": %s, \"label_disabled\": %s}," % [
			s["name"], sprite_name(s["normal"]), sprite_name(s["hover"]), sprite_name(s["pressed"]), sprite_name(s["disabled"]), sprite_name(s["selected"]),
			", ".join(extra), lit_color(Color(lab[0], lab[1], lab[2], lab[3])), lit_color(Color(dis[0], dis[1], dis[2], dis[3]))])
	L.append("}")
	L.append("")
	L.append("## The theme's named sprites (panel, window, tooltip, cd_badge, clock_ring.3_1, stat_icon.Power…) -> sprite name.")
	L.append("const ROLES := {")
	for k in theme_json:
		var v = theme_json[k]
		if v is String and "#" in v:
			L.append("\t\"%s\": \"%s\"," % [_snake(k), sprite_name(v)])
		elif v is Array and k in ["clockRings", "statIcons"]:
			for e in v:
				L.append("\t\"%s.%s\": \"%s\"," % [_snake(k).trim_suffix("s"), e["state"], sprite_name(e["sprite"])])
	L.append("}")
	L.append("")
	L.append("## Kit sprites: name -> [res path, png width, png height, [border l, t, r, b] (png px), [outset l, t, r, b] (reference px)].")
	L.append("const SPRITES := {")
	var sn := sprites.keys()
	sn.sort()
	for n in sn:
		var d: Dictionary = sprites[n]
		var o: Array = d["outset"]
		L.append("\t\"%s\": [\"%s\", %d, %d, [%d, %d, %d, %d], [%s, %s, %s, %s]]," % [n, d["path"], d["w"], d["h"],
			d["border"][0], d["border"][1], d["border"][2], d["border"][3], _f(o[0]), _f(o[1]), _f(o[2]), _f(o[3])])
	L.append("}")
	L.append("")
	return "\n".join(L)

static func _snake(camel: String) -> String:
	return dotted(camel).replace(".", "_")

# ------------------------------------------------------------------ td_theme.tres

func _box(name: String, pad := [-1.0, -1.0, -1.0, -1.0], tint := Color.WHITE) -> StyleBox:
	if not sprites.has(name):
		push_warning("build_theme: no sprite " + name)
		return StyleBoxEmpty.new()
	var d: Dictionary = sprites[name]
	var b = slice_script.new()
	b.texture = load(d["path"])
	b.border_left = d["border"][0]; b.border_top = d["border"][1]; b.border_right = d["border"][2]; b.border_bottom = d["border"][3]
	b.outset_left = d["outset"][0]; b.outset_top = d["outset"][1]; b.outset_right = d["outset"][2]; b.outset_bottom = d["outset"][3]
	b.modulate_color = tint
	b.content_margin_left = pad[0]; b.content_margin_top = pad[1]; b.content_margin_right = pad[2]; b.content_margin_bottom = pad[3]
	return b

## A texture for theme icons (which Godot draws at texture size): the PNG downscaled 2x (Lanczos) into
## res://game/ui/theme/half/<name>.png (imported on the next --import; the first build after adding one falls back to
## the full-size texture, so run the build twice after adding icons).
const HALF_DIR := "res://game/ui/theme/half/"

func _half_tex(name: String) -> Texture2D:
	if not sprites.has(name): return null
	var out := HALF_DIR + name + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HALF_DIR))
	var img := Image.load_from_file(ProjectSettings.globalize_path(sprites[name]["path"]))
	if img != null:
		img.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(out))
	if ResourceLoader.exists(out):
		return load(out)
	return load(sprites[name]["path"])

func _font(key: String) -> Font:
	return load(FONT_FILES[key])

func _c(n: String) -> Color:
	return colors.get(n, Color.MAGENTA)

func _flat(c: Color, radius := 0, pad := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

func _button_styles(th: Theme, type: String, style: Dictionary, pad: Array, font_key: String, size: int) -> void:
	var normal: String = style["normal"]
	th.set_stylebox("normal", type, _box(normal, pad))
	th.set_stylebox("hover", type, _box(style["hover"] if style["hover"] != "" else normal, pad))
	th.set_stylebox("pressed", type, _box(style["pressed"] if style["pressed"] != "" else normal, pad))
	th.set_stylebox("hover_pressed", type, _box(style["pressed"] if style["pressed"] != "" else normal, pad))
	th.set_stylebox("disabled", type, _box(style["disabled"] if style["disabled"] != "" else normal, pad))
	th.set_stylebox("focus", type, _box("focus_ring_r14", [0, 0, 0, 0], _c("accent")))
	var lab: Color = style["label"]
	th.set_color("font_color", type, lab)
	th.set_color("font_hover_color", type, lab)
	th.set_color("font_pressed_color", type, lab)
	th.set_color("font_hover_pressed_color", type, lab)
	th.set_color("font_focus_color", type, lab)
	th.set_color("font_disabled_color", type, style["label_disabled"])
	th.set_color("icon_normal_color", type, _c("cream.100"))
	th.set_color("icon_disabled_color", type, _c("cream.300"))
	th.set_font("font", type, _font(font_key))
	th.set_font_size("font_size", type, size)
	th.set_constant("h_separation", type, 12)

func _build_theme(theme_json: Dictionary) -> Theme:
	var th := Theme.new()
	th.default_font = _font("nunito_medium")
	th.default_font_size = 22
	var styles := {}
	for s in theme_json["styles"]:
		styles[s["name"]] = {"normal": sprite_name(s["normal"]), "hover": sprite_name(s["hover"]), "pressed": sprite_name(s["pressed"]),
			"disabled": sprite_name(s["disabled"]), "selected": sprite_name(s["selected"]),
			"label": Color(s["label"][0], s["label"][1], s["label"][2], s["label"][3]),
			"label_disabled": Color(s["labelDisabled"][0], s["labelDisabled"][1], s["labelDisabled"][2], s["labelDisabled"][3])}

	# --- labels: body on wood by default; variations per type role
	th.set_color("font_color", "Label", _c("cream.200"))
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	th.set_color("font_outline_color", "Label", Color(_c("rim"), 0.8))
	th.set_font("font", "Label", _font("nunito_medium"))
	th.set_font_size("font_size", "Label", 22)
	var label_roles := {"DisplayLabel": "display", "PlaqueTitleLabel": "plaque_title", "H1Label": "h1", "H2Label": "h2", "H3Label": "h3",
		"HeaderLabel": "header", "ButtonLabel": "button", "BodyLabel": "body", "SmallLabel": "small", "MicroLabel": "micro", "PlateLabel": "plate"}
	for v in label_roles:
		var t: Dictionary = type_scale[label_roles[v]]
		th.set_type_variation(v, "Label")
		th.set_font("font", v, _font(t["font"]))
		th.set_font_size("font_size", v, t["size"])
		th.set_color("font_color", v, t["color"])
	for v in ["InkLabel", "InkSmallLabel", "InkTitleLabel"]:
		th.set_type_variation(v, "Label")
	th.set_color("font_color", "InkLabel", _c("ink"))
	th.set_color("font_color", "InkSmallLabel", _c("ink.2"))
	th.set_font("font", "InkSmallLabel", _font("nunito_bold"))
	th.set_font_size("font_size", "InkSmallLabel", 20)
	th.set_color("font_color", "InkTitleLabel", _c("ink"))
	th.set_font("font", "InkTitleLabel", _font("plinth"))
	th.set_font_size("font_size", "InkTitleLabel", 28)
	# text over the board: outlined (UI rules: outline 0.2 at rim 80 %)
	th.set_type_variation("BoardLabel", "Label")
	th.set_font("font", "BoardLabel", _font("plinth"))
	th.set_font_size("font_size", "BoardLabel", 18)
	th.set_color("font_color", "BoardLabel", _c("cream.100"))
	th.set_constant("outline_size", "BoardLabel", 6)

	# --- rich text
	th.set_font("normal_font", "RichTextLabel", _font("nunito_medium"))
	th.set_font("bold_font", "RichTextLabel", _font("nunito_extrabold"))
	th.set_font("italics_font", "RichTextLabel", _font("nunito_medium"))
	th.set_font("bold_italics_font", "RichTextLabel", _font("nunito_extrabold"))
	th.set_font_size("normal_font_size", "RichTextLabel", 22)
	th.set_font_size("bold_font_size", "RichTextLabel", 22)
	th.set_color("default_color", "RichTextLabel", _c("cream.200"))
	th.set_constant("line_separation", "RichTextLabel", 2)
	th.set_type_variation("InkRichText", "RichTextLabel")
	th.set_color("default_color", "InkRichText", _c("ink"))

	# --- buttons: the plain Button is Secondary; variations for the other kit styles
	_button_styles(th, "Button", styles["Secondary"], [28, 8, 28, 8], "plinth", 28)
	var variations := {"PrimaryButton": ["Primary", [28, 8, 28, 8], 28], "SecondaryButton": ["Secondary", [28, 8, 28, 8], 28],
		"DangerButton": ["Danger", [28, 8, 28, 8], 28], "IconButton": ["Icon", [8, 8, 8, 8], 18],
		"MenuPrimaryButton": ["MenuPrimary", [32, 8, 32, 8], 28], "MenuWoodButton": ["MenuWood", [32, 8, 32, 8], 28],
		"TabButton": ["Tab", [24, 6, 24, 6], 26], "RowButton": ["Row", [16, 6, 8, 6], 26]}
	for v in variations:
		var spec: Array = variations[v]
		if not styles.has(spec[0]): continue
		th.set_type_variation(v, "Button")
		_button_styles(th, v, styles[spec[0]], spec[1], "plinth", spec[2])
	if sprites.has("btn_wood_normal"):
		th.set_type_variation("WoodButton", "Button")
		_button_styles(th, "WoodButton", {"normal": "btn_wood_normal", "hover": "btn_wood_hover", "pressed": "btn_wood_pressed",
			"disabled": "btn_wood_disabled", "label": _c("cream.100"), "label_disabled": _c("cream.300")}, [28, 8, 28, 8], "plinth", 28)
	# quiet text button ("Skip tutorial"): no panel
	th.set_type_variation("TextButton", "Button")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		th.set_stylebox(st, "TextButton", StyleBoxEmpty.new())
	th.set_color("font_color", "TextButton", _c("cream.200"))
	th.set_color("font_hover_color", "TextButton", _c("cream.100"))
	th.set_color("font_pressed_color", "TextButton", _c("cream.300"))
	th.set_font("font", "TextButton", _font("nunito_bold"))
	th.set_font_size("font_size", "TextButton", 22)

	# --- panels
	th.set_stylebox("panel", "PanelContainer", _box("panel_wood", [20, 20, 20, 20]))
	th.set_stylebox("panel", "Panel", _box("panel_wood"))
	var panels := {"WindowPanel": ["window_frame", 32], "PaperCard": ["paper_card", 20], "TooltipPanel": ["tooltip_paper", 16],
		"DialoguePanel": ["dialogue_box", 40], "PillPanel": ["pill_wood", 12], "EnemyPanel": ["panel_wood_enemy", 20],
		"MenuPanel": ["menu_panel", 32], "WellPanel": ["well", 16], "PaperStat": ["paper_stat", 8], "WoodPanel": ["panel_wood", 20]}
	for v in panels:
		th.set_type_variation(v, "PanelContainer")
		var pad: float = panels[v][1]
		th.set_stylebox("panel", v, _box(panels[v][0], [pad, pad, pad, pad]))
	# Godot's own tooltips (tooltip_text): paper like ours
	th.set_stylebox("panel", "TooltipPanel", _box("tooltip_paper", [18, 16, 18, 14]))
	th.set_color("font_color", "TooltipLabel", _c("ink"))
	th.set_font("font", "TooltipLabel", _font("nunito_medium"))
	th.set_font_size("font_size", "TooltipLabel", 22)

	# --- text field (paper)
	th.set_stylebox("normal", "LineEdit", _box("field_paper_normal", [20, 8, 20, 8]))
	th.set_stylebox("focus", "LineEdit", _box("field_paper_focus", [20, 8, 20, 8]))
	th.set_stylebox("read_only", "LineEdit", _box("field_paper_normal", [20, 8, 20, 8]))
	th.set_color("font_color", "LineEdit", _c("ink"))
	th.set_color("font_placeholder_color", "LineEdit", _c("ink.2"))
	th.set_color("caret_color", "LineEdit", _c("ink"))
	th.set_color("selection_color", "LineEdit", Color(_c("accent"), 0.35))
	th.set_font("font", "LineEdit", _font("nunito_bold"))
	th.set_font_size("font_size", "LineEdit", 26)
	th.set_type_variation("ErrorLineEdit", "LineEdit")
	th.set_stylebox("normal", "ErrorLineEdit", _box("field_paper_error", [20, 8, 20, 8]))
	th.set_stylebox("focus", "ErrorLineEdit", _box("field_paper_error", [20, 8, 20, 8]))

	# --- slider
	for t in ["HSlider"]:
		th.set_stylebox("slider", t, _box("slider_track", [0, 8, 0, 8]))
		th.set_stylebox("grabber_area", t, _box("slider_fill", [0, 8, 0, 8]))
		th.set_stylebox("grabber_area_highlight", t, _box("slider_fill", [0, 8, 0, 8]))
		th.set_icon("grabber", t, _half_tex("slider_knob_normal"))
		th.set_icon("grabber_highlight", t, _half_tex("slider_knob_hover"))
		th.set_icon("grabber_disabled", t, _half_tex("slider_knob_normal"))
	# --- toggle (CheckButton) and check box
	th.set_icon("checked", "CheckButton", _half_tex("toggle_on"))
	th.set_icon("unchecked", "CheckButton", _half_tex("toggle_off"))
	th.set_icon("checked_disabled", "CheckButton", _half_tex("toggle_on"))
	th.set_icon("unchecked_disabled", "CheckButton", _half_tex("toggle_off"))
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		th.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	th.set_color("font_color", "CheckButton", _c("cream.200"))
	th.set_color("font_hover_color", "CheckButton", _c("cream.100"))
	th.set_color("font_pressed_color", "CheckButton", _c("cream.100"))
	th.set_color("font_hover_pressed_color", "CheckButton", _c("cream.100"))
	th.set_font("font", "CheckButton", _font("nunito_bold"))
	th.set_font_size("font_size", "CheckButton", 22)
	# --- dropdown
	th.set_stylebox("normal", "OptionButton", _box("dropdown_normal", [18, 6, 44, 6]))
	th.set_stylebox("hover", "OptionButton", _box("dropdown_hover", [18, 6, 44, 6]))
	th.set_stylebox("pressed", "OptionButton", _box("dropdown_open", [18, 6, 44, 6]))
	th.set_stylebox("hover_pressed", "OptionButton", _box("dropdown_open", [18, 6, 44, 6]))
	th.set_stylebox("disabled", "OptionButton", _box("dropdown_normal", [18, 6, 44, 6]))
	th.set_stylebox("focus", "OptionButton", _box("focus_ring_r14", [0, 0, 0, 0], _c("accent")))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(k, "OptionButton", _c("ink"))
	th.set_color("font_disabled_color", "OptionButton", _c("ink.2"))
	th.set_font("font", "OptionButton", _font("nunito_bold"))
	th.set_font_size("font_size", "OptionButton", 22)
	th.set_icon("arrow", "OptionButton", _half_tex("dropdown_arrow"))
	th.set_constant("arrow_margin", "OptionButton", 16)
	th.set_stylebox("panel", "PopupMenu", _box("dropdown_list", [6, 6, 6, 6]))
	th.set_stylebox("hover", "PopupMenu", _box("dropdown_item_hover"))
	th.set_color("font_color", "PopupMenu", _c("ink"))
	th.set_color("font_hover_color", "PopupMenu", _c("ink"))
	th.set_font("font", "PopupMenu", _font("nunito_bold"))
	th.set_font_size("font_size", "PopupMenu", 22)
	th.set_constant("v_separation", "PopupMenu", 12)
	# --- tabs
	for t in ["TabBar", "TabContainer"]:
		th.set_stylebox("tab_unselected", t, _box("tab_normal", [24, 6, 24, 6]))
		th.set_stylebox("tab_hovered", t, _box("tab_hover", [24, 6, 24, 6]))
		th.set_stylebox("tab_selected", t, _box("tab_selected", [24, 6, 24, 6]))
		th.set_stylebox("tab_disabled", t, _box("tab_normal", [24, 6, 24, 6]))
		th.set_stylebox("tab_focus", t, _box("focus_ring_r14", [0, 0, 0, 0], _c("accent")))
		th.set_color("font_selected_color", t, Color.WHITE)
		th.set_color("font_unselected_color", t, _c("cream.200"))
		th.set_color("font_hovered_color", t, _c("cream.100"))
		th.set_color("font_disabled_color", t, _c("cream.300"))
		th.set_font("font", t, _font("plinth"))
		th.set_font_size("font_size", t, 26)
		th.set_constant("h_separation", t, 8)
	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	th.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	# --- scroll bars (wood; Paper variation for paper panels)
	for t in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", t, _box("scrollbar_track"))
		th.set_stylebox("scroll_focus", t, _box("scrollbar_track"))
		th.set_stylebox("grabber", t, _box("scrollbar_handle_normal"))
		th.set_stylebox("grabber_highlight", t, _box("scrollbar_handle_hover"))
		th.set_stylebox("grabber_pressed", t, _box("scrollbar_handle_hover"))
	th.set_type_variation("PaperVScrollBar", "VScrollBar")
	th.set_stylebox("scroll", "PaperVScrollBar", _box("scrollbar_track_paper"))
	th.set_stylebox("grabber", "PaperVScrollBar", _box("scrollbar_handle_paper"))
	th.set_stylebox("grabber_highlight", "PaperVScrollBar", _box("scrollbar_handle_paper"))
	th.set_stylebox("grabber_pressed", "PaperVScrollBar", _box("scrollbar_handle_paper"))
	# --- progress bar (loading bar)
	th.set_stylebox("background", "ProgressBar", _box("loadbar_track"))
	th.set_stylebox("fill", "ProgressBar", _box("loadbar_fill"))
	th.set_color("font_color", "ProgressBar", _c("cream.100"))
	th.set_font("font", "ProgressBar", _font("plinth"))
	th.set_font_size("font_size", "ProgressBar", 18)
	# --- separators
	var line := StyleBoxLine.new()
	line.color = _c("wood.500"); line.thickness = 2
	th.set_stylebox("separator", "HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = _c("wood.500"); vline.thickness = 2; vline.vertical = true
	th.set_stylebox("separator", "VSeparator", vline)
	return th
