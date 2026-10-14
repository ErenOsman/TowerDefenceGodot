class_name HudArt
extends RefCounted
## Pictures for the HUD from the content (through the level's AssetConverter and GameApp): unit portraits (bust
## renders, else the unit icon), hand miniatures, ability faces and chips, passive and status icons; plus small
## node helpers the HUD parts share (a masked circular portrait, a kit sprite rect, a labelled pill).

static func _app():
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameApp") if tree != null else null

static func icon(ref: String) -> Texture2D:
	if ref == "": return null
	var app = _app()
	if app != null: return app.icon_texture(ref)
	var p := ArtPaths.icon(ref)
	return load(p) if p != "" and ResourceLoader.exists(p) else null

static func portrait_named(unit: String) -> Texture2D:
	if unit == "": return null
	var app = _app()
	if app != null: return app.portrait_texture(unit)
	var p := ArtPaths.portrait(unit)
	return load(p) if p != "" and ResourceLoader.exists(p) else null

## An entity definition's colour portrait: its icon (res://art/icons/Units/<Name>.png, as the Unity HUD), else its
## bust render (by model folder, then display name).
static func portrait(converter: AssetConverter, def: EntityDef) -> Texture2D:
	if def == null: return null
	var asset = converter.asset_of(def, "EntityAsset") if converter != null else null
	var t: Texture2D = null
	if asset != null:
		t = icon(asset.icon)
		if t == null: t = portrait_named(HudText.model_name(asset.view))
		if t == null: t = portrait_named(asset.display_name)
	if t == null: t = portrait_named(def.display_name)
	return t

## A hand tower's miniature render (its own plinth), else its portrait.
static func miniature(converter: AssetConverter, def: EntityDef) -> Texture2D:
	var asset = converter.asset_of(def, "EntityAsset") if converter != null and def != null else null
	var t: Texture2D = icon(asset.miniature) if asset != null else null
	return t if t != null else portrait(converter, def)

static func _ability_ref(converter: AssetConverter, a: AbilityDef) -> String:
	var asset = converter.asset_of(a, "AbilityAsset") if converter != null and a != null else null
	return asset.icon if asset != null else ""

## The ability's full-face picture for an ability button (kit abilities_face/<Name>, else its icon).
static func ability_face(converter: AssetConverter, a: AbilityDef) -> Texture2D:
	var own := TdTheme.kit("abilities_face/" + a.name) if a != null else null # a form's own ability art, by id
	if own != null: return own
	var ref := _ability_ref(converter, a)
	var t := TdTheme.ability_face(HudText.icon_name(ref)) if ref != "" else null
	return t if t != null else icon(ref)

## The ability's chip icon for rows (kit abilities/<Name>, else its icon).
static func ability_chip(converter: AssetConverter, a: AbilityDef) -> Texture2D:
	var own := TdTheme.kit("abilities/" + a.name) if a != null else null # a form's own ability art, by id
	if own != null: return own
	var ref := _ability_ref(converter, a)
	var t := TdTheme.kit("abilities/" + HudText.icon_name(ref)) if ref != "" else null
	return t if t != null else icon(ref)

static func passive_icon(converter: AssetConverter, p: PassiveDef) -> Texture2D:
	var asset = converter.asset_of(p, "PassiveAsset") if converter != null and p != null else null
	if asset == null: return null
	var t := TdTheme.kit("passives/" + HudText.icon_name(asset.icon))
	return t if t != null else icon(asset.icon)

static func status_icon(converter: AssetConverter, s: StatusDef) -> Texture2D:
	var asset = converter.asset_of(s, "StatusAsset") if converter != null and s != null else null
	return icon(asset.icon) if asset != null else null

# ------------------------------------------------------------------ nodes

## A kit sprite rect at a size (mouse ignored).
static func sprite(name: String, size: Vector2, tint := Color.WHITE) -> TextureRect:
	return TdTheme.sprite_rect(TdTheme.texture(name), size, tint)

