class_name TdMenu
extends RefCounted
## Small builders shared by the menu screens (style B with the kit): backgrounds, labels, kit buttons, the
## "window" frame with a title and close button, pop-in of spawned rows (unscaled), portraits.

## The game's name until there is a logo.
const GAME_TITLE := "Tower Defence"

## The GameApp autoload (looked up, so this class also compiles in tools and tests run before autoloads exist).
static func app() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameApp")

## The shared menu background (Boot, Welcome, main menu, loading; the Unity build's image).
const MENU_BACKGROUND := "res://art/ui/Backgrounds/Spitters Blurred.png"

## The shared background image, centred and covering the parent (aspect kept, cropped), over dark wood.
static func menu_background(parent: Control) -> TextureRect:
	var bg := ColorRect.new()
	bg.color = TdTheme.color("wood.900")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var r := TextureRect.new()
	r.texture = load(MENU_BACKGROUND) if ResourceLoader.exists(MENU_BACKGROUND) else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

## A full-rect dark wood background (backdrop_wood) with the vignette over it.
static func wood_background(parent: Control, vignette := true) -> Control:
	var bg := ColorRect.new()
	bg.color = TdTheme.color("wood.900")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var tex := TextureRect.new()
	tex.texture = TdTheme.texture("backdrop_wood")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(tex)
	if vignette and TdTheme.has_sprite("vignette"):
		var v := TextureRect.new()
		v.texture = TdTheme.texture("vignette")
		v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.stretch_mode = TextureRect.STRETCH_SCALE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(v)
	return bg

## A Label in a type role, placed (optional) at a position.
static func label(text: String, role := "body", col := Color(0, 0, 0, 0), size := 0) -> Label:
	return TdTheme.label(text, role, col, size)

