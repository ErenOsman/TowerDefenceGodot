class_name HudEndScreen
extends HudPopup
## The end of a level (UI_EndScreen; mockups screens-b/victory.html, defeat.html): a ribbon title over the window's
## top edge ("Victory" cobalt, "Defeat" red; the defeat window gets a red rim), "Chapter 1 · First Steps", the summary
## line, three paper stat tiles (victory: rounds, base health left, towers lost; defeat: waves cleared, rounds, towers
## lost), then the reward card (a first clear's tower) or, on a defeat, one Codex tip, and one centred row of
## buttons: defeat = Level select (wood) · Retry (cobalt); victory = Retry · Level select (wood) · Next level (cobalt)
## (Retry is cobalt when there is no next level; it is hidden after winning the tutorial). Esc and right click never
## close it: one of its buttons decides.

const WIDTH := 880.0

var retry_button: TdButton
var leave_button: TdButton
var next_button: TdButton
var ribbon: PanelContainer
var _ribbon_label: Label
var _place: Label
var _summary: Label
var _tiles: HBoxContainer
var _extra: VBoxContainer
var _won := false
var _rim: Panel

func _ready() -> void:
	closable = false
	make("", WIDTH, false, true)
	title_label.get_parent().visible = false
	body.add_theme_constant_override("separation", 22)
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 58)
	top_gap.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(top_gap)
	var head := HudArt.vbox(4)
	body.add_child(head)
	_place = HudArt.label("", "small", TdTheme.color("cream.300"))
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_place)
	_summary = HudArt.label("", "body", TdTheme.color("cream.100"), 26)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_summary)
	_tiles = HudArt.hbox(14)
	_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_tiles)
	_extra = HudArt.vbox(0)
	body.add_child(_extra)
	var row := HudArt.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	retry_button = HudPopup.wide_button("Retry", TdButton.Style.SECONDARY, "", 240)
	retry_button.clicked.connect(func(): if controller != null: controller.retry())
	leave_button = HudPopup.wide_button("Level select", TdButton.Style.SECONDARY, "icon_back", 240)
	leave_button.clicked.connect(func(): if controller != null: controller.level_select())
	next_button = HudPopup.wide_button("Next level", TdButton.Style.PRIMARY, "icon_next", 280)
	next_button.icon_after = true
	next_button.clicked.connect(func(): if controller != null: controller.next_level())
	row.add_child(retry_button)
	row.add_child(leave_button)
	row.add_child(next_button)
	# the ribbon title, over the window's top edge
	ribbon = PanelContainer.new()
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	ribbon.custom_minimum_size = Vector2(560, 116)
	add_child(ribbon)
	_ribbon_label = HudArt.label("Victory", "display", Color.WHITE, 76)
	_ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.outline(_ribbon_label, 4)
	ribbon.add_child(_ribbon_label)
	ribbon.draw.connect(_draw_tails)
	_rim = Panel.new()
	_rim.mouse_filter = MOUSE_FILTER_IGNORE
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = TdTheme.color("bad")
	rim.set_border_width_all(3)
	rim.set_corner_radius_all(24)
	rim.anti_aliasing = true
	_rim.add_theme_stylebox_override("panel", rim)
	add_child(_rim)
	move_child(_rim, ribbon.get_index())
	visible = false

static func _ribbon_box(fill: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = fill.darkened(0.45)
	b.set_border_width_all(4)
	b.set_corner_radius_all(16)
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4)
	b.anti_aliasing = true
	return b

func _ribbon_color() -> Color:
	return TdTheme.color("bad").darkened(0.15) if not _won else TdTheme.color("accent.fill")

## The ribbon's folded tails, behind its ends.
func _draw_tails() -> void:
	var s := ribbon.size
	var c := _ribbon_color().darkened(0.3)
	var y0 := 26.0
	var y1 := s.y - 10.0
	ribbon.draw_colored_polygon(PackedVector2Array([Vector2(-44, y0), Vector2(8, y0), Vector2(8, y1), Vector2(-44, y1), Vector2(-26, (y0 + y1) / 2.0)]), c)
	ribbon.draw_colored_polygon(PackedVector2Array([Vector2(s.x + 44, y0), Vector2(s.x - 8, y0), Vector2(s.x - 8, y1), Vector2(s.x + 44, y1), Vector2(s.x + 26, (y0 + y1) / 2.0)]), c)
	ribbon.draw_style_box(_ribbon_box(_ribbon_color()), Rect2(Vector2.ZERO, s))

func _process(delta: float) -> void:
	super._process(delta)
	if panel == null or not visible: return
	ribbon.size = ribbon.custom_minimum_size
	ribbon.position = Vector2(panel.position.x + (panel.size.x - ribbon.size.x) / 2.0, panel.position.y - 52.0)
	ribbon.modulate.a = panel.modulate.a
	_rim.visible = not _won
	_rim.position = panel.position - Vector2(2, 2)
	_rim.size = panel.size + Vector2(4, 4)
	_rim.scale = panel.scale
	_rim.pivot_offset = _rim.size / 2.0
	_rim.modulate.a = panel.modulate.a

