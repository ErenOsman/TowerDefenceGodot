class_name HudInspector
extends PanelContainer
## The card on the right for the selection or the hand tower being placed (hud-menu-spec §6.2; UI_InspectorCard; the
## Unity build's look): portrait in its ring, name (accent; red on the enemy panel), sub line ("Tower", "Enemy",
## "Yours", "Neutral", "Tower · 100 energy"), Info, the Health row and bar, statuses (chips with time / stacks badges,
## a tooltip each, left of the card), the description, stat tiles (Max HP first, value + bonus badge), one list of
## abilities (read-only rows: icon, name, "Ready" / "2 turns"; hover = tooltip + the range or, for an enemy, that
## ability's coming turn on the board) then passives ("Always on" / "Off", aura on hover), an enemy's "Next: …" line,
## and Sell with its refund for a placed tower. Opens sliding in from the right.

signal info_pressed

## The card: 360 wide, 32 px from the right edge, 96 from the top (Unity's BattleHudBuilder); 16 px padding.
const WIDTH := 360.0
const INNER := 328.0

var controller: LevelController
var shown_id := -1
var shown_tower := ""

var _portrait: Control
var _name: Label
var _sub: Label
var _info: TdButton
var _health_box: VBoxContainer
var _health_value: Label
var _hp: TdHealthBar
var _statuses: TdIconBar
var _desc: RichTextLabel
var _stats: GridContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
## Rows shown whole before the list scrolls (UI Design Rules: up to 6 fit above Sell).
const MAX_ROWS := 6
var _next: RichTextLabel
var _sell: TdButton
var _sell_value: Label
var _enemy := false
var _owner_key := ""
var _rows_key := ""
var _status_key := ""
var _open_t := 1.0

func _init() -> void:
	name = "Inspector"
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0)
	_set_panel(false)
	var v := HudArt.vbox(14)
	add_child(v)
	# head: portrait · name + sub · info
	var head := HudArt.hbox(14)
	v.add_child(head)
	_portrait = HudArt.medallion(88, "medallion_ring", 6)
	head.add_child(_portrait)
	var names := HudArt.vbox(2)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(names)
	_name = HudArt.label("", "h2", TdTheme.color("accent.light"))
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_name.custom_minimum_size = Vector2(140, 0)
	names.add_child(_name)
	var sub_row := HudArt.hbox(6)
	names.add_child(sub_row)
	_sub = HudArt.label("", "body", TdTheme.color("cream.300"), 20)
	_sub.size_flags_horizontal = SIZE_EXPAND_FILL
	_sub.clip_text = true
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub.custom_minimum_size = Vector2(60, 0)
	_sub.size_flags_vertical = SIZE_SHRINK_CENTER
	sub_row.add_child(_sub)
	_info = TdButton.new()
	_info.name = "InfoButton"
	_info.style = TdButton.Style.ICON
	_info.custom_minimum_size = Vector2(40, 40)
	_info.size = Vector2(40, 40)
	_info.icon = TdTheme.texture("icon_info")
	sub_row.add_child(_info)
	_info.clicked.connect(func(): info_pressed.emit())
	TdTooltipTrigger.attach(_info, TooltipText.title("Info", TooltipText.neutral_color()), "Everything about this unit: stats, abilities and statuses.", "Key", "I").set_placement(TdTooltipPlacement.Side.LEFT, self)
	# health
	_health_box = HudArt.vbox(6)
	v.add_child(_health_box)
	var hrow := HudArt.hbox(8)
	_health_box.add_child(hrow)
	var heart := HudArt.sprite("icon_heart", Vector2(20, 20), TdTheme.color("good"))
	heart.size_flags_vertical = SIZE_SHRINK_CENTER
	hrow.add_child(heart)
	var hl := HudArt.label("Health", "small", TdTheme.color("cream.200"))
	hl.size_flags_horizontal = SIZE_EXPAND_FILL
	hrow.add_child(hl)
	_health_value = HudArt.label("", "micro", TdTheme.color("cream.100"), 22)
	hrow.add_child(_health_value)
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(INNER, 14)
	bar_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_health_box.add_child(bar_holder)
	_hp = TdHealthBar.new()
	_hp.size = Vector2(INNER, 14)
	bar_holder.add_child(_hp)
	_statuses = TdIconBar.new()
	_statuses.icon_size = 40
	_statuses.h_spacing = 12
	_statuses.max_per_row = 6
	_statuses.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(_statuses)
	# description
	_desc = HudArt.rich("body", TdTheme.color("cream.200"))
	_desc.custom_minimum_size = Vector2(INNER, 0)
	v.add_child(_desc)
	# stat tiles
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 10)
	_stats.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(_stats)
	# abilities + passives
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = MOUSE_FILTER_PASS
	v.add_child(_scroll)
	_list = HudArt.vbox(8)
	_list.custom_minimum_size = Vector2(INNER, 0)
	_scroll.add_child(_list)
	_next = HudArt.rich("small", TdTheme.color("cream.100"))
	_next.custom_minimum_size = Vector2(INNER, 0)
	v.add_child(_next)
	# sell
	_sell = TdButton.new()
	_sell.name = "SellButton"
	_sell.style = TdButton.Style.DANGER
	_sell.bleed_mode = TdButton.Bleed.OFF # the card does not clip: keep it as wide as the rows above
	_sell.custom_minimum_size = Vector2(INNER, 48)
	_sell.size = Vector2(INNER, 48)
	_sell.text = ""
	v.add_child(_sell)
	var sell_row := HudArt.hbox(10)
	sell_row.z_index = 1
	sell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sell_row.set_anchors_preset(PRESET_FULL_RECT)
	_sell.face_node().add_child(sell_row) # on the face: it moves with it and keeps clear of the bleed room
	sell_row.add_child(HudArt.label("Sell", "button", TdTheme.color("cream.100"), 26))
	_sell_value = HudArt.label("", "button", TdTheme.color("gold.light"), 26)
	sell_row.add_child(_sell_value)
	for l in sell_row.get_children(): l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sell.clicked.connect(func(): if controller != null: controller.sell_selected())
	TdTooltipTrigger.attach(_sell, TooltipText.title("Sell", TooltipText.neutral_color()),
		"Refunds half the cost, scaled by the tower's remaining HP. The tower goes back to the hand.").set_placement(TdTooltipPlacement.Side.LEFT, self)

