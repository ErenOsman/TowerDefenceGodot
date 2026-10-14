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

## A 2-column grid of stat tiles from [[stat, label, value], …].
static func stat_grid(tiles: Array, width := 158.0) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for t in tiles: g.add_child(stat_tile(t[0], t[1], t[2], width))
	return g

## An ability or passive row: the dashed rule above, icon (passives: a 42 px medallion), name, the subtitle,
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
	if passive:
		var med := TdMenu.medallion(icon, isz - 2.0)
		med.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(med)
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
	var app := _app()
	var asset = app.convert.asset_of(ab, "AbilityAsset") if app != null else null
	var icon: Texture2D = TdTheme.ability_icon(MenuLogic.icon_name(asset.icon)) if asset != null and asset.icon != "" else null
	var pills := []
	if me != null and vocab != null:
		for r in result_tags(ab, me, vocab): pills.append([str(r[0]), MenuLogic.result_name(str(r[1]))])
	return ability_row(icon, ab.display_name, HandLogic.ability_subtitle(ab.tags, ab.cooldown, ab.cooldown_until_reset), pills, "", false)

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
	var app := _app()
	var asset = app.convert.asset_of(p, "PassiveAsset") if app != null else null
	var icon: Texture2D = app.icon_texture(asset.icon) if app != null and asset != null and asset.icon != "" else null
	return ability_row(icon, name_text if name_text != "" else p.display_name, "Passive · always on", [],
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
