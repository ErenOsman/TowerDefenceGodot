class_name CoopUi
extends RefCounted
## Builders shared by the co-op screens (mockups ~/uiux/mockups/screens-b/lobby-*.html): flat rounded boxes, text
## fields, the 1–6 player picker, level thumbnails (minimap), the paper level card (waves, towers each, energy rule,
## turns), level rows, hand medallion strips, status pills.

const ROW_BG := Color(0.29, 0.21, 0.16, 0.92)
const ROW_LINE := Color(0.43, 0.32, 0.24)
const SEL_BG := Color("3f74c9")
const SEL_LINE := Color("9cc2ff")
const WELL_BG := Color(0.13, 0.095, 0.075, 0.88)
const GOOD := Color("59b35c")
const BAD := Color("e2584f")
const GOLD := Color("f3c34e")

static var _thumbs := {}   # level id + size → ImageTexture

## A flat rounded StyleBox.
static func box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), width := 2, pad := Vector4(14, 10, 14, 10), dashed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(width)
	sb.content_margin_left = pad.x; sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z; sb.content_margin_bottom = pad.w
	if dashed: sb.draw_center = bg.a > 0.0
	return sb

static func flat_panel(bg: Color, radius := 12, border := Color(0, 0, 0, 0), pad := Vector4(14, 10, 14, 10)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, 2, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## A cream text field (the kit's LineEdit) with a placeholder; secret hides the text.
static func field(placeholder: String, width := 0.0, secret := false, max_len := 0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	if max_len > 0: e.max_length = max_len
	e.custom_minimum_size = Vector2(width, 56)
	TdTheme.apply_type(e, "body", TdTheme.color("ink"), 24)
	e.add_theme_color_override("font_placeholder_color", Color(TdTheme.color("ink"), 0.55))
	e.add_theme_color_override("caret_color", TdTheme.color("accent.fill"))
	e.add_theme_constant_override("caret_width", 3)
	e.add_theme_stylebox_override("normal", box(Color("efe2c4"), 10, Color("c9b48c"), 2, Vector4(18, 6, 18, 6)))
	e.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 10, SEL_LINE, 3, Vector4(18, 6, 18, 6)))
	return e

## Marks a field as wrong (red border) or normal.
static func field_error(e: LineEdit, wrong: bool) -> void:
	e.add_theme_stylebox_override("normal", box(Color("efe2c4"), 10, BAD if wrong else Color("c9b48c"), 3 if wrong else 2, Vector4(18, 6, 18, 6)))
	e.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 10, BAD if wrong else SEL_LINE, 3, Vector4(18, 6, 18, 6)))

## The red warning line under a field (icon + text), hidden while text is "".
static func warning(text := "") -> HBoxContainer:
	var h := TdMenu.hbox(8)
	h.add_child(TdMenu.picture(TdMenu.warn_icon(), Vector2(22, 22)))
	var l := TdMenu.label(text, "body", BAD, 22)
	l.name = "Text"
	h.add_child(l)
	h.visible = text != ""
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func set_warning(w: HBoxContainer, text: String, color := BAD) -> void:
	var l: Label = w.get_node("Text")
	l.text = text
	l.add_theme_color_override("font_color", color)
	w.visible = text != ""

## The 1–6 picker: kit TAB buttons; on_pick(n). Returns the buttons (index 0 = 1 player).
static func count_picker(parent: Container, selected: int, on_pick: Callable) -> Array:
	var out := []
	for n in range(NetProtocol.MIN_COUNT, NetProtocol.MAX_COUNT + 1):
		var b := TdMenu.button(TdButton.Style.TAB, str(n), Vector2(56, 52))
		b.selectable = true
		b.selected = n == selected
		b.font_size = 26
		b.bleed_mode = TdButton.Bleed.OFF
		var k := n
		b.clicked.connect(func():
			for x in out: x.set_selected(x == b)
			on_pick.call(k))
		parent.add_child(b)
		out.append(b)
	return out