func _set_panel(enemy: bool) -> void:
	add_theme_stylebox_override("panel", TdTheme.stylebox("panel_wood_enemy" if enemy else "panel_wood", Color.WHITE, [16, 18, 16, 20]))

## What the card shows now: {entity, frame, hand} or null.
func subject(c: LevelController):
	if c == null or c.session == null or c.shown == null: return null
	var e: Entity = c.session.state.get_entity(c.selected)
	var f: EntityFrame = c.shown.get_frame(e.id) if e != null else null
	var hand: TowerDef = c.session.tower(c.placing) if f == null and c.placing != null else null
	if f == null and hand == null: return null
	return {"entity": e if f != null else null, "frame": f, "hand": hand}

## Slides in from the right (0.25 s, ease out).
func play_open() -> void:
	_open_t = 0.0

func _process(delta: float) -> void:
	if not visible: return
	if _open_t < 1.0: _open_t = minf(1.0, _open_t + TdTheme.unscaled(delta) / TdTheme.motion("normal"))
	var k := TdTheme.eased("out", _open_t)
	modulate.a = k
	size = get_combined_minimum_size()
	var w := get_parent_area_size().x
	position = Vector2(w - HudLayout.MARGIN - size.x + (1.0 - k) * 380.0, HudLayout.INSPECTOR_TOP)

