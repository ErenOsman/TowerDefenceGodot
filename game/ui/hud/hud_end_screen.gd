class_name HudEndScreen
extends HudPopup
## The end of a level (UI_EndScreen; mockups screens-b/victory.html, defeat.html): a ribbon title over the window's
## top edge ("Victory" cobalt, "Defeat" red; the defeat window gets a red rim), "Chapter 1 · First Steps", the summary
## line, three paper stat tiles (victory: rounds, base health left, towers lost; defeat: waves cleared, rounds, towers
## lost), then the reward card (a first clear's tower) or, on a defeat, one Codex tip, and one centred row of
## buttons (Eren 2026-10-15: no Next level): Retry (wood) · Level select (cobalt, the primary: back to the level list;
## "Guild" for a mission, "Lobby" in co-op, "Main menu" after the tutorial) · Return (wood: the main menu, or the
## Camp once it is unlocked; not in co-op or the tutorial). Retry is hidden after winning the tutorial and when a
## mission has no play left. Esc and right click never close it: one of its buttons decides.
## A mission (mockups end-screen-mission, -last): "Mission · Patrol", the rewards row "Rewards [coin ×1]  First win
## [gold-rimmed coin ×1]" (first win only when this win took it; no "Spend them in the Workshop.": Eren 2026-10-16), under it "⧗ 1 play left
## today" / "✓ Done today: no plays left · resets in 5 h"; Retry hidden when no play is left (can_retry); the leave
## button says "Guild" (LevelController.end_list_label).

const WIDTH := 880.0

var retry_button: TdButton
var leave_button: TdButton
var return_button: TdButton
var ribbon: PanelContainer
var _ribbon_label: Label
var _place: Label
var _summary: Label
var _tiles: HBoxContainer
var _extra: VBoxContainer
var _won := false
var _rim: Panel
var _retry_line: Label

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
	retry_button.icon = HudArt.retry_icon()
	retry_button.clicked.connect(func(): if controller != null: controller.retry())
	leave_button = HudPopup.wide_button("Level select", TdButton.Style.SECONDARY, "icon_back", 240)
	leave_button.clicked.connect(func(): if controller != null: controller.end_list())
	return_button = HudPopup.wide_button("Main menu", TdButton.Style.SECONDARY, "icon_castle", 240)
	return_button.clicked.connect(func(): if controller != null: controller.go_return())
	row.add_child(retry_button)
	row.add_child(leave_button)
	row.add_child(return_button)
	_retry_line = HudArt.label("", "body", TdTheme.color("cream.200"), 20)
	_retry_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retry_line.visible = false
	body.add_child(_retry_line)
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
	var m: MissionDef = c.mission if "mission" in c else null
	if m != null:
		_place.text = MissionUiLogic.end_subtitle(m)
		var mp = _mission_progress()
		var rec: LevelRecord = mp.find(m.id) if mp != null else null
		var groups := MissionUiLogic.end_reward_groups(m, _won, rec != null and rec.wins == 1)
		var gold: int = c.gold_drop if "gold_drop" in c else 0
		if not groups.is_empty() or gold > 0: _extra.add_child(_mission_rewards(groups, gold, c.gold_text if gold > 0 else ""))
		_add_tasks(c)
		if mp != null:
			var line := MissionUiLogic.end_plays_line(m, mp)
			var done := MissionBoard.plays_left(m, mp) <= 0
			var row := HudArt.hbox(8)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(TdDrops.icon("check" if done else "hourglass", 20, TdTheme.color("cream.200")))
			row.add_child(HudArt.label(line, "body", TdTheme.color("cream.100"), 22))
			if _extra.get_child_count() > 0: _extra.add_child(TdMenu.spacer(14))
			_extra.add_child(row)
			# a play is left but Retry is hidden (every tower it would take is tired): say why, pointing at the Guild
			var why: String = c.retry_note if "retry_note" in c else ""
			if not done and why != "" and not c.can_retry:
				var wl := HudArt.label(MissionUiLogic.RetryAllTired if why == MissionBoard.AllTired else why + ".", "body", TdTheme.color("cream.300"), 20)
				wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_extra.add_child(wl)
	# Workshop tokens: "Rewards:" and a chip per token kind (icon, ×n, name)
	elif _won and "drops" in c and not c.drops.is_empty(): _extra.add_child(_token_row(c.drops))
	if m == null: _add_tasks(c)
	if not _won:
		var tip = _codex_tip("losing")
		if tip != null:
			# the mission's plays line sat 6 px over the card (QA 2026-10-14): the same gap as above it
			if _extra.get_child_count() > 0: _extra.add_child(TdMenu.spacer(14))
			_extra.add_child(_tip_card(tip))
	_extra.visible = _extra.get_child_count() > 0
	# buttons, won or lost alike: Retry · Level select / Guild (primary) · Return
	retry_button.visible = c.can_retry
	retry_button.style = TdButton.Style.SECONDARY
	leave_button.text = c.end_list_label
	leave_button.style = TdButton.Style.PRIMARY
	return_button.text = c.return_label
	return_button.visible = c.can_return
	var row: HBoxContainer = retry_button.get_parent()
	row.move_child(retry_button, 0)
	row.move_child(leave_button, 1)
	row.move_child(return_button, 2)
	# under Retry: when only some of the towers it would take are rested, which ones ("Retry takes 1 rested tower (Mage)")
	_retry_line.text = _retry_takes(c, m) if retry_button.visible and m != null else ""
	_retry_line.visible = _retry_line.text != ""
	open()

