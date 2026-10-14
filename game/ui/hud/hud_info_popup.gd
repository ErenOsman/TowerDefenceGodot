class_name HudInfoPopup
extends HudPopup
## The Tower / Enemy Info window, laid out like the Unity build's (reference/unity-build/info-window-tower.png, about
## 1004 × 669): a wood window whose header holds the name (Plinth, cream; red for an enemy) over its subtitle ("Tower ·
## on the board", "Enemy", "Yours"), a Codex button (opens the menus agent's Codex at this entry, when it exists), the
## Health label, number and bar, and ×. The body is one paper card: left, the turning model (TdModelPreview, "‹ Drag
## to turn ›") with the 2-column stat tiles under it; right (scrolls), the description, "Abilities" with a rule, one
## row per ability (88 px icon, the cooldown pips and the state under it: "Ready" green / "In 1 turn", the cooldown
## words; name in gold Plinth, the tags line, the description with bold numbers, one pill per result tag), passives in
## the same rows, and Statuses when there are any. Esc, right click or × close it; `I` too.

const CODEX_SCENE := "res://game/ui/screens/codex.tscn"
const WIDTH := 1004.0
const LEFT_W := 276.0
const RIGHT_W := 560.0
const BODY_H := 488.0

var shown_id := -1
var _name: Label
var _sub: Label
var _codex: TdButton
var _health_box: VBoxContainer
var _health_value: Label
var _hp: TdHealthBar
var _model: TdModelPreview
var _stats: GridContainer
var _right: VBoxContainer
var _values := {}
var _codex_target := []
var _rim: Panel

func _ready() -> void:
	make("", WIDTH, true)
	var head: HBoxContainer = title_label.get_parent()
	head.add_theme_constant_override("separation", 24)
	title_label.visible = false
	var names := HudArt.vbox(0)
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(names)
	head.move_child(names, 0)
	_name = HudArt.label("", "h1", TdTheme.color("cream.100"), 40)
	names.add_child(_name)
	_sub = HudArt.label("", "small", TdTheme.color("cream.300"))
	names.add_child(_sub)
	_codex = TdButton.new()
	_codex.style = TdButton.Style.SECONDARY
	_codex.custom_minimum_size = Vector2(120, 48)
	_codex.size = Vector2(120, 48)
	_codex.text = "Codex"
	_codex.font_size = 24
	_codex.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(_codex)
	head.move_child(_codex, 1)
	_codex.clicked.connect(_open_codex)
	_health_box = HudArt.vbox(8)
	_health_box.custom_minimum_size = Vector2(300, 0)
	_health_box.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(_health_box)
	head.move_child(_health_box, 2)
	var hrow := HudArt.hbox(8)
	_health_box.add_child(hrow)
	var heart := HudArt.sprite("icon_heart", Vector2(20, 20), TdTheme.color("good"))
	heart.size_flags_vertical = SIZE_SHRINK_CENTER
	hrow.add_child(heart)
	var hl := HudArt.label("Health", "small", TdTheme.color("cream.200"))
	hl.size_flags_horizontal = SIZE_EXPAND_FILL
	hrow.add_child(hl)
	_health_value = HudArt.label("", "micro", TdTheme.color("cream.100"), 24)
	hrow.add_child(_health_value)
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(300, 14)
	bar_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_health_box.add_child(bar_holder)
	_hp = TdHealthBar.new()
	_hp.size = Vector2(300, 14)
	bar_holder.add_child(_hp)
	if close_button != null: close_button.size_flags_vertical = SIZE_SHRINK_CENTER
	# body: the paper card
	var card := HudArt.panel("paper_card", [20, 16, 12, 16])
	card.mouse_filter = MOUSE_FILTER_PASS
	body.add_child(card)
	var cols := HudArt.hbox(28)
	card.add_child(cols)
	var left := HudArt.vbox(14)
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	cols.add_child(left)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", _box(TdTheme.color("paper.2").darkened(0.12), TdTheme.color("ink.2"), 10, 2))
	stage.custom_minimum_size = Vector2(LEFT_W, 256)
	stage.mouse_filter = MOUSE_FILTER_PASS
	left.add_child(stage)
	var stage_v := HudArt.vbox(0)
	stage.add_child(stage_v)
	_model = TdModelPreview.new()
	_model.custom_minimum_size = Vector2(LEFT_W - 8, 214)
	stage_v.add_child(_model)
	var cap := HudArt.label("‹   Drag to turn   ›", "body", TdTheme.color("ink.2"), 20)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_v.add_child(cap)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 10)
	left.add_child(_stats)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(RIGHT_W + 20, BODY_H)
	cols.add_child(scroll)
	TdDragScroll.attach(scroll, true) # a visible paper scrollbar (Statuses can be below the fold), drag to scroll
	_right = HudArt.vbox(16)
	_right.custom_minimum_size = Vector2(RIGHT_W, 0)
	scroll.add_child(_right)
	# the enemy window's red rim
	_rim = Panel.new()
	_rim.mouse_filter = MOUSE_FILTER_IGNORE
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = TdTheme.color("bad")
	rim.set_border_width_all(3)
	rim.set_corner_radius_all(24)
	rim.anti_aliasing = true
	_rim.add_theme_stylebox_override("panel", rim)
	_rim.visible = false
	add_child(_rim)
	visible = false

