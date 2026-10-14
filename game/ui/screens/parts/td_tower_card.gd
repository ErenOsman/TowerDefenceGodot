class_name TdTowerCard
extends RefCounted
## The parts of a tower's paper detail card, shared by the hand editor (Hand select) and the Workshop (picker card,
## "This tower now", the selected node's card): stat tiles, ability / passive rows (icon, name, "Attack ·
## projectile · 1 turn CD", result pills), a portrait medallion with its form badge, the dashed rule between rows.

const STAT_ICONS := {"MaxHp": "icon_heart", "Power": "icon_power", "Potency": "icon_del-spark", "Duration": "icon_clock",
	"Speed": "icon_speed", "Range": "icon_range", "Radius": "icon_range"}

static func _app() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameApp")

## A stat tile (paper_stat): icon, value, label. width 0 = fill.
static func stat_tile(stat: String, label: String, value: String, width := 158.0) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TdTheme.stylebox("paper_stat", Color.WHITE, [8, 2, 8, 2]))
	p.custom_minimum_size = Vector2(width, 44)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := TdMenu.hbox(6)
	p.add_child(h)
	var ic := TdMenu.picture(TdTheme.texture(STAT_ICONS.get(stat, "icon_power")), Vector2(18, 18))
	ic.modulate = TdTheme.color("bad.ink") if stat == "MaxHp" else TdTheme.color("ink.2")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := TdMenu.label(value, "header", TdTheme.color("ink"), 22)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var l := TdMenu.label(label, "small", TdTheme.color("ink.2"), 18)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return p

## A 2-column grid of stat tiles from [[stat, label, value], …], inside a margin the size of the paper_stat
## sprite's outset (its rim hangs outside the tile; without the margin a clipping parent cuts the left/right edge).
static func stat_grid(tiles: Array, width := 158.0) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for t in tiles: g.add_child(stat_tile(t[0], t[1], t[2], width))
	return bleed_margin(g)

## Wraps a control in a MarginContainer as wide as the paper_stat sprite's outset (+1 px), so its rim is not clipped.
static func bleed_margin(c: Control) -> MarginContainer:
	var o: Array = TdTheme.sprite_outset("paper_stat")
	var m := MarginContainer.new()
	var sides := ["left", "top", "right", "bottom"]
	for i in 4: m.add_theme_constant_override("margin_" + sides[i], int(ceil(float(o[i]) if o.size() > i else 0.0)) + 1)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

## An ability or passive row: the dashed rule above, icon (passives: the double-rim square chip), name, the subtitle,
## optional rich text, result pills.
static func ability_row(icon: Texture2D, name_text: String, sub: String, pills: Array, text: String, passive: bool) -> Control:
	var box := TdMenu.vbox(0)
	var line := DashLine.new()
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	box.add_child(m)
	var h := TdMenu.hbox(10)
	m.add_child(h)
	var isz := 44.0
	if false:
		pass
	else:
		var ic := TdMenu.picture(icon, Vector2(isz, isz))
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
	var v := TdMenu.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nr := TdMenu.hbox(8)
	v.add_child(nr)
	nr.add_child(TdMenu.label(name_text, "header", TdTheme.color("ink"), 20))
	if sub != "": v.add_child(TdMenu.wrap_label(sub, "small", TdTheme.color("ink.2"), 18))
	if text != "": v.add_child(TdMenu.rich(text, "body", TdTheme.color("ink"), 18))
	if not pills.is_empty():
		var f := HFlowContainer.new()
		f.add_theme_constant_override("h_separation", 6)
		f.add_theme_constant_override("v_separation", 4)
		for p in pills:
			f.add_child(TdMenu.pill("[font=%s]%s[/font] %s" % [TdTheme.font("plinth").resource_path, p[0], p[1]],
				Color(0, 0, 0, 0), TdTheme.color("ink.2"), 18, Color(TdTheme.color("ink.2"), 0.45)))
		v.add_child(f)
	return box

## The rows of an entity's abilities then passives.
static func def_rows(def: EntityDef, vocab: Vocabulary) -> Array:
	var out := []
	if def == null: return out
	var me: IEntity = DefStats.new(def)
	for ab in def.abilities: if ab != null: out.append(ability_row_of(ab, me, vocab))
	for pv in PassiveView.of(def): out.append(passive_row_of(pv.def, pv.name))
	return out

## One ability's row (icon from its asset, subtitle, result pills).
static func ability_row_of(ab: AbilityDef, me: IEntity, vocab: Vocabulary) -> Control:
	var icon := ability_icon(ab)
	var pills := []
	if me != null and vocab != null:
		for r in result_tags(ab, me, vocab): pills.append([str(r[0]), MenuLogic.result_name(str(r[1]))])
	var sub := HandLogic.ability_subtitle(ab.tags, ab.cooldown, ab.cooldown_until_reset)
	if ab.tags.is_empty() and HandLogic.ability_kind(ab) != "": sub = HandLogic.ability_kind(ab) + " · " + sub # Taunt: "Control · 2 turn CD"
	return ability_row(icon, ab.display_name, sub, pills, "", false)