func refresh() -> void:
	var c := controller
	var s = subject(c)
	if s == null: return
	var e: Entity = s["entity"]
	var f: EntityFrame = s["frame"]
	var hand: TowerDef = s["hand"]
	var session := c.session
	var tower_id = session.tower_id_of(e) if e != null else null
	var enemy := e != null and session.state.effective_team(e) == Teams.Enemy
	shown_id = e.id if e != null else -1
	shown_tower = hand.id if hand != null else ""
	if enemy != _enemy:
		_enemy = enemy
		_set_panel(enemy)
	var def: EntityDef = e.def if e != null else (hand.entity if hand != null else null)
	var tdef: TowerDef = hand if hand != null else (session.tower(tower_id) if tower_id != null else null)
	HudArt.set_medallion(_portrait, HudArt.portrait(c.converter, def), "portrait_ring_enemy" if enemy else "medallion_ring")
	_name.text = hand.name if hand != null else f.name
	_name.add_theme_color_override("font_color", TdTheme.color("bad") if enemy else TdTheme.color("accent.light"))
	if hand != null: _sub.text = "Tower · %d energy" % hand.cost
	elif tower_id != null: _sub.text = "Tower"
	elif enemy: _sub.text = "Enemy"
	elif session.is_commanded(e): _sub.text = "Yours"
	else: _sub.text = "Neutral"
	var desc := ""
	if hand != null: desc = hand.type.description if hand.type != null else ""
	elif tdef != null and tdef.type != null and tdef.type.description != "": desc = tdef.type.description
	elif def != null: desc = def.description
	_desc.text = TooltipText.from_rich(desc)
	_desc.visible = desc != ""
	# health + statuses
	_health_box.visible = f != null and f.has_hp
	if f != null and f.has_hp:
		_health_value.text = "%d / %d" % [f.hp, f.max_hp]
		if _owner_key != _key_of(e, hand): _hp.set_health_immediate(f.hp, f.max_hp)
		else: _hp.set_health(f.hp, f.max_hp)
	elif hand != null and def != null:
		_health_box.visible = true
		var mh := int(DefStats.new(def).stat("MaxHp"))
		_health_value.text = "%d / %d" % [mh, mh]
		_hp.set_health_immediate(mh, mh)
	_show_statuses(f)
	# stats
	var self_entity = e if e != null else (DefStats.new(def) if def != null else null)
	_show_stats(HudText.stat_tiles(self_entity, def, session.state.vocab))
	# abilities and passives
	var abilities: Array = e.abilities if e != null else (def.abilities if def != null else [])
	var passives: Array = f.passives if f != null else PassiveView.of(def)
	_show_list(e, f, self_entity, abilities, passives)
	# The "Next: …" forecast line is not shown (user decision 2026-10-13); hovering the enemy previews its turn on the board.
	_next.text = ""
	_next.visible = false
	# sell
	var can_sell := tower_id != null and f != null and f.life == LifeState.Alive
	_sell.visible = can_sell
	if can_sell:
		_sell_value.text = "+%d" % session.sell_value(tower_id)
		var keep := session.last_reason
		var ok := session.can_sell(tower_id) and c.can_act
		_sell.set_interactable(ok, session.last_reason if session.last_reason != "" else "Not now")
		session.last_reason = keep
	_owner_key = _key_of(e, hand)
	size = Vector2(WIDTH, 0)

func _key_of(e: Entity, hand: TowerDef) -> String:
	return ("e%d" % e.id) if e != null else ("t" + hand.id if hand != null else "")

func _show_statuses(f: EntityFrame) -> void:
	var list: Array = f.statuses if f != null else []
	var visible_list := []
	for st in OverlayStyle.ordered_statuses(list):
		if st.def != null and st.def.has_tag(Tags.Hidden): continue
		visible_list.append(st)
	var key := ""
	for st in visible_list: key += "%s:%d:%d:%d|" % [st.name, st.stacks, st.turns_left, st.shield]
	_statuses.visible = not visible_list.is_empty()
	if key == _status_key: return
	_status_key = key
	_statuses.clear_all()
	for st in visible_list:
		var chip := _statuses.add_icon(st.name, HudArt.status_icon(controller.converter, st.def), "", false)
		var shield: bool = st.def != null and st.def.stacks_are_shield
		chip.set_status(st.turns_left, st.shield if shield and st.shield > 0 else st.stacks, shield)
		var harmful: bool = st.def != null and st.def.has_tag(Tags.Debuff)
		var helpful: bool = st.def != null and st.def.has_tag(Tags.Buff)
		var rounds: bool = st.def != null and st.def.duration_unit == DurationUnit.Rounds
		var desc := HudText.status_description(st.def.description if st.def != null else "", st.stacks, st.turns_left)
		var by := ", ".join(st.applied_by)
		var t := TdTooltipTrigger.attach(chip)
		t.set_stack([TooltipText.status(st.name, desc, harmful, helpful, st.stacks, st.turns_left, rounds, false, by)],
			TdTooltipPlacement.Side.LEFT, self)

func _show_stats(tiles: Array) -> void:
	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	for t in tiles:
		_stats.add_child(stat_tile(t))
	_stats.visible = not tiles.is_empty()