## The level's minimap as a texture (cached).
static func thumb(level_id: String, pixels := 6) -> Texture2D:
	var key := "%s@%d" % [level_id, pixels]
	if _thumbs.has(key): return _thumbs[key]
	var a := CoopLevels.level_asset(level_id)
	var img := MenuLogic.minimap_image(a, pixels) if a != null else null
	var t: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	_thumbs[key] = t
	return t

## A level's small picture: its 3D board rendered to fill the box (CoopBoardPic); the minimap until it is ready.
static func thumb_rect(level_id: String, size: Vector2, _pixels := 6) -> Control:
	var frame := flat_panel(Color("1a130f"), 8, Color(0.25, 0.19, 0.14), Vector4(2, 2, 2, 2))
	frame.custom_minimum_size = size
	frame.clip_contents = true
	var pic := CoopBoardPic.new()
	pic.custom_minimum_size = size - Vector2(4, 4)
	frame.add_child(pic)
	pic.show_level(level_id)
	return frame

static func waves_of(level_id: String) -> int:
	var a := CoopLevels.level_asset(level_id)
	return a.waves.size() if a != null else 0

## A chip on the paper card: icon + bold number + word.
static func fact_chip(icon: String, value: String, word: String) -> PanelContainer:
	var p := flat_panel(Color("e9dbb9"), 10, Color("c9b48c"), Vector4(12, 6, 12, 6))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := TdMenu.hbox(8)
	p.add_child(h)
	if icon != "" and TdTheme.has_sprite(icon):
		var i := TdMenu.picture(TdTheme.texture(icon), Vector2(24, 24))
		i.modulate = TdTheme.color("ink")
		h.add_child(i)
	h.add_child(TdMenu.label(value, "h3", TdTheme.color("ink"), 26))
	var w := TdMenu.label(word, "body", TdTheme.color("ink"), 20)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(w)
	return p

## A wide note row on the paper card (icon + rich text).
static func note_row(icon: String, bbcode: String) -> PanelContainer:
	var p := flat_panel(Color("e9dbb9"), 10, Color("c9b48c"), Vector4(12, 6, 12, 6))
	var h := TdMenu.hbox(10)
	p.add_child(h)
	if icon != "" and TdTheme.has_sprite(icon):
		var i := TdMenu.picture(TdTheme.texture(icon), Vector2(24, 24))
		i.modulate = Color("c98a12") if icon == "icon_energy" else TdTheme.color("ink")
		i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(i)
	h.add_child(TdMenu.rich(bbcode, "body", TdTheme.color("ink"), 20))
	return p

## Puts a texture as a note row's icon (the hourglass for plays: icons outside the kit), in ink.
static func set_note_icon(row: PanelContainer, tex: Texture2D) -> void:
	var h: HBoxContainer = row.get_child(0)
	var first := h.get_child(0)
	if first is TextureRect:
		first.texture = tex
		return
	var i := TdMenu.picture(tex, Vector2(24, 24))
	i.modulate = TdTheme.color("ink")
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(i)
	h.move_child(i, 0)

## The paper level card: map, name, (description), waves · towers each, energy rule, turns note.
## Returns {panel, map, title, desc, facts, energy, turns, extra (VBox for buttons)}.
static func level_card(width: float, map_h: float, with_desc := false) -> Dictionary:
	var p := TdMenu.panel(TdPanel.Kind.PAPER, 12)
	p.custom_minimum_size = Vector2(width, 0)
	var v := TdMenu.vbox(10)
	p.add_child(v)
	var map_frame := flat_panel(Color("1a130f"), 12, Color(0, 0, 0, 0), Vector4(0, 0, 0, 0))
	map_frame.custom_minimum_size = Vector2(0, map_h)
	map_frame.clip_contents = true
	v.add_child(map_frame)
	var map := CoopBoardPic.new() # the 3D board rendered to fill the box (the minimap until then)
	map_frame.add_child(map)
	var title := TdMenu.label("", "h2", TdTheme.color("ink"), 34)
	v.add_child(title)
	var desc := TdMenu.wrap_label("", "body", TdTheme.color("ink"), 21)
	desc.visible = with_desc
	v.add_child(desc)
	var facts := TdMenu.hbox(10)
	v.add_child(facts)
	var energy := note_row("icon_energy", "")
	v.add_child(energy)
	var turns := note_row("icon_clock", "Turns in join order; [b]Pass[/b] moves you to the end.")
	v.add_child(turns)
	var extra := TdMenu.vbox(8)
	v.add_child(extra)
	return {"panel": p, "map": map, "title": title, "desc": desc, "facts": facts, "energy": energy, "turns": turns, "extra": extra}

