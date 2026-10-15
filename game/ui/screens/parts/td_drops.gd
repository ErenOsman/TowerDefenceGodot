class_name TdDrops
extends RefCounted
## The token coins of the Missions & Guild screens (mockup .mcoin / .inv): a dark pill with the token's sprite
## (res://art/ui/KitB/tokens/<id>.png) and "×1"; first-win coins have a gold rim; a claimed first-win drop is dimmed
## with a green "✓ claimed" after it. Also the "Each win / First win" rows, and the inventory pills of the board
## header ("[coin] 2"). Tooltips name the token.

## A token's sprite (null when the kit has none).
static func token_texture(token_id: String) -> Texture2D:
	var app := TdMenu.app()
	if app == null: return null
	var t: TokenAsset = app.catalog.find_token(token_id) if app.catalog != null else null
	var tex: Texture2D = app.kit_texture(t.icon) if t != null and t.icon != "" else null
	return tex if tex != null else app.kit_texture("tokens/" + token_id)

static func token_name(token_id: String) -> String:
	var app := TdMenu.app()
	var t: TokenAsset = app.catalog.find_token(token_id) if app != null and app.catalog != null else null
	return t.get_display_name() if t != null else token_id

## One coin: icon + "×n" (count_text overrides the label, e.g. the inventory's "2"). first = gold rim; dim = claimed.
static func coin(token_id: String, amount: int, first := false, dim := false, size := 40.0, count_text := "") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.067, 0.05, 0.85)
	sb.border_color = TdTheme.color("gold") if first else TdTheme.color("rim")
	sb.set_border_width_all(3 if first else 2)
	sb.set_corner_radius_all(int(size / 2.0))
	sb.content_margin_left = 4; sb.content_margin_right = 10; sb.content_margin_top = 2; sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, size)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := TdMenu.hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	# the coin at least 24 px on screen (the sprite has a margin: 28 px), the count in Plinth 18 (UI review 2026-10-14)
	var d := clampf(size - 8.0, 28.0, 36.0)
	var pic := TdMenu.picture(token_texture(token_id), Vector2(d, d))
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pic)
	var l := TdMenu.label(count_text if count_text != "" else "×%d" % amount, "micro", TdTheme.color("cream.100"), 22 if size >= 42.0 else 18)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if dim: p.modulate = Color(1, 1, 1, 0.5)
	# what the token is for and how many you have (QA 2026-10-15: an "Each win" coin said only "Ember Core · Token")
	var app := TdMenu.app()
	var t: TokenAsset = app.catalog.find_token(token_id) if app != null and app.catalog != null else null
	var body := (t.description + "\n") if t != null and t.description != "" else ""
	body += "First win only." if first else "Every win."
	var have := ""
	if app != null and app.has_node("/root/SaveData"):
		var sd = app.get_node("/root/SaveData")
		if sd.tokens != null: have = str(sd.tokens.count(token_id))
	TdTooltipTrigger.attach(p, TooltipText.title(token_name(token_id), TooltipText.value_color(), "Token"), body,
		"You have" if have != "" else "", have)
	return p

## The coins of a {token: amount} list, in order.
static func coins(amounts: Dictionary, first := false, dim := false, size := 40.0) -> Array:
	var out := []
	for id in amounts:
		if int(amounts[id]) > 0: out.append(coin(str(id), int(amounts[id]), first, dim, size))
	return out

## "✓ claimed" in the good colour.
static func claimed_tag(size := 20) -> HBoxContainer:
	var h := TdMenu.hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TdMenu.picture(TdTheme.texture("icon_check"), Vector2(size - 2, size - 2))
	ic.modulate = TdTheme.color("good")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := TdMenu.label("claimed", "plate", TdTheme.color("good"), size)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

## The "Each win / First win" rows of a mission (MissionUiLogic.drop_rows) as a VBox; claimed dims the first-win row.
## label_w: the width of the row labels (so the coins line up).
static func rows(m: MissionDef, claimed: bool, size := 40.0, label_w := 96.0, font := 20) -> VBoxContainer:
	var v := TdMenu.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in MissionUiLogic.drop_rows(m):
		var first: bool = r[0] == "First win"
		var h := TdMenu.hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		var l := TdMenu.label(r[0], "plate", TdTheme.color("cream.200"), font)
		l.custom_minimum_size = Vector2(label_w, 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		for c in coins(r[1], first, first and claimed, size): h.add_child(c)
		if first and claimed: h.add_child(claimed_tag(font))
	return v

## A small icon from the extra icon set (flag, hourglass, users: res://art/ui/icons-extra/icon_<name>.png) or the kit
## ("cards", "back", "lock", "check", "info"…), tinted.
static func icon(name: String, size: float, tint: Color) -> TextureRect:
	var r := TdMenu.picture(icon_texture(name), Vector2(size, size))
	r.modulate = tint
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

## The texture of icon(): the extra set first, then the kit; null when neither has it.
static func icon_texture(name: String) -> Texture2D:
	var path := "res://art/ui/icons-extra/icon_%s.png" % name
	if ResourceLoader.exists(path): return load(path)
	return TdTheme.texture("icon_" + name) if TdTheme.has_sprite("icon_" + name) else null

## A line with a leading icon: [icon] text (rich, bold allowed).
static func icon_line(icon_name: String, bbcode: String, tint: Color, text_color: Color, font := 20) -> HBoxContainer:
	var h := TdMenu.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_name != "": h.add_child(icon(icon_name, font, tint))
	var r := TdMenu.rich(bbcode, "plate", text_color, font)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	return h

## A mode chip: "[users] Co-op 2–6" in violet (co-op) or teal-green (Any / Solo).
static func mode_chip(m: MissionDef, font := 20) -> PanelContainer:
	var coop := m != null and m.mode == MissionMode.Coop
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#6E3FD1") if coop else Color("#2F6B4F")
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10; sb.content_margin_right = 12; sb.content_margin_top = 2; sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := TdMenu.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(icon("users", font - 2, TdTheme.color("cream.100")))
	var l := TdMenu.label(MissionUiLogic.mode_chip(m), "plate", TdTheme.color("cream.100"), font)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return p