## One stat tile (paper_stat): line 1 icon + value (+ bonus badge), line 2 the stat's name.
static func stat_tile(t: Dictionary, width := 159.0) -> Control:
	var p := HudArt.panel("paper_stat", [10, 4, 8, 4])
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(width, 58)
	var v := HudArt.vbox(-4)
	p.add_child(v)
	var line := HudArt.hbox(6)
	v.add_child(line)
	var icon_name := TdTheme.role_sprite("stat_icon." + str(t["stat"]))
	if icon_name != "":
		var ic := HudArt.sprite(icon_name, Vector2(20, 20), TdTheme.color("ink.2"))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		line.add_child(ic)
	line.add_child(HudArt.label(str(t["value"]), "micro", TdTheme.color("ink"), 26))
	if str(t["bonus"]) != "":
		var b := HudArt.label(str(t["bonus"]), "micro", TdTheme.color("bad.ink") if str(t["bonus"]).begins_with("-") else TdTheme.color("good.ink"), 18)
		b.size_flags_vertical = SIZE_SHRINK_CENTER
		line.add_child(b)
	v.add_child(HudArt.label(str(t["label"]), "small", TdTheme.color("ink.2"), 18))
	return p

func _show_list(e: Entity, f: EntityFrame, self_entity, abilities: Array, passives: Array) -> void:
	var c := controller
	var key := _key_of(e, c.session.tower(c.placing) if e == null and c.placing != null else null)
	for a in abilities:
		var left: int = f.cooldowns.get(a, 0) if f != null else 0
		key += "|%s:%d" % [a.name, left]
	for p in passives: key += "|%s:%s" % [p.name, p.active]
	if key == _rows_key: return
	_rows_key = key
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	for a in abilities:
		var left: int = f.cooldowns.get(a, 0) if f != null else 0
		var held := left == Entity.HeldCooldown
		var state := HudText.row_state(0 if held else left, held)
		var ready := state == "Ready"
		var row := _row(HudArt.ability_chip(c.converter, a), a.display_name, state, TdTheme.color("good") if ready else TdTheme.color("cream.200"))
		var content := TooltipText.ability(a.display_name, HudText.fill_stats(a.description, HudText.stat_values(self_entity, c.session.state.vocab)), " · ".join(a.tags),
			AbilityText.tags(a, self_entity, c.session.state.vocab) if self_entity != null else [], a.cooldown, a.cooldown_until_reset,
			left, [], a.start_cooldown)
		TdTooltipTrigger.attach(row).set_tooltip(content)
		TdTooltipTrigger.find_on(row).set_placement(TdTooltipPlacement.Side.LEFT, self)
		var ability: AbilityDef = a
		row.mouse_entered.connect(func(): if e != null: c.preview_ability(e, ability))
		row.mouse_exited.connect(func(): c.preview_ability(null, null))
		_list.add_child(row)
	for p in passives:
		var row := _row(HudArt.passive_icon(c.converter, p.def), p.name, "Always on" if p.active else "Off", TdTheme.color("status") if p.active else TdTheme.color("cream.300"))
		row.modulate.a = 1.0 if p.active else 0.6
		TdTooltipTrigger.attach(row).set_tooltip(TooltipText.passive(p.name, p.def.description if p.def != null else "", p.active))
		TdTooltipTrigger.find_on(row).set_placement(TdTooltipPlacement.Side.LEFT, self)
		var aura = p.def.aura if p.def != null else null
		row.mouse_entered.connect(func(): if e != null and aura != null and not aura.is_empty: c.preview_aura(e, aura))
		row.mouse_exited.connect(func(): c.preview_aura(null, null))
		_list.add_child(row)
	var n := _list.get_child_count()
	_scroll.visible = n > 0
	var shown := mini(n, MAX_ROWS)
	_scroll.custom_minimum_size = Vector2(INNER + (12.0 if n > MAX_ROWS else 0.0), shown * 44.0 + maxi(0, shown - 1) * 8.0)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if n > MAX_ROWS else ScrollContainer.SCROLL_MODE_DISABLED

func _row(icon: Texture2D, title: String, state: String, state_color: Color) -> PanelContainer:
	var row := HudArt.panel("row_normal", [8, 4, 10, 4])
	row.custom_minimum_size = Vector2(INNER, 44)
	row.mouse_filter = MOUSE_FILTER_PASS
	var h := HudArt.hbox(12)
	row.add_child(h)
	var ic := TdTheme.sprite_rect(icon, Vector2(32, 32))
	ic.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(ic)
	var n := HudArt.label(title, "body", TdTheme.color("cream.100"))
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(n)
	var st := HudArt.label(state, "small", state_color, 18)
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(st)
	return row