## An ability's chip icon: the kit's by ability id (abilities/<id>.png, e.g. fire-shot: forms get their own icons
## when the kit delivers them), else its asset's icon (the base ability's for a form).
static func ability_icon(ab: AbilityDef) -> Texture2D:
	if ab == null: return null
	var t := TdTheme.kit("abilities/" + ab.name)
	if t != null: return t
	var app := _app()
	var asset = app.convert.asset_of(ab, "AbilityAsset") if app != null else null
	return TdTheme.ability_icon(MenuLogic.icon_name(asset.icon)) if asset != null and asset.icon != "" else null

## A passive's icon: the kit's double-rim square chip (passives/<icon>), else its icon.
static func passive_icon(p: PassiveDef) -> Texture2D:
	var app := _app()
	var asset = app.convert.asset_of(p, "PassiveAsset") if app != null and p != null else null
	if asset == null or asset.icon == "": return null
	var t := TdTheme.kit("passives/" + MenuLogic.icon_name(asset.icon))
	return t if t != null else app.icon_texture(asset.icon)

## The result tags shown under an ability: AbilityText.tags plus how long a status it applies lasts ("2 Duration",
## from the Apply Status step's duration, else the status's own) when AbilityText leaves it out (it only names a
## duration that scales). Shared with the Codex.
static func result_tags(ab: AbilityDef, me: IEntity, vocab: Vocabulary) -> Array:
	var out := AbilityText.tags(ab, me, vocab)
	for t in out:
		if str(t[1]) == "Duration": return out
	for st in AbilityText.all_steps(ab.steps):
		if not (st is ApplyStatusStep) or st.status == null: continue
		var d := -1
		if st.duration != null and not st.duration.is_empty and st.duration.expression.strip_edges().is_valid_int():
			d = int(st.duration.expression.strip_edges())
		elif st.status.duration >= 0:
			d = st.status.duration
		if d > 0:
			out.append([str(d), "Duration"])
			return out
	return out

## A disabled action on the cream card (mockup .k-btn.is-disabled on paper): a light muted fill, ink text, never
## clickable; reason (optional) as its tooltip. Fills the width.
static func disabled_button(text: String, icon: Texture2D, reason := "") -> Control:
	var p := PanelContainer.new()
	var sb := TdButton.disabled_box() # the one Disabled look (UI Design Rules § States)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 54)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)
	var h := TdMenu.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	var col := TdButton.DISABLED_LABEL
	if icon != null:
		var ic := TdMenu.picture(icon, Vector2(22, 22))
		ic.modulate = col
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := TdMenu.label(text, "header", col, 24)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	h.add_child(l)
	if reason != "": TdTooltipTrigger.attach(p, "", reason)
	return p

## A gold ring round a button (the mockup's .ws-gold: the Unlock buttons).
static func gold_ring(b: Control) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color("#FFD46B")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.show_behind_parent = true
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the button sprite sits inside its rect (its outset): the ring hugs the drawn button
	p.offset_left = 8; p.offset_right = -8; p.offset_top = -3; p.offset_bottom = 3
	b.add_child(p)

## One passive's row (always on).
static func passive_row_of(p: PassiveDef, name_text := "") -> Control:
	return ability_row(passive_icon(p), name_text if name_text != "" else p.display_name, "Passive · always on", [],
		TooltipText.describe(p.description), true)

## A portrait medallion (TdMenu.medallion) with the form's badge at its lower-right and, for a form, a ring in the
## badge's colour (the mockup's tint ring). grey: the portrait desaturated (a form not unlocked).
static func medallion(tex: Texture2D, diameter: float, badge_path := "", grey := false, ring := Color(0, 0, 0, 0)) -> Control:
	var m := TdMenu.medallion(tex, diameter)
	if grey:
		for c in m.get_children():
			if c is TextureRect and c.material != null: c.material = TdMenu.grey_circle_material()
	if ring.a > 0.0 or badge_path != "":
		var r := RingLine.new()
		r.colour = ring if ring.a > 0.0 else TdFormBadge.colour_of(badge_path)
		r.size = Vector2(diameter, diameter)
		m.add_child(r)
	TdFormBadge.attach(m, badge_path, diameter)
	return m

## A coloured ring drawn round a medallion (form tint, Current cobalt, Can unlock gold).
class RingLine extends Control:
	var colour := Color.WHITE
	var width := 4.0
	var glow := Color(0, 0, 0, 0)
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		# over the portrait ring sprite's coloured band (TdMenu.medallion: the sprite is 1.12 × the diameter)
		var c := size / 2.0
		var r := size.x * 0.515
		var w := maxf(width, size.x * 0.055)
		if glow.a > 0.0:
			for i in 7: draw_arc(c, r + w + 2.0 + i * 2.5, 0, TAU, 64, Color(glow, glow.a * (1.0 - i / 7.0)), 3.0, true)
		draw_arc(c, r, 0, TAU, 64, TdTheme.color("rim"), w + 4.0, true)
		draw_arc(c, r, 0, TAU, 64, colour, w, true)

## The dashed rule between ability rows.
class DashLine extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_dashed_line(Vector2(0, 1), Vector2(size.x, 1), Color(TdTheme.color("ink.2"), 0.3), 2.0, 6.0)