## The tower level tasks this level moved (Upgrades — Design; mockup end-screen-tasks), under the drops: a dark inset
## with "Tasks", one row per advance (UpgradeLogic.end_rows: "Archer (tower 3): Get 10 kills with it   8 / 10 kills
## +3", a done one "✓ … Done"; at most UpgradeLogic.END_ROWS, then "+2 more tasks moved") and a gold line per tower
## made ready ("★ Guardian is ready to upgrade! Go to the Blacksmith."). Nothing when no task moved (and never before
## the Blacksmith opens: the controller counts nothing then).
func _add_tasks(c: LevelController) -> void:
	var adv: Array = c.task_advances if "task_advances" in c else []
	if adv.is_empty(): return
	if _extra.get_child_count() > 0: _extra.add_child(TdMenu.spacer(14))
	_extra.add_child(task_block(adv))

## The Tasks inset of task_advances (public for tools).
static func task_block(adv: Array) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.067, 0.05, 0.55)
	box.border_color = Color(TdTheme.color("rim"), 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 16; box.content_margin_right = 16; box.content_margin_top = 10; box.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(778, 0)
	var v := HudArt.vbox(6)
	p.add_child(v)
	v.add_child(HudArt.label("Tasks", "h3", TdTheme.color("cream.100"), 22))
	var rows := UpgradeLogic.end_rows(adv)
	var green := Color("#7EE08A")
	for i in mini(rows.size(), UpgradeLogic.END_ROWS):
		var r: Dictionary = rows[i]
		var h := HudArt.hbox(8)
		var ic := TdMenu.picture(TdTheme.texture("icon_check") if r.done else TdDrops.icon_texture(UpgradeLogic.task_icon(r.kind)), Vector2(20, 20))
		ic.modulate = green if r.done else TdTheme.color("cream.200")
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		var who := "[b][color=%s]%s[/color][/b]" % [TdTheme.rich("cream.100"), r.who]
		if r.where != "": who += " " + r.where
		var t := TdMenu.rich("%s: %s" % [who, r.text], "body", TdTheme.color("cream.200"), 20)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		t.clip_contents = true
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		t.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(t)
		var right := "[b][color=%s]Done[/color][/b]" % green.to_html(false) if r.done else \
			"[b][color=%s]%s[/color][/b]  [b][color=%s]%s[/color][/b]" % [TdTheme.rich("cream.100"), r.progress, green.to_html(false), r.gain]
		var rl := TdMenu.rich(right, "body", TdTheme.color("cream.100"), 20)
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rl.fit_content = true
		rl.size_flags_horizontal = SIZE_SHRINK_END
		rl.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(rl)
		v.add_child(h)
	var more := UpgradeLogic.end_more(rows.size())
	if more != "": v.add_child(HudArt.label(more, "body", TdTheme.color("cream.300"), 18))
	for name in UpgradeLogic.end_ready(adv):
		var g := PanelContainer.new()
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(1.0, 0.83, 0.42, 0.12)
		gs.border_color = TdTheme.color("gold")
		gs.set_border_width_all(2)
		gs.set_corner_radius_all(8)
		gs.content_margin_left = 12; gs.content_margin_right = 12; gs.content_margin_top = 4; gs.content_margin_bottom = 5
		g.add_theme_stylebox_override("panel", gs)
		g.mouse_filter = MOUSE_FILTER_IGNORE
		var gh := HudArt.hbox(8)
		g.add_child(gh)
		var st := TdMenu.picture(TdLvChip.star_texture(), Vector2(22, 22))
		st.modulate = TdTheme.color("gold")
		st.size_flags_vertical = SIZE_SHRINK_CENTER
		gh.add_child(st)
		var gl := TdMenu.rich("[b][color=%s][font_size=22]%s is ready to upgrade![/font_size][/color][/b]  Go to the Blacksmith." % [TdTheme.rich("gold"), name],
			"body", TdTheme.color("cream.200"), 20)
		gl.autowrap_mode = TextServer.AUTOWRAP_OFF
		gl.size_flags_horizontal = SIZE_EXPAND_FILL
		gl.size_flags_vertical = SIZE_SHRINK_CENTER
		gh.add_child(gl)
		v.add_child(g)
	return p

## "Retry takes 1 rested tower (Mage)" for a solo mission whose cap is not filled by rested towers ("" otherwise).
func _retry_takes(c: LevelController, m: MissionDef) -> String:
	var sd := get_tree().root.get_node_or_null("SaveData") if is_inside_tree() else null
	var app := get_tree().root.get_node_or_null("GameApp") if is_inside_tree() else null
	if sd == null or c.level == null: return ""
	var cap: int = c.level.hand_cap
	var names := []
	for id in MissionBoard.taken(sd.towers.hand, sd.missions, cap):
		var owned: OwnedTower = sd.towers.find(id)
		var type: TowerAsset = app.catalog.find_tower(owned.type) if app != null and app.catalog != null and owned != null else null
		names.append(MenuLogic.tower_name(owned, type) if owned != null else str(id))
	return MissionUiLogic.retry_takes_line(names, cap)

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

func _mission_progress() -> MissionProgress:
	var sd := get_tree().root.get_node_or_null("SaveData") if is_inside_tree() else null
	return sd.missions if sd != null else null

## A mission's rewards row: per group its label ("Rewards" gold, "First win" cream), the coins (first-win ones
## gold-rimmed), the gold this win gave right after "Rewards" (LevelController.gold_drop / gold_text as one gold
## chip, "+150 gold"; the first win gives no extra gold; Backpack — Design).
func _mission_rewards(groups: Array, gold := 0, gold_text := "") -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(TdTheme.color("wood.850"), 0.95)
	box.border_color = TdTheme.color("gold.dark")
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 20; box.content_margin_right = 20; box.content_margin_top = 10; box.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(778, 0)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
	p.add_child(row)
	var gold_chip: Control = null
	if gold > 0: gold_chip = TdDrops.gold_coin(gold, false, false, 42.0, gold_text if gold_text != "" else "+%d gold" % gold)
	if groups.is_empty() and gold_chip != null:
		var gl := HudArt.label("Rewards", "h3", TdTheme.color("gold"), 26)
		gl.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(gl)
		row.add_child(gold_chip)
		return p
	for g in groups:
		var first: bool = g[2]
		var l := HudArt.label(g[0], "h3" if g[0] == "Rewards" else "body", TdTheme.color("gold") if g[0] == "Rewards" else TdTheme.color("cream.200"), 26 if g[0] == "Rewards" else 21)
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(l)
		# the win's whole gold (every win + first win) right after "Rewards", not inside the first-win group
		if gold_chip != null and gold_chip.get_parent() == null: row.add_child(gold_chip)
		for c in TdDrops.coins(g[1], first, false, 42.0): row.add_child(c)
	return p

## The Workshop tokens a win gave (Workshop — Design § Rules "Tokens"): "Rewards:" then a chip per kind (its 32 px
## icon, "×2", its name; tooltip: name and description), on the reward card's panel.
func _token_row(drops: Dictionary) -> Control:
	var app := get_tree().root.get_node_or_null("GameApp")
	var catalog: GameCatalogAsset = app.catalog if app != null else null
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(TdTheme.color("wood.850"), 0.95)
	box.border_color = TdTheme.color("gold.dark")
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 20; box.content_margin_right = 20; box.content_margin_top = 10; box.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(778, 0)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	p.add_child(row)
	var l := HudArt.label("Rewards:", "h3", TdTheme.color("gold"), 26)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(l)
	for r in HudText.token_rows(drops, catalog):
		var t: TokenAsset = r[0]
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.067, 0.05, 0.7)
		sb.border_color = TdTheme.color("rim")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(22)
		sb.content_margin_left = 5; sb.content_margin_right = 14; sb.content_margin_top = 3; sb.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = MOUSE_FILTER_STOP
		var h := HudArt.hbox(6)
		h.mouse_filter = MOUSE_FILTER_IGNORE
		chip.add_child(h)
		var ic := HudArt.icon(t.icon) if t != null else null
		if ic == null and t != null and app != null: ic = app.kit_texture(t.icon)
		var pic := TdTheme.sprite_rect(ic, Vector2(32, 32))
		pic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(pic)
		var n := HudArt.label("×%d" % r[2], "h3", TdTheme.color("cream.100"), 24)
		n.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(n)
		var nm := HudArt.label(t.get_display_name() if t != null else str(r[1]), "body", TdTheme.color("cream.200"), 20)
		nm.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(nm)
		if t != null: TdTooltipTrigger.attach(chip, TooltipText.title(t.get_display_name(), TooltipText.value_color(), "Token"),
			t.description)
		row.add_child(chip)
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