## Fills a level card for a level and a player count.
## short: the energy rule without "(set by the level)" (the room, where height is tight).
static func fill_level_card(card: Dictionary, level_id: String, players: int, short := false) -> void:
	var a := CoopLevels.level_asset(level_id)
	(card.map as CoopBoardPic).show_level(level_id)
	card.title.text = CoopLevels.level_name(level_id)
	card.desc.text = a.description if a != null else ""
	for c in card.facts.get_children(): c.queue_free()
	card.facts.add_child(fact_chip("icon_wave", str(waves_of(level_id)), "waves"))
	card.facts.add_child(fact_chip("icon_cards", str(CoopLevels.hand_cap(level_id)), "towers each"))
	var e := CoopLevels.energy_text(level_id, players)
	var parts := e.split(" · ", true, 1)
	var rich: RichTextLabel = card.energy.get_child(0).get_child(card.energy.get_child(0).get_child_count() - 1)
	rich.text = ("[b]%s[/b] · %s" + ("" if short else " (set by the level)")) % [parts[0], parts[1]] if parts.size() > 1 else e

## A level row (thumb, name, "3 waves", optional tag); selectable. Returns the TdButton-like PanelContainer.
static func level_row(level_id: String, width: float, selected: bool, tag := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 70)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.add_theme_stylebox_override("panel", box(SEL_BG if selected else ROW_BG, 10, SEL_LINE if selected else ROW_LINE, 3 if selected else 2, Vector4(8, 6, 16, 6)))
	var h := TdMenu.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(thumb_rect(level_id, Vector2(80, 56), 4))
	var v := TdMenu.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(TdMenu.label(CoopLevels.level_name(level_id), "h3", TdTheme.color("cream.100"), 26))
	v.add_child(TdMenu.label("%d waves" % waves_of(level_id), "small", TdTheme.color("cream.200"), 20))
	if tag != "":
		var t := TdMenu.pill("[b]%s[/b]" % tag, Color(0.12, 0.09, 0.07, 0.85), GOLD, 20)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(t)
	return p

## A strip of hand medallions for hand entries (type ids, "<type>@<form>" for formed towers), padded with empty
## circles up to cap. A formed tower shows its form badge and its tooltip names the form ("Fire Archer").
static func hand_strip(types: Array, cap: int, diameter := 46.0) -> HBoxContainer:
	var h := TdMenu.hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in maxi(cap, types.size()):
		if i < types.size():
			var ta := CoopLevels.tower_asset(str(types[i]))
			var fa := CoopLevels.form_asset(str(types[i]))
			var view: String = ta.entity.view if ta != null and ta.entity != null else ""
			var m := TdMenu.medallion(TdMenu.unit_picture(view, ta.icon if ta != null else ""), diameter)
			TdFormBadge.attach(m, MenuLogic.form_badge(fa), diameter, 0.46)
			if ta != null:
				m.mouse_filter = Control.MOUSE_FILTER_PASS
				var nm := fa.get_display_name() if fa != null else ta.get_display_name()
				TdTooltipTrigger.attach(m, TooltipText.title(nm, TooltipText.tower_color(), "Form of " + ta.get_display_name() if fa != null else "Tower"),
					TooltipText.describe(fa.description if fa != null and fa.description != "" else ta.description))
			h.add_child(m)
		else:
			h.add_child(empty_circle(diameter))
	return h

static func empty_circle(d: float) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(d, d)
	p.add_theme_stylebox_override("panel", box(Color(0.1, 0.075, 0.06, 0.7), int(d / 2), Color(0.35, 0.27, 0.2), 2, Vector4.ZERO))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## A filled status pill ("Ready", "Waiting", "Full", "Playing").