func _process(delta: float) -> void:
	super._process(delta)
	if panel == null or _rim == null: return
	_rim.position = panel.position - Vector2(2, 2)
	_rim.size = panel.size + Vector2(4, 4)
	_rim.scale = panel.scale
	_rim.pivot_offset = _rim.size / 2.0
	_rim.modulate.a = panel.modulate.a

static func _box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b

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
	_name.text = f.name
	_name.add_theme_color_override("font_color", TdTheme.color("bad") if enemy else TdTheme.color("cream.100"))
	_sub.text = "Tower · on the board" if tower_id != null else ("Enemy" if enemy else ("Yours" if session.is_commanded(e) else "Neutral"))
	_health_box.visible = f.has_hp
	if f.has_hp:
		_health_value.text = "%d / %d" % [f.hp, f.max_hp]
		_hp.set_health_immediate(f.hp, f.max_hp)
	# the Codex entry: the tower type, or the enemy's asset
	var asset = c.converter.asset_of(e.def, "EntityAsset") if c.converter != null else null
	_codex_target = []
	if tdef != null and tdef.type != null: _codex_target = [CodexSection.Towers, tdef.type.id]
	elif enemy and asset != null: _codex_target = [CodexSection.Enemies, asset.get_id()]
	_codex.visible = ResourceLoader.exists(CODEX_SCENE) and not _codex_target.is_empty() and not c.is_tutorial
	# the model
	var app = get_tree().root.get_node_or_null("GameApp")
	var scene: PackedScene = app.model_scene(asset.view) if app != null and asset != null and asset.view != "" else null
	if scene != null: _model.show_model(scene)
	else: _model.clear()
	# stats
	_values = HudText.stat_values(e, session.state.vocab)
	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	for t in HudText.stat_tiles(e, e.def, session.state.vocab): _stats.add_child(HudInspector.stat_tile(t, (LEFT_W - 10.0) / 2.0))
	# right column
	for ch in _right.get_children():
		_right.remove_child(ch)
		ch.queue_free()
	var desc: String = tdef.type.description if tdef != null and tdef.type != null and tdef.type.description != "" else e.def.description
	if desc != "":
		var d := _ink_text("body", 22)
		d.text = TooltipText.describe(HudText.fill_stats(TooltipText.from_rich(desc), _values))
		_right.add_child(d)
	_right.add_child(_heading("Abilities", enemy))
	var first := true
	for a in e.abilities:
		if not first: _right.add_child(_rule())
		first = false
		_right.add_child(_ability_row(a, e, f.cooldowns.get(a, 0)))
	for p in f.passives:
		if not first: _right.add_child(_rule())
		first = false
		_right.add_child(_row(HudArt.passive_icon(c.converter, p.def), p.name, "Passive",
			TooltipText.describe(HudText.fill_stats(p.def.description if p.def != null else "", _values)), [],
			null, "Always on" if p.active else "Off", "", p.active))
	var statuses := []
	for st in OverlayStyle.ordered_statuses(f.statuses):
		if st.def == null or not st.def.has_tag(Tags.Hidden): statuses.append(st)
	_right.add_child(_heading("Statuses", enemy))
	if statuses.is_empty():
		_right.add_child(HudArt.label("No statuses", "body", TdTheme.color("ink.2")))
	for st in statuses: _right.add_child(_status_row(st))
	_rim.visible = enemy
	open()

