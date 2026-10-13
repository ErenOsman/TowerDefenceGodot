class_name HudInfoPopup
extends HudPopup
## The Tower / Enemy Info window (UI_InfoPopup, UI_TowerInfo / UI_EnemyInfo; UI Design Rules, Codex and the Info
## window): about 960 × 640, × to close (Esc / right click too). Header: portrait, name (accent, red for an enemy),
## sub line, Health. Left: description and the stat tiles. Right (scrolls): one Abilities list (icon with the
## cooldown state under it: "Ready" / "In 1 turn"; name + tags, the full description, the result tags; passives
## at the end with "Always on") and Statuses (icon chip, name, description with live values, "2 turns left ·
## applied by …"; "No statuses"). The "Next turn" forecast line is not shown.

const ROW_W := 520.0

var shown_id := -1
var _portrait: Control
var _name: Label
var _sub: Label
var _health: Label
var _desc: RichTextLabel
var _stats: GridContainer
var _right: VBoxContainer
var _values := {}

func _ready() -> void:
	make("", 960, true)
	# the name row is the window's title row, level with the ×
	var head: HBoxContainer = title_label.get_parent()
	head.add_theme_constant_override("separation", 18)
	title_label.visible = false
	_portrait = HudArt.medallion(96, "medallion_ring", 6)
	head.add_child(_portrait)
	head.move_child(_portrait, 0)
	var names := HudArt.vbox(2)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(names)
	head.move_child(names, 1)
	if close_button != null: close_button.size_flags_vertical = SIZE_SHRINK_BEGIN
	_name = HudArt.label("", "h2")
	names.add_child(_name)
	_sub = HudArt.label("", "body", TdTheme.color("cream.300"), 20)
	names.add_child(_sub)
	_health = HudArt.label("", "small", TdTheme.color("cream.200"))
	names.add_child(_health)
	var cols := HudArt.hbox(28)
	body.add_child(cols)
	var left := HudArt.vbox(14)
	left.custom_minimum_size = Vector2(320, 0)
	cols.add_child(left)
	_desc = HudArt.rich("body", TdTheme.color("cream.200"))
	_desc.custom_minimum_size = Vector2(320, 0)
	left.add_child(_desc)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 10)
	left.add_child(_stats)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(ROW_W + 16, 470)
	cols.add_child(scroll)
	_right = HudArt.vbox(14)
	_right.custom_minimum_size = Vector2(ROW_W, 0)
	scroll.add_child(_right)
	visible = false

func _extra_close_key(keys) -> bool:
	return keys.key_pressed(KEY_I)

## Fills it for an entity (as shown now) and opens it.
func show_entity(id: int) -> void:
	var c := controller
	var e: Entity = c.session.state.get_entity(id)
	var f: EntityFrame = c.shown.get_frame(id) if c.shown != null else null
	if e == null or f == null: return
	shown_id = id
	var session := c.session
	var enemy := session.state.effective_team(e) == Teams.Enemy
	var tower_id = session.tower_id_of(e)
	var tdef: TowerDef = session.tower(tower_id) if tower_id != null else null
	HudArt.set_medallion(_portrait, HudArt.portrait(c.converter, e.def), "portrait_ring_enemy" if enemy else "medallion_ring")
	_name.text = f.name
	_name.add_theme_color_override("font_color", TdTheme.color("bad") if enemy else TdTheme.color("accent.light"))
	_sub.text = "Tower · on the board" if tower_id != null else ("Enemy" if enemy else ("Yours" if session.is_commanded(e) else "Neutral"))
	_health.text = "Health  %d / %d" % [f.hp, f.max_hp] + ("   +%d shield" % f.shield if f.shield > 0 else "") if f.has_hp else ""
	var desc: String = tdef.type.description if tdef != null and tdef.type != null and tdef.type.description != "" else e.def.description
	_values = HudText.stat_values(e, session.state.vocab)
	_desc.text = TooltipText.describe(HudText.fill_stats(TooltipText.from_rich(desc), _values))
	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	for t in HudText.stat_tiles(e, e.def, session.state.vocab): _stats.add_child(HudInspector.stat_tile(t, 155))
	for ch in _right.get_children():
		_right.remove_child(ch)
		ch.queue_free()
	_right.add_child(HudArt.label("Abilities", "header", TdTheme.color("cream.100")))
	for a in e.abilities:
		var left: int = f.cooldowns.get(a, 0)
		_right.add_child(_ability_row(a, e, left))
	for p in f.passives:
		_right.add_child(_row(HudArt.passive_icon(c.converter, p.def), p.name, "Passive",
			TooltipText.describe(HudText.fill_stats(p.def.description if p.def != null else "", _values)), [], "Always on" if p.active else "Off", "", p.active))
	# The "Next turn" forecast line is kept out of the Info window too (UI/UX agent, 2026-10-13, pending the user's answer).
	_right.add_child(HudArt.label("Statuses", "header", TdTheme.color("cream.100")))
	var any := false
	for st in f.statuses:
		if st.def != null and st.def.has_tag(Tags.Hidden): continue
		any = true
		_right.add_child(_status_row(st))
	if not any: _right.add_child(HudArt.label("No statuses", "body", TdTheme.color("cream.300")))
	title_label.text = ""
	open()