## A wrapping label of a fixed width.
static func wrap_label(text: String, role := "body", col := Color(0, 0, 0, 0), size := 0) -> Label:
	var l := TdTheme.label(text, role, col, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## A RichTextLabel (BBCode, fit to content) in a type role.
static func rich(text: String, role := "body", col := Color(0, 0, 0, 0), size := 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TdTheme.apply_type(r, role, col, size)
	r.add_theme_font_override("bold_font", TdTheme.font("nunito_extrabold"))
	r.text = text
	return r

## A kit button (TdButton) of a style with a label, optional icon and size.
static func button(style: int, text: String, size := Vector2.ZERO, icon: Texture2D = null) -> TdButton:
	var b := TdButton.new()
	b.style = style
	if size != Vector2.ZERO:
		b.custom_minimum_size = size
		b.size = size
	b.text = text
	if icon != null: b.icon = icon
	return b

## The window close button (× in an icon button, 52 px).
static func close_button() -> TdButton:
	var b := TdButton.new()
	b.style = TdButton.Style.ICON
	b.custom_minimum_size = Vector2(52, 52)
	b.size = Vector2(52, 52)
	b.icon = TdTheme.texture("icon_close")
	return b

## A built-in Button in the Theme's WoodButton style (screens' wood buttons: Back, Change hand).
static func wood_button(text: String, size := Vector2(220, 60)) -> Button:
	var b := Button.new()
	b.theme_type_variation = "WoodButton"
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	return b

## A panel of a TdPanel kind with padding.
static func panel(kind: int, pad := -1.0) -> TdPanel:
	var p := TdPanel.new()
	p.kind = kind
	if pad >= 0.0: p.padding = pad
	return p

## A plain StyleBox panel from a kit sprite (a Panel / PanelContainer override).
static func boxed(c: Control, sprite: String, pad: Array = []) -> Control:
	var key := "panel"
	c.add_theme_stylebox_override(key, TdTheme.stylebox(sprite, Color.WHITE, pad))
	return c

static func spacer(h := 0.0, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

## A texture rect of a fixed size (keeps aspect, centred, smooth).
static func picture(tex: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r

## A unit's picture: its bust render (portrait of the model), else its icon; null when neither.
static func unit_picture(view_path: String, icon_path: String) -> Texture2D:
	var n := MenuLogic.portrait_name(view_path)
	var t: Texture2D = app().portrait_texture(n) if n != "" else null
	if t == null and icon_path != "": t = app().icon_texture(icon_path)
	return t

## A round medallion: a portrait clipped to a circle inside a ring (portrait_ring / portrait_ring_enemy).
static func medallion(tex: Texture2D, diameter: float, enemy := false) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(diameter, diameter)
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_name := "portrait_ring_enemy" if enemy else "portrait_ring"
	if TdTheme.has_sprite(ring_name):
		var ring := picture(TdTheme.texture(ring_name), Vector2(diameter, diameter) * 1.12)
		ring.stretch_mode = TextureRect.STRETCH_SCALE
		ring.position = Vector2(diameter, diameter) * -0.06
		root.add_child(ring)
	if tex != null:
		var inner := diameter * 0.9
		var p := picture(tex, Vector2(inner, inner))
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		p.position = Vector2(diameter - inner, diameter - inner) / 2.0
		p.material = circle_material()
		root.add_child(p)
	return root

static var _circle: ShaderMaterial = null

## A material that cuts a TextureRect to the circle inscribed in it.
static func circle_material() -> ShaderMaterial:
	if _circle == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR.a *= 1.0 - smoothstep(0.46, 0.5, distance(UV, vec2(0.5)));\n}\n"
		_circle = ShaderMaterial.new()
		_circle.shader = sh
	return _circle

## Pops spawned controls in one after another (stagger seconds apart, unscaled time).
static func pop_in(items: Array, stagger := 0.035) -> void:
	var i := 0
	for c in items:
		if not (c is Control) or not is_instance_valid(c): continue
		var ctl: Control = c
		ctl.pivot_offset = ctl.custom_minimum_size / 2.0 if ctl.size == Vector2.ZERO else ctl.size / 2.0
		ctl.scale = Vector2(0.9, 0.9)
		var target := ctl.modulate.a # a dimmed control (a locked row at 60 %) pops in to its own alpha
		ctl.modulate.a = 0.0
		var tw := TdTheme.tween(ctl)
		tw.tween_interval(stagger * i)
		tw.set_parallel(true)
		TdTheme.ease_tweener(tw.tween_property(ctl, "scale", Vector2.ONE, TdTheme.motion("normal")), "lift")
		tw.tween_property(ctl, "modulate:a", target, TdTheme.motion("quick"))
		i += 1

## Slides controls in from the left with a fade (main menu list: x -24, 0.25 s, stagger 0.04 s).
static func slide_in(items: Array, stagger := 0.04, dx := -24.0) -> void:
	var i := 0
	for c in items:
		var ctl: Control = c
		var to := ctl.position
		ctl.position = to + Vector2(dx, 0)
		ctl.modulate.a = 0.0
		var tw := TdTheme.tween(ctl)
		tw.tween_interval(stagger * i)
		tw.set_parallel(true)
		TdTheme.ease_tweener(tw.tween_property(ctl, "position", to, TdTheme.motion("normal")), "out")
		tw.tween_property(ctl, "modulate:a", 1.0, TdTheme.motion("normal"))
		i += 1

## A tab strip of kit TAB buttons; on_pick(index) runs on click. Returns the buttons.
static func tabs(parent: Container, names: Array, icons: Array, size: Vector2, on_pick: Callable) -> Array:
	var out := []
	for i in names.size():
		var b := button(TdButton.Style.TAB, names[i], size, icons[i] if i < icons.size() else null)
		b.selectable = true
		var k := i
		b.clicked.connect(func(): on_pick.call(k))
		parent.add_child(b)
		out.append(b)
	return out

## A section heading: cream h3 text and a thin divider filling the rest of the row (gold is kept for values).
static func section_heading(text: String, size := 28) -> HBoxContainer:
	var h := hbox(14)
	var l := label(text, "h3", TdTheme.color("cream.100"), size)
	h.add_child(l)
	var sep := HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ls := StyleBoxLine.new()
	ls.color = Color(TdTheme.color("cream.300"), 0.35)
	ls.thickness = 2
	sep.add_theme_stylebox_override("separator", ls)
	h.add_child(sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

## The logo slot (the game's name is not decided): a container named "LogoSlot" holding the placeholder name;
## swap its child for the logo later. Thin cream outline, rounded, no fill.
static func logo_slot(font_size := 76, slot_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "LogoSlot"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(TdTheme.color("cream.300"), 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 28; sb.content_margin_right = 28
	sb.content_margin_top = 6; sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = slot_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = "Logo slot (placeholder title)"
	# the placeholder name (user decision 2026-10-13: keep the text until there is a logo)
	var t := label(GAME_TITLE, "display", TdTheme.color("cream.100"), font_size)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	t.add_theme_constant_override("shadow_offset_y", 4)
	p.add_child(t)
	return p

## A rounded pill (result tags, "2 new"): rich text on a flat fill.
static func pill(bbcode: String, bg: Color, fg: Color, size := 20, border := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	sb.content_margin_left = 10; sb.content_margin_right = 12
	sb.content_margin_top = 1; sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := rich(bbcode, "body", fg, size)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(r)
	return p

static var _warn: Texture2D = null

## A small warning triangle (bad.ink with a cream "!"), 20 px; the fonts have no ⚠.
static func warn_icon() -> Texture2D:
	if _warn != null: return _warn
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var red := TdTheme.color("bad.ink")
	var cream := TdTheme.color("cream.100")
	for y in n:
		for x in n:
			var t := float(y - 3) / float(n - 7)  # 0 at the apex, 1 at the base
			var half := t * (n - 4) / 2.0
			if t >= 0.0 and t <= 1.0 and absf(x - n / 2.0 + 0.5) <= half: img.set_pixel(x, y, red)
	for y in range(13, 27):
		for x in range(18, 22): img.set_pixel(x, y, cream)
	for y in range(29, 33):
		for x in range(18, 22): img.set_pixel(x, y, cream)
	_warn = ImageTexture.create_from_image(img)
	return _warn