func _open_codex() -> void:
	if _codex_target.is_empty() or not ResourceLoader.exists(CODEX_SCENE): return
	var n: Node = (load(CODEX_SCENE) as PackedScene).instantiate()
	get_parent().add_child(n)
	if n is Control: (n as Control).set_anchors_preset(PRESET_FULL_RECT)
	if n.has_signal("closed"): n.closed.connect(func(): if is_instance_valid(n): n.queue_free())
	if n.has_method("open_at"): n.open_at(_codex_target[0], _codex_target[1])
	elif n.has_method("open"): n.open()

# ------------------------------------------------------------------ parts

func _ink_text(role: String, size := 0) -> RichTextLabel:
	var r := HudArt.rich(role, TdTheme.color("ink"), size)
	r.custom_minimum_size = Vector2(RIGHT_W, 0)
	return r

func _heading(text: String, enemy: bool) -> Control:
	var h := HudArt.hbox(18)
	var l := HudArt.label(text, "h3", TdTheme.color("bad.ink") if enemy else TdTheme.color("ink"))
	h.add_child(l)
	var line := ColorRect.new()
	line.color = Color(TdTheme.color("bad.ink") if enemy else TdTheme.color("ink.2"), 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = SIZE_EXPAND_FILL
	line.size_flags_vertical = SIZE_SHRINK_CENTER
	line.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(line)
	return h

func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(TdTheme.color("ink.2"), 0.35)
	line.custom_minimum_size = Vector2(RIGHT_W, 2)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	return line

func _ability_row(a: AbilityDef, e: Entity, left: int) -> Control:
	var c := controller
	var held := left == Entity.HeldCooldown
	var tags: Array = HudText.shown_tags(AbilityText.tags(a, e, c.session.state.vocab))
	var sub := " · ".join(a.tags)
	var state := TooltipText.ready_in(left, held)
	var words := TooltipText.cooldown_words(a.cooldown, a.cooldown_until_reset)
	var desc := TooltipText.describe(HudText.fill_stats(a.description, _values))
	var row := _row(HudArt.ability_chip(c.converter, a), a.display_name, sub, desc, tags, [left, held, a.cooldown], state, words, left == 0 and not held)
	var tip := TooltipText.ability(a.display_name, HudText.fill_stats(a.description, _values), sub, tags,
		a.cooldown, a.cooldown_until_reset, left, [], a.start_cooldown)
	TdTooltipTrigger.attach(row).set_tooltip(tip)
	row.mouse_entered.connect(func(): c.preview_ability(e, a))
	row.mouse_exited.connect(func(): c.preview_ability(null, null))
	return row

## The cooldown pips under an ability's icon: one per cooldown turn (up to 3), lit (ready) for the turns recovered;
## a held cooldown shows locked pips.
static func pip_names(left: int, held: bool, cooldown: int) -> Array:
	var n := clampi(cooldown, 1, 3)
	var out := []
	var total := maxi(1, cooldown)
	var recovered := n if left <= 0 else (total - left if total <= 3 else int(floor(3.0 * float(total - left) / float(total))))
	for i in n:
		if held: out.append("pip_mini_held")
		else: out.append("pip_mini_ready" if i < recovered else "pip_mini_wait")
	return out

## One row: the 88 px icon with the pips (cd = [left, held, cooldown] or null) and the state under it, in a 120 px
## column; name (gold Plinth), the tags line, the description, one pill per result tag.
func _row(icon: Texture2D, title: String, sub: String, desc: String, tags: Array, cd, state: String, words: String, good: bool) -> Control:
	var row := HudArt.hbox(18)
	row.mouse_filter = MOUSE_FILTER_PASS
	var col := HudArt.vbox(4)
	col.custom_minimum_size = Vector2(120, 0)
	row.add_child(col)
	var ic := TdTheme.sprite_rect(icon, Vector2(88, 88))
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(ic)
	if cd != null:
		var pips := HudArt.hbox(4)
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(pips)
		for n in pip_names(cd[0], cd[1], cd[2]): pips.add_child(HudArt.sprite(n, Vector2(22, 22)))
	var st := HudArt.label(state, "small", TdTheme.color("good.ink") if good else TdTheme.color("ink"))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(st)
	if words != "":
		var w := HudArt.label(words, "small", TdTheme.color("ink"), 18)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(w)
	var text := HudArt.vbox(4)
	text.custom_minimum_size = Vector2(RIGHT_W - 138, 0)
	row.add_child(text)
	text.add_child(HudArt.label(title, "h3", TdTheme.color("gold.ink")))
	if sub != "": text.add_child(HudArt.label(sub, "small", TdTheme.color("ink.2")))
	var d := HudArt.rich("body", TdTheme.color("ink"))
	d.custom_minimum_size = Vector2(RIGHT_W - 138, 0)
	d.text = desc
	text.add_child(d)
	if not tags.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 8)
		flow.mouse_filter = MOUSE_FILTER_IGNORE
		text.add_child(flow)
		for t in tags: flow.add_child(_pill(str(t[0]), str(t[1])))
	return row