func show_outcome(outcome: int) -> void:
	var c := controller
	var s := c.session
	_won = outcome == Outcome.Won
	_ribbon_label.text = "Victory" if _won else "Defeat"
	ribbon.queue_redraw()
	panel.add_theme_stylebox_override("panel", TdTheme.stylebox("window_frame", Color.WHITE, [40, 32, 40, 32]))
	_place.text = place_line(c)
	var cleared: int = c.waves_finished if "waves_finished" in c else 0
	var hp := 0
	var max_hp := 0
	for id in s.bases:
		var b: Entity = s.state.get_entity(id)
		if b != null:
			max_hp += b.max_hp
			if b.alive: hp += b.hp
	var lost: int = LevelResults.from(s, "", "").towers_lost
	_summary.text = ("Every wave cleared in %d rounds." % s.round) if _won else ("The base fell in round %d. Waves cleared: %d of %d." % [s.round, cleared, s.waves.size()])
	for ch in _tiles.get_children():
		_tiles.remove_child(ch) # gone at once: the window is sized from what is left
		ch.queue_free()
	if _won:
		_tiles.add_child(_tile("icon_clock", str(s.round), "rounds"))
		_tiles.add_child(_tile("icon_heart", "%d / %d" % [hp, max_hp], "base health left", TdTheme.color("bad")))
		_tiles.add_child(_tile("icon_castle", str(lost), "towers lost"))
	else:
		_tiles.add_child(_tile("icon_wave", "%d / %d" % [cleared, s.waves.size()], "waves cleared"))
		_tiles.add_child(_tile("icon_clock", str(s.round), "rounds"))
		_tiles.add_child(_tile("icon_castle", str(lost), "towers lost"))
	for ch in _extra.get_children():
		_extra.remove_child(ch)
		ch.queue_free()
	if _won and c.reward != null: _extra.add_child(_reward_card(c.reward))
	elif not _won:
		var tip = _codex_tip("losing")
		if tip != null: _extra.add_child(_tip_card(tip))
	_extra.visible = _extra.get_child_count() > 0
	# buttons: defeat = Level select · Retry (primary); victory = Retry · Level select · Next level (primary)
	var has_next: bool = _won and c.next_level_asset != null
	next_button.visible = has_next
	retry_button.visible = c.can_retry
	retry_button.style = TdButton.Style.SECONDARY if has_next else TdButton.Style.PRIMARY
	leave_button.text = c.leave_label
	var row: HBoxContainer = retry_button.get_parent()
	row.move_child(leave_button, 0 if not _won else 1)
	if not _won: row.move_child(retry_button, 1)
	else: row.move_child(retry_button, 0)
	open()

## "Chapter 1 · First Steps": the level's chapter (from the catalog) and its name.
static func place_line(c: LevelController) -> String:
	if c == null or c.level == null: return ""
	var app = c.get_tree().root.get_node_or_null("GameApp") if c.is_inside_tree() else null
	var catalog: GameCatalogAsset = app.catalog if app != null else null
	if catalog != null:
		for e in catalog.entries():
			if e[0].level == c.level:
				var ch: ChapterData = catalog.chapters[e[1]]
				var chapter: String = ch.display_name if ch.display_name != "" else "Chapter %d" % (e[1] + 1)
				return "%s · %s" % [chapter, c.level.display_name]
	return c.level.display_name

func _codex_tip(id: String):
	var app = get_tree().root.get_node_or_null("GameApp")
	var catalog: GameCatalogAsset = app.catalog if app != null else null
	if catalog == null or catalog.codex == null or catalog.codex.tips.is_empty(): return null
	for t in catalog.codex.tips:
		if t != null and t.id == id: return t
	return catalog.codex.tips[0]

## A paper stat tile: icon, the number (Plinth 40), the label.
func _tile(icon_name: String, value: String, label: String, tint := Color(0, 0, 0, 0)) -> Control:
	var p := HudArt.panel("paper_card", [12, 12, 12, 12])
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(250, 124)
	var v := HudArt.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var ic := HudArt.sprite(icon_name, Vector2(24, 24), tint if tint.a > 0.0 else TdTheme.color("ink"))
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	v.add_child(ic)
	var n := HudArt.label(value, "h1", TdTheme.color("ink"), 40)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := HudArt.label(label, "small", TdTheme.color("ink.2"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return p

func _tip_card(tip) -> Control:
	var p := HudArt.panel("paper_card", [24, 14, 24, 16])
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(778, 0)
	var h := HudArt.hbox(14)
	p.add_child(h)
	var ic := HudArt.sprite("icon_codex", Vector2(26, 26), TdTheme.color("ink"))
	ic.size_flags_vertical = SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := HudArt.vbox(2)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(HudArt.label("Codex tip: " + tip.title, "header", TdTheme.color("ink")))
	var t := HudArt.rich("body", TdTheme.color("ink.2"))
	t.custom_minimum_size = Vector2(690, 0)
	t.text = TooltipText.from_rich(tip.text)
	v.add_child(t)
	return p

func _reward_card(reward: TowerAsset) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(TdTheme.color("wood.850"), 0.95)
	box.border_color = TdTheme.color("teal")
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 20; box.content_margin_right = 20; box.content_margin_top = 14; box.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(778, 0)
	var h := HudArt.hbox(18)
	p.add_child(h)
	var medal := HudArt.medallion(100, "medallion_ring", 7)
	medal.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(medal)
	var conv: AssetConverter = controller.converter
	var def: EntityDef = conv.tower(reward, "reward").entity if conv != null and reward != null else null
	HudArt.set_medallion(medal, HudArt.portrait(conv, def) if def != null else HudArt.icon(reward.icon))
	var v := HudArt.vbox(2)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(HudArt.label("FIRST WIN REWARD", "small", TdTheme.color("teal")))
	v.add_child(HudArt.label(HudText.joined(reward.display_name), "h2", TdTheme.color("cream.100")))
	if reward.description != "":
		var d := HudArt.rich("body", TdTheme.color("cream.200"))
		d.custom_minimum_size = Vector2(620, 0)
		d.text = TooltipText.from_rich(reward.description)
		v.add_child(d)
	return p