static func state_pill(text: String, bg: Color, fg: Color) -> PanelContainer:
	return TdMenu.pill("[b]%s[/b]" % text, bg, fg, 20)

## A player's medallion: the bust of the first tower in their hand (else an empty circle).
static func player_medal(hand: Array, d := 56.0) -> Control:
	if hand.is_empty(): return empty_circle(d)
	var ta := CoopLevels.tower_asset(str(hand[0]))
	var view: String = ta.entity.view if ta != null and ta.entity != null else ""
	return TdMenu.medallion(TdMenu.unit_picture(view, ta.icon if ta != null else ""), d)

## A round number badge (slot number).
static func number_badge(n: int, dim := false) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(32, 32)
	p.add_theme_stylebox_override("panel", box(Color(0.35, 0.3, 0.27) if dim else Color("efe2c4"), 16, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0)))
	var l := TdMenu.label(str(n), "h3", TdTheme.color("cream.300") if dim else TdTheme.color("ink"), 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## Removes all children at once (a queued child would still count in a container for a frame).
static func clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

## A centred window popup body: CenterContainer + WINDOW panel of a size; returns {center, panel, body}.
static func window(parent: Control, size: Vector2, pad := 32.0) -> Dictionary:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, pad)
	p.custom_minimum_size = size
	center.add_child(p)
	var v := TdMenu.vbox(14)
	p.add_child(v)
	return {"center": center, "panel": p, "body": v}

## The title row: big title, optional sub text, close button. Returns {row, title, sub, close}.
static func title_row(text: String, sub := "", size := 56) -> Dictionary:
	var h := TdMenu.hbox(18)
	var t := TdMenu.label(text, "display", TdTheme.color("cream.100"), size)
	h.add_child(t)
	var s := TdMenu.label(sub, "body", TdTheme.color("cream.200"), 22)
	s.size_flags_vertical = Control.SIZE_SHRINK_END
	s.visible = sub != ""
	h.add_child(s)
	var sp := TdMenu.spacer()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var x := TdMenu.close_button()
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(x)
	return {"row": h, "title": t, "sub": s, "close": x}

## Opens a popup; outside a running tree (headless tests) it is shown without the transition.
static func show_popup(p: TdPopup) -> void:
	if p.is_inside_tree():
		p.open()
		return
	p._ensure_built()
	p.is_open = true
	p.visible = true
	p._on_open()

## A dashed rounded outline (empty room slots); content goes in as children of the returned MarginContainer.
class DashedBox extends MarginContainer:
	var color := Color(0.45, 0.35, 0.27, 0.9)
	var radius := 12.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right"]: add_theme_constant_override("margin_" + side, 14)
		for side in ["top", "bottom"]: add_theme_constant_override("margin_" + side, 6)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var pts := PackedVector2Array()
		var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
		var corners := [[r.position + Vector2(r.size.x - rad, rad), -PI / 2.0], [r.end - Vector2(rad, rad), 0.0],
			[Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0], [r.position + Vector2(rad, rad), PI]]
		for c in corners:
			for i in 7: pts.append(c[0] + Vector2.from_angle(c[1] + i * PI / 12.0) * rad)
		pts.append(pts[0])
		# walk the outline, drawing 10 px dashes with 7 px gaps
		var dash := 10.0
		var gap := 7.0
		var on := true
		var left := dash
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			var t := 0.0
			while t < seg:
				var step := minf(left, seg - t)
				var p0 := a.lerp(b, t / seg)
				var p1 := a.lerp(b, (t + step) / seg)
				if on: draw_line(p0, p1, color, 2.0, true)
				t += step
				left -= step
				if left <= 0.001:
					on = not on
					left = dash if on else gap

static var _glyphs := {}