func _ability_row(a: AbilityDef, e: Entity, left: int) -> Control:
	var c := controller
	var held := left == Entity.HeldCooldown
	var state := TooltipText.ready_in(left, held)
	var tags: Array = AbilityText.tags(a, e, c.session.state.vocab)
	var sub := " · ".join(a.tags)
	var words := TooltipText.cooldown_words(a.cooldown, a.cooldown_until_reset)
	var desc := TooltipText.describe(HudText.fill_stats(a.description, _values))
	var row := _row(HudArt.ability_chip(c.converter, a), a.display_name, sub, desc, tags, state, words, left == 0)
	var tip := TooltipText.ability(a.display_name, HudText.fill_stats(a.description, _values), sub, tags,
		a.cooldown, a.cooldown_until_reset, left, [], a.start_cooldown)
	TdTooltipTrigger.attach(row).set_tooltip(tip)
	row.mouse_entered.connect(func(): c.preview_ability(e, a))
	row.mouse_exited.connect(func(): c.preview_ability(null, null))
	return row

## A Codex-style row (ability-rows mockup): the 88 px icon with its state under it ("Ready" green, else cream) and
## the cooldown words muted, in a 110 px column; name + type line, the full description, the tags as pills.
func _row(icon: Texture2D, title: String, sub: String, desc: String, tags: Array, state: String, words: String, good: bool) -> Control:
	var row := HudArt.hbox(16)
	row.mouse_filter = MOUSE_FILTER_PASS
	var col := HudArt.vbox(4)
	col.custom_minimum_size = Vector2(110, 0)
	row.add_child(col)
	var ic := TdTheme.sprite_rect(icon, Vector2(88, 88))
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(ic)
	var st := HudArt.label(state, "small", TdTheme.color("good") if good else TdTheme.color("cream.100"))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(st)
	if words != "":
		var w := HudArt.label(words, "small", TdTheme.color("cream.300"), 18)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(w)
	var text := HudArt.vbox(6)
	text.custom_minimum_size = Vector2(ROW_W - 126, 0)
	row.add_child(text)
	var head := HudArt.rich("body", TdTheme.color("cream.100"))
	head.text = "[font_size=24][color=%s]%s[/color][/font_size]  [color=%s]%s[/color]" % [TdTheme.rich("gold.light"), title, TdTheme.rich("cream.300"), sub]
	text.add_child(head)
	var d := HudArt.rich("body", TdTheme.color("cream.200"))
	d.text = desc
	text.add_child(d)
	if not tags.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.mouse_filter = MOUSE_FILTER_IGNORE
		text.add_child(flow)
		for t in tags: flow.add_child(_pill(str(t[0]), str(t[1])))
	return row

## One result tag pill: icon + bold number + name.
func _pill(value: String, label: String) -> Control:
	var p := HudArt.panel("badge_key_dark", [10, 3, 12, 3])
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := HudArt.hbox(6)
	p.add_child(h)
	var icon_name := HudArt.tag_icon(label)
	if icon_name != "":
		var ic := HudArt.sprite(icon_name, Vector2(18, 18), TdTheme.color("cream.300"))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
	h.add_child(HudArt.label(value, "micro", TdTheme.color("cream.100"), 20))
	var n := HudArt.label(label, "small", TdTheme.color("cream.200"), 18)
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(n)
	return p

func _status_row(st: StatusView) -> Control:
	var chip := TdIconChip.new()
	chip.chip_size = 48
	chip.custom_minimum_size = Vector2(48, 48)
	var shield: bool = st.def != null and st.def.stacks_are_shield
	var harmful: bool = st.def != null and st.def.has_tag(Tags.Debuff)
	var helpful: bool = st.def != null and st.def.has_tag(Tags.Buff)
	var rounds: bool = st.def != null and st.def.duration_unit == DurationUnit.Rounds
	var row := HudArt.hbox(16)
	var col := HudArt.vbox(0)
	col.custom_minimum_size = Vector2(110, 0)
	row.add_child(col)
	chip.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(chip)
	chip.set_icon(HudArt.status_icon(controller.converter, st.def))
	chip.set_status(st.turns_left, st.shield if shield and st.shield > 0 else st.stacks, shield)
	var text := HudArt.vbox(2)
	text.custom_minimum_size = Vector2(ROW_W - 126, 0)
	row.add_child(text)
	var col_name := "bad" if harmful else ("good" if helpful else "status")
	var head := HudArt.rich("body")
	head.text = "[font_size=24][color=%s]%s[/color][/font_size]" % [TdTheme.rich(col_name), st.name]
	text.add_child(head)
	var d := HudArt.rich("body", TdTheme.color("cream.200"))
	d.text = TooltipText.describe(HudText.status_description(st.def.description if st.def != null else "", st.stacks, st.turns_left))
	text.add_child(d)
	var line := ""
	if st.turns_left >= 0: line = TooltipText.turns(st.turns_left, "round" if rounds else "turn") + " left"
	if not st.applied_by.is_empty(): line += (" · " if line != "" else "") + "applied by " + ", ".join(st.applied_by)
	if line != "": text.add_child(HudArt.label(line, "small", TdTheme.color("cream.300")))
	return row