## A round portrait (HudPortrait) under a ring sprite drawn `ring_out` past it. Returns the holder; its children are
## named "Portrait" and "Ring".
static func medallion(diameter: float, ring_sprite: String, ring_out := 8.0) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size = Vector2(diameter, diameter)
	var ring := TextureRect.new()
	ring.name = "Ring"
	ring.texture = TdTheme.texture(ring_sprite)
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = -Vector2(ring_out, ring_out)
	ring.size = Vector2(diameter, diameter) + Vector2(ring_out, ring_out) * 2.0
	holder.add_child(ring)
	var pic := HudPortrait.new()
	pic.name = "Portrait"
	pic.size = Vector2(diameter, diameter) - Vector2(4, 4)
	pic.position = Vector2(2, 2)
	holder.add_child(pic)
	return holder

static func set_medallion(m: Control, tex: Texture2D, ring_sprite := "") -> void:
	(m.get_node("Portrait") as HudPortrait).texture = tex
	if ring_sprite != "": (m.get_node("Ring") as TextureRect).texture = TdTheme.texture(ring_sprite)

## A PanelContainer drawn with a kit 9-slice and padding [l, t, r, b].
static func panel(sprite_name: String, padding: Array, tint := Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TdTheme.stylebox(sprite_name, tint, padding))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

static func hbox(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func label(text: String, role: String, col := Color(0, 0, 0, 0), size := 0) -> Label:
	var l := TdTheme.label(text, role, col, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func rich(role: String, col := Color(0, 0, 0, 0), size := 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TdTheme.apply_type(r, role, col, size)
	r.add_theme_font_override("bold_font", TdTheme.font("nunito_extrabold"))
	return r

## The icon a stat or result tag shows (kit sprite name), "" when none.
static func tag_icon(name: String) -> String:
	match name:
		"MaxHp", "HP", "Heal": return "icon_heart"
		"Power", "Damage": return "icon_power"
		"Range", "Area", "Radius": return "icon_range"
		"Speed": return "icon_speed"
		"Move": return "icon_walk"
		"Duration", "Potency": return "icon_clock"
		"Hits": return "icon_shoot"
		"Jumps": return "icon_volley"
	return ""

## Tags as one BBCode line, each "icon [b]value[/b] name" ([[stat_or_tag, value, label], …] or [[value, name], …]),
## icons in ink.2 for paper.
static func tag_line(tags: Array, size := 20, tint := "") -> String:
	var parts: PackedStringArray = []
	var col := tint if tint != "" else TdTheme.rich("ink.2")
	for t in tags:
		var key: String = str(t[0]) if t.size() >= 3 else str(t[1])
		var value: String = str(t[1]) if t.size() >= 3 else str(t[0])
		var label: String = str(t[2]) if t.size() >= 3 else str(t[1])
		var icon_name := tag_icon(key)
		var img := ""
		if icon_name != "" and TdTheme.has_sprite(icon_name):
			img = "[img=%dx%d color=%s]%s[/img] " % [size, size, col, TdTokens.SPRITES[icon_name][0]]
		parts.append("%s[b]%s[/b]\u00a0%s" % [img.replace("[/img] ", "[/img]\u00a0"), value, label.replace(" ", "\u00a0")])
	return "  ".join(parts)

static var _retry_tex: Texture2D = null

## A "↻" glyph for Retry (the kit has none, and the fonts have no arrows): a white open ring with an arrow head,
## drawn once into a 64 px texture (tinted by the button like the kit's icons).
static func retry_icon() -> Texture2D:
	if _retry_tex != null: return _retry_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := Vector2(32, 34)
	var r_out := 21.0
	var r_in := 14.0
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length()
			var a := fposmod(atan2(p.y, p.x), TAU) # 0 = right, clockwise (y down)
			# the ring, open between about 290° and 345° (top right, where the arrow head sits)
			var on_ring := d <= r_out and d >= r_in and not (a > deg_to_rad(285.0) and a < deg_to_rad(350.0))
			var alpha := 0.0
			if on_ring: alpha = clampf(minf(r_out - d, d - r_in) + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	# the arrow head at the ring's open end (pointing clockwise, downwards-right)
	var tip := c + Vector2(cos(deg_to_rad(350.0)), sin(deg_to_rad(350.0))) * ((r_out + r_in) / 2.0)
	var head := PackedVector2Array([tip + Vector2(-12, -6), tip + Vector2(10, -8), tip + Vector2(2, 12)])
	for y in n:
		for x in n:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), head): img.set_pixel(x, y, Color.WHITE)
	_retry_tex = ImageTexture.create_from_image(img)
	return _retry_tex