## Small line icons the kit lacks, drawn once (48 px, cream): "search" (magnifier), "refresh" (circular arrow).
static func glyph(kind: String) -> Texture2D:
	if _glyphs.has(kind): return _glyphs[kind]
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var col := TdTheme.color("cream.100")
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var a := 0.0
			match kind:
				"search":
					var cc := Vector2(20, 20)
					a = 1.0 - clampf(absf(p.distance_to(cc) - 12.0) - 2.2, 0.0, 1.0)
					var d := Geometry2D.get_closest_point_to_segment(p, Vector2(29, 29), Vector2(41, 41)).distance_to(p)
					a = maxf(a, 1.0 - clampf(d - 3.0, 0.0, 1.0))
				"players":
					# two heads and shoulders
					for h in [[Vector2(18, 17), 7.0, Vector2(18, 40), 12.0], [Vector2(32, 15), 6.0, Vector2(33, 36), 10.0]]:
						if p.distance_to(h[0]) <= h[1]: a = 1.0
						var sh: Vector2 = h[2]
						if p.y <= 42.0 and p.y >= sh.y - h[3] + 6.0 and p.distance_to(Vector2(sh.x, sh.y + 2.0)) <= h[3]: a = 1.0
				"refresh":
					var ang := fposmod(atan2(p.y - c.y, p.x - c.x), TAU)
					var ring := 1.0 - clampf(absf(p.distance_to(c) - 15.0) - 2.2, 0.0, 1.0)
					if ang < deg_to_rad(320) and ang > deg_to_rad(10): a = ring
					# the arrow head at the end of the arc (top right, pointing down)
					var tip := Vector2(c.x + 15.0, c.y - 9.0)
					var tri := PackedVector2Array([tip + Vector2(-8, -6), tip + Vector2(8, -6), tip + Vector2(0, 6)])
					if Geometry2D.is_point_in_polygon(p, tri): a = 1.0
			if a > 0.0: img.set_pixel(x, y, Color(col, a))
	var t := ImageTexture.create_from_image(img)
	_glyphs[kind] = t
	return t

## A round initial medallion (the host on a lobby row, when no portrait is known).
static func initial_medal(player_name: String, d := 48.0, tint := Color("4a90e2")) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(d, d)
	p.add_theme_stylebox_override("panel", box(tint.darkened(0.35), int(d / 2), Color("efe2c4"), 2, Vector4.ZERO))
	var l := TdMenu.label(player_name.substr(0, 1).to_upper() if player_name != "" else "?", "h3", Color.WHITE, int(d * 0.48))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## A clickable paper row with an icon (the level card's "Change level"); on_click runs on a left click.
static func paper_action(icon: String, text: String, on_click: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := box(Color("e9dbb9"), 10, Color("6f9be0"), 2, Vector4(12, 8, 12, 8))
	var hover := box(Color("f3e8cc"), 10, SEL_BG, 3, Vector4(12, 8, 12, 8))
	p.add_theme_stylebox_override("panel", normal)
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", hover))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", normal))
	var h := TdMenu.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if TdTheme.has_sprite(icon):
		var i := TdMenu.picture(TdTheme.texture(icon), Vector2(24, 24))
		i.modulate = TdTheme.color("ink")
		i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(i)
	h.add_child(TdMenu.label(text, "h3", TdTheme.color("ink"), 22))
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: on_click.call())
	return p

## "• 42 ms" in good / warn colours, "• —" when unknown.
static func ping_label(ms: int) -> Label:
	var col := TdTheme.color("cream.300") if ms < 0 else (GOOD if ms < 100 else Color("e8913a"))
	var l := TdMenu.label("• —" if ms < 0 else "• %d ms" % ms, "body", col, 21)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.tooltip_text = "Round trip to the server" if ms >= 0 else "Not measured"
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l

## A visible cream scrollbar on a ScrollContainer's vertical bar (the default theme's is nearly invisible).
static func style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(12, 0)
	bar.add_theme_stylebox_override("scroll", box(Color(0.1, 0.075, 0.06, 0.8), 6, Color(0, 0, 0, 0), 0, Vector4(2, 2, 2, 2)))
	var grab := box(Color(TdTheme.color("cream.300"), 0.8), 6, Color(0, 0, 0, 0), 0, Vector4(4, 4, 4, 4))
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]: bar.add_theme_stylebox_override(k, grab)

static var _italic: FontVariation = null

## The body font slanted (the fonts have no italic face): chat system lines, notes.
static func italic_font() -> Font:
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = TdTheme.font("body")
		_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	return _italic
