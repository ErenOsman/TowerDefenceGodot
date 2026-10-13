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

func _ready() -> void:
	make("", 960, true)
	var head := HudArt.hbox(18)
	body.add_child(head)
	body.move_child(head, 0)
	_portrait = HudArt.medallion(96, "medallion_ring", 6)
	head.add_child(_portrait)
	var names := HudArt.vbox(2)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
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
	panel.add_theme_stylebox_override("panel", TdTheme.stylebox("panel_wood_enemy" if enemy else "window_frame", Color.WHITE, [32, 32, 32, 32]))
	HudArt.set_medallion(_portrait, HudArt.portrait(c.converter, e.def), "portrait_ring_enemy" if enemy else "medallion_ring")
	_name.text = f.name
	_name.add_theme_color_override("font_color", TdTheme.color("bad") if enemy else TdTheme.color("accent.light"))
	_sub.text = "Tower · on the board" if tower_id != null else ("Enemy" if enemy else ("Yours" if session.is_commanded(e) else "Neutral"))
	_health.text = "Health  %d / %d" % [f.hp, f.max_hp] + ("   +%d shield" % f.shield if f.shield > 0 else "") if f.has_hp else ""
	var desc: String = tdef.type.description if tdef != null and tdef.type != null and tdef.type.description != "" else e.def.description
	_desc.text = TooltipText.from_rich(desc)
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
			TooltipText.describe(p.def.description if p.def != null else ""), "", "Always on" if p.active else "Off", p.active))
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
	var tags := TooltipText.tag_line(AbilityText.tags(a, e, c.session.state.vocab))
	var sub := " · ".join(a.tags)
	var words := TooltipText.cooldown_words(a.cooldown, a.cooldown_until_reset)
	var row := _row(HudArt.ability_chip(c.converter, a), a.display_name, sub, TooltipText.describe(a.description), tags,
		state + "\n" + words, left == 0)
	var tip := TooltipText.ability(a.display_name, a.description, sub, AbilityText.tags(a, e, c.session.state.vocab),
		a.cooldown, a.cooldown_until_reset, left, [], a.start_cooldown)
	TdTooltipTrigger.attach(row).set_tooltip(tip)
	row.mouse_entered.connect(func(): c.preview_ability(e, a))
	row.mouse_exited.connect(func(): c.preview_ability(null, null))
	return row

## A Codex-style row: icon (64) with the state under it in a 110 px column; name + type line, description, tags.
func _row(icon: Texture2D, title: String, sub: String, desc: String, tags: String, state: String, good: bool) -> Control:
	var row := HudArt.hbox(16)
	row.mouse_filter = MOUSE_FILTER_PASS
	var col := HudArt.vbox(6)
	col.custom_minimum_size = Vector2(110, 0)
	row.add_child(col)
	var ic := TdTheme.sprite_rect(icon, Vector2(64, 64))
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(ic)
	var st := HudArt.label(state, "small", TdTheme.color("good") if good else TdTheme.color("cream.300"))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(st)
	var text := HudArt.vbox(4)
	text.custom_minimum_size = Vector2(ROW_W - 126, 0)
	row.add_child(text)
	var head := HudArt.rich("body", TdTheme.color("cream.100"))
	head.text = "[font_size=24][color=%s]%s[/color][/font_size]  [color=%s]%s[/color]" % [TdTheme.rich("gold.light"), title, TdTheme.rich("cream.300"), sub]
	text.add_child(head)
	var d := HudArt.rich("body", TdTheme.color("cream.200"))
	d.text = desc
	text.add_child(d)
	if tags != "":
		var t := HudArt.rich("small", TdTheme.color("cream.100"))
		t.text = tags
		text.add_child(t)
	return row

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