## One result tag pill (tan, the number bold): "10 Damage".
func _pill(value: String, label: String) -> Control:
	var p := PanelContainer.new()
	var box := _box(TdTheme.color("paper.2").darkened(0.18), TdTheme.color("gold.dark"), 8, 2)
	box.content_margin_left = 12; box.content_margin_right = 14; box.content_margin_top = 2; box.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = Vector2(146, 0)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := HudArt.hbox(6)
	p.add_child(h)
	var icon_name := HudArt.tag_icon(label)
	if icon_name != "":
		var ic := HudArt.sprite(icon_name, Vector2(18, 18), TdTheme.color("ink.2"))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
	h.add_child(HudArt.label(value, "micro", TdTheme.color("ink"), 22))
	var n := HudArt.label(label, "small", TdTheme.color("ink.2"), 18)
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
	var row := HudArt.hbox(18)
	var col := HudArt.vbox(0)
	col.custom_minimum_size = Vector2(120, 0)
	row.add_child(col)
	chip.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(chip)
	chip.set_icon(HudArt.status_icon(controller.converter, st.def))
	chip.set_status(st.turns_left, st.shield if shield and st.shield > 0 else st.stacks, shield)
	var text := HudArt.vbox(2)
	text.custom_minimum_size = Vector2(RIGHT_W - 138, 0)
	row.add_child(text)
	text.add_child(HudArt.label(st.name, "h3", TdTheme.color("bad.ink") if harmful else (TdTheme.color("good.ink") if helpful else TdTheme.color("status.ink"))))
	var d := HudArt.rich("body", TdTheme.color("ink"))
	d.custom_minimum_size = Vector2(RIGHT_W - 138, 0)
	d.text = TooltipText.describe(HudText.status_description(st.def.description if st.def != null else "", st.stacks, st.turns_left))
	text.add_child(d)
	var line := ""
	if st.turns_left >= 0: line = TooltipText.turns(st.turns_left, "round" if rounds else "turn") + " left"
	if not st.applied_by.is_empty(): line += (" · " if line != "" else "") + "applied by " + ", ".join(st.applied_by)
	if line != "": text.add_child(HudArt.label(line, "small", TdTheme.color("ink.2")))
	return row
