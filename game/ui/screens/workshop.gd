extends TdPopup
## The Workshop (Workshop — Design; mockups ~/uiux/mockups/screens-b/workshop*.html, js/workshop.js): the Camp
## station where a tower turns into one of its forms, unlocked with tokens, per individual tower.
##  Step 1, the picker: "Workshop · Pick a tower to modify", the collection of Hand select without the hand row
##  (TdCollection: search, Role / Delivery / Cost, Sort, the grid with form badges) and a detail card (name,
##  "#1 · tower 3", energy, "Form of Archer · 1 of 4 forms unlocked", description, stat tiles, abilities, Modify).
##  Modify or a double click slides the Modify view in from the right (0.35 s; the picker slides out left).
##  Step 2, the Modify view: "← Back Esc", the tower's name, every token kind with its count (tooltip: name,
##  description, where it drops); left "This tower now"; centre the forms tree (root = the default form in the
##  middle, children by FormDef.order, grandchildren beyond their parent; node states Current / Unlocked / Can
##  unlock / Needs tokens / locked; legend); right the selected node's card (the form as it is: description, stat
##  tiles, abilities and passives; "Leads to", the unlock cost, ONE action: Unlock → confirm, Use this form, or the
##  reason it cannot). No comparison between forms (user decision 2026-10-14).
## Keys: Esc / right click = Back (confirm → cancel; Modify → picker; picker → close), arrows move between nodes,
## Enter = the card's action (confirm: Enter = Unlock). Every change saves through SaveData at once.
## The texts and rules are WorkshopLogic's and Workshop's; this script only builds and wires nodes.

signal changed

const WIN := Vector2(1460, 864)
const PAD := 22.0
const SLIDE_TIME := 0.35
## The Modify view's columns (mockup grid 330px 1fr 380px).
const NOW_W := 344.0
const CARD_W := 380.0
const NODE_MEDAL := 96.0
const COBALT := Color("#3A6BB0")
const COBALT_LINE := Color("#6AA2EC")
const GOLD_RING := Color("#FFD46B")
const SHORT := Color("#FF7A6B")
const OK := Color("#7EE08A")
const TITLE_INK := Color("#2B5594")
## The paper cards' lower colour (the bottom fade of their scrolling body).
const PAPER_FADE := Color("#EADDC2")

## "pick" or "modify".
var view := "pick"
## The owned tower picked / being modified.
var tower_id := ""
## The selected node of the tree (a form id; "" = the default form).
var node_id := ""
## A node just unlocked (its toast shows until another node is picked or 4 s pass).
var flash_id := ""
var confirm_open := false
var _confirm_at := -100000

var collection: TdCollection
var _entries: Array = []
var _type: TowerType = null
var _found := {}   # token id → "Found in" text
var _vocab: Vocabulary

var _clip: Control
var _slider: Control
var _pick: VBoxContainer
var _mod: VBoxContainer
var _pdetail: VBoxContainer
var _mname: HBoxContainer
var _tokens: HBoxContainer
var _now: VBoxContainer
var _tree: FormTree
var _card: VBoxContainer
var _confirm: Control
var _confirm_box: VBoxContainer
var _toast_serial := 0
var _slide_tween: Tween

# ------------------------------------------------------------------ build

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, PAD)
	p.custom_minimum_size = WIN
	center.add_child(p)
	window = p
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(_clip)
	_slider = Control.new()
	_slider.mouse_filter = MOUSE_FILTER_IGNORE
	_clip.add_child(_slider)
	_pick = TdMenu.vbox(14)
	_slider.add_child(_pick)
	_mod = TdMenu.vbox(14)
	_slider.add_child(_mod)
	_clip.resized.connect(_layout_panes)
	_build_pick()
	_build_mod()
	_build_confirm()

func _layout_panes() -> void:
	var s := _clip.size
	_pick.position = Vector2.ZERO
	_pick.size = s
	_mod.position = Vector2(s.x + PAD * 2.0, 0)
	_mod.size = s
	if _slide_tween == null or not _slide_tween.is_running(): _slider.position.x = _slide_x()

func _slide_x() -> float:
	return 0.0 if view == "pick" else -(_clip.size.x + PAD * 2.0)

func _build_pick() -> void:
	var head := TdMenu.hbox(14)
	_pick.add_child(head)
	head.add_child(TdMenu.label("Workshop", "h1", TdTheme.color("cream.100"), 44))
	var sub := TdMenu.label("Pick a tower to modify", "small", TdTheme.color("cream.300"), 22)
	sub.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(sub)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(fill)
	var x := TdMenu.close_button()
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	var body := TdMenu.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	_pick.add_child(body)
	collection = TdCollection.new()
	collection.extras = false
	collection.hand_keys = false
	collection.filter_width = 224.0
	collection.tile_size = TdTowerTile.WIDE
	collection.gap = 8
	collection.build()
	collection.selected.connect(_pick_tower)
	collection.activated.connect(open_modify)
	body.add_child(collection)
	var paper := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	paper.custom_minimum_size = Vector2(360, 0)
	_pdetail = TdMenu.vbox(10)
	paper.add_child(_pdetail)
	body.add_child(paper)

func _build_mod() -> void:
	var top := TdMenu.hbox(20)
	top.custom_minimum_size = Vector2(0, 56)
	_mod.add_child(top)
	var back_b := TdMenu.button(TdButton.Style.SECONDARY, "Back", Vector2(190, 52), TdTheme.texture("icon_back"))
	back_b.set_key_hint("Esc")
	back_b.size_flags_vertical = SIZE_SHRINK_CENTER
	back_b.clicked.connect(back_to_picker)
	top.add_child(back_b)
	_mname = TdMenu.hbox(10)
	_mname.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(_mname)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(fill)
	_tokens = TdMenu.hbox(8)
	_tokens.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(_tokens)
	var body := TdMenu.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	_mod.add_child(body)
	var left := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	left.custom_minimum_size = Vector2(NOW_W, 0)
	left.padding = 14
	_now = TdMenu.vbox(10)
	left.add_child(_now)
	body.add_child(left)
	var well := TdMenu.panel(TdPanel.Kind.WELL, 0)
	well.size_flags_horizontal = SIZE_EXPAND_FILL
	_tree = FormTree.new()
	_tree.screen = self
	well.add_child(_tree)
	body.add_child(well)
	var right := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	right.custom_minimum_size = Vector2(CARD_W, 0)
	_card = TdMenu.vbox(8)
	right.add_child(_card)
	body.add_child(right)

func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_confirm.mouse_filter = MOUSE_FILTER_STOP
	_confirm.visible = false
	add_child(_confirm)
	var sc := TdScrim.new()
	# not the second click of a double click on Unlock (it landed on the scrim and cancelled at once; QA 2026-10-15)
	sc.clicked.connect(func(_b: int): if Time.get_ticks_msec() - _confirm_at > TdPopup.SCRIM_GRACE_MS: cancel_confirm())
	_confirm.add_child(sc)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	_confirm.add_child(c)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 30)
	p.custom_minimum_size = Vector2(760, 0)
	c.add_child(p)
	_confirm_box = TdMenu.vbox(12)
	_confirm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(_confirm_box)

# ------------------------------------------------------------------ open / data

func _on_open() -> void:
	_vocab = GameApp.rules.vocabulary if GameApp.rules != null else null
	_found.clear()
	for t in GameApp.catalog.tokens: _found[t.get_id()] = WorkshopLogic.found_in_text(t.get_id(), GameApp.missions())
	view = "pick"
	confirm_open = false
	_confirm.visible = false
	_reload_entries()
	if tower_id == "" or SaveData.towers.find(tower_id) == null:
		tower_id = _entries[0].id if not _entries.is_empty() else ""
	_refresh_pick()
	_layout_panes.call_deferred()

func _reload_entries() -> void:
	_entries = HandLogic.entries(SaveData.towers, GameApp.catalog, GameApp.convert)

func _entry(id: String) -> Dictionary:
	for e in _entries:
		if e.id == id: return e
	return {}

func _owned() -> OwnedTower:
	return SaveData.towers.find(tower_id)

# ------------------------------------------------------------------ the picker

func _refresh_pick() -> void:
	collection.entries = _entries
	collection.hand = SaveData.towers.hand
	collection.selected_id = tower_id
	collection.refresh()
	_refresh_pdetail()

func _pick_tower(id: String) -> void:
	tower_id = id
	_refresh_pdetail()

func _refresh_pdetail() -> void:
	TdCollection.clear_children(_pdetail)
	var e := _entry(tower_id)
	var owned := _owned()
	if e.is_empty() or owned == null:
		var l := TdMenu.wrap_label("Select a tower to see its details.", "body", TdTheme.color("ink.2"), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_vertical = SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_pdetail.add_child(l)
		return
	var type := GameApp.tower_type(owned.type)
	var body := _scroll_body(_pdetail)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 10)
	head.add_child(TdMenu.label(e.name, "h2", TdTheme.color("accent.ink"), 32))
	body.add_child(head)
	body.add_child(TdMenu.label(HandLogic.number_text(e), "micro", TdTheme.color("ink.2"), 18))
	body.add_child(TdMenu.rich("[img=20x20 color=%s]%s[/img] [font_size=22][color=%s]%d[/color][/font_size] energy" % [TdTheme.rich("gold.ink"),
		TdTheme.texture("icon_energy").resource_path, TdTheme.rich("gold.ink"), e.cost], "small", TdTheme.color("ink.2"), 18))
	body.add_child(_bold_digits(WorkshopLogic.form_line(owned, type), 18))
	if e.description != "": body.add_child(TdMenu.rich(TooltipText.describe(e.description), "body", TdTheme.color("ink"), 18))
	_def_section(body, e.def)
	var b := TdMenu.button(TdButton.Style.PRIMARY, "Modify", Vector2(0, 58), TdTheme.texture("icon_edit"))
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.clicked.connect(func(): open_modify(tower_id))
	_pdetail.add_child(b)

## A ScrollContainer filling a column, holding a vbox (returned) with room for the scrollbar.
func _scroll_body(parent: Control, sep := 10, gutter_px := 12, fade := false) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	if fade:
		# the Modify cards: no scrollbar line; a fade at the bottom says there is more (wheel / drag scrolls)
		TdDragScroll.attach(scroll, true)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # after attach (it sets AUTO)
		var holder := Control.new()
		holder.size_flags_vertical = SIZE_EXPAND_FILL
		holder.size_flags_horizontal = SIZE_EXPAND_FILL
		holder.mouse_filter = MOUSE_FILTER_PASS
		parent.add_child(holder)
		scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		holder.add_child(scroll)
		var f := TextureRect.new()
		var g := Gradient.new()
		g.set_color(0, Color(PAPER_FADE, 0.0))
		g.set_color(1, PAPER_FADE)
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 32
		f.texture = gt
		f.stretch_mode = TextureRect.STRETCH_SCALE
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.mouse_filter = MOUSE_FILTER_IGNORE
		f.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		f.offset_top = -28
		holder.add_child(f)
		var upd := func() -> void:
			var bar := scroll.get_v_scroll_bar()
			f.visible = bar.max_value - bar.page > 1.0 and scroll.scroll_vertical < bar.max_value - bar.page - 1.0
		scroll.get_v_scroll_bar().changed.connect(upd)
		scroll.get_v_scroll_bar().value_changed.connect(func(_v): upd.call())
	else:
		parent.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", gutter_px)
	if fade:
		# the head medallion's ring hangs ~5 px outside its rect: room for it inside the scroll's clip (QA 2026-10-14)
		gutter.add_theme_constant_override("margin_left", 6)
		gutter.add_theme_constant_override("margin_top", 6)
	gutter.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(gutter)
	var body := TdMenu.vbox(sep)
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	gutter.add_child(body)
	return body

## A line with its numbers bold ("Form of Archer · 1 of 4 forms unlocked").
func _bold_digits(text: String, size: int) -> RichTextLabel:
	var re := RegEx.create_from_string("(\\d+)")
	var t := re.sub(text, "[color=%s][b]$1[/b][/color]" % TdTheme.rich("ink"), true)
	var r := TdMenu.rich(t, "body", TdTheme.color("ink.2"), size)
	r.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
	return r

# ------------------------------------------------------------------ the Modify view

## Opens the Modify view for a tower (slides in from the right).
func open_modify(id: String) -> void:
	var owned := SaveData.towers.find(id)
	if owned == null: return
	tower_id = id
	collection.selected_id = id
	_type = GameApp.tower_type(owned.type)
	node_id = WorkshopLogic.current_id(owned, _type)
	flash_id = ""
	view = "modify"
	refresh_modify()
	_slide()

## Back to the picker (slides back).
func back_to_picker() -> void:
	if view != "modify": return
	view = "pick"
	confirm_open = false
	_confirm.visible = false
	_refresh_pick()
	_slide()

func _slide() -> void:
	if _slide_tween != null: _slide_tween.kill()
	_slide_tween = TdTheme.tween(_slider)
	_slide_tween.tween_property(_slider, "position:x", _slide_x(), SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Redraws the whole Modify view.
func refresh_modify() -> void:
	var owned := _owned()
	if owned == null or _type == null: return
	var e := _entry(tower_id)
	# header: name + number, tokens
	TdCollection.clear_children(_mname)
	var n := TdMenu.label(e.get("name", ""), "h1", TdTheme.color("accent.light"), 34)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	_mname.add_child(n)
	var num := TdMenu.label(HandLogic.number_text(e), "header", TdTheme.color("cream.300"), 20)
	num.add_theme_font_override("font", TdTheme.font("plinth"))
	num.size_flags_vertical = SIZE_SHRINK_END
	_mname.add_child(num)
	_refresh_tokens()
	_refresh_now()
	_tree.rebuild()
	_refresh_card()

func _refresh_tokens() -> void:
	TdCollection.clear_children(_tokens)
	for t in GameApp.catalog.tokens:
		var id: String = t.get_id()
		var have: int = SaveData.tokens.count(id)
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.067, 0.05, 0.7)
		sb.border_color = TdTheme.color("rim")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(22)
		sb.content_margin_left = 5; sb.content_margin_right = 12; sb.content_margin_top = 4; sb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", sb)
		chip.custom_minimum_size = Vector2(0, 44)
		chip.mouse_filter = MOUSE_FILTER_STOP
		var h := TdMenu.hbox(6)
		h.mouse_filter = MOUSE_FILTER_IGNORE
		chip.add_child(h)
		var ic := TdMenu.picture(GameApp.kit_texture(t.icon), Vector2(32, 32))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := TdMenu.label(str(have), "header", TdTheme.color("cream.100") if have > 0 else TdTheme.color("cream.300"), 22)
		l.add_theme_font_override("font", TdTheme.font("plinth"))
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(l)
		if have == 0: chip.modulate.a = 0.6
		var where: String = _found.get(id, "")
		TdTooltipTrigger.attach(chip, TooltipText.title(t.get_display_name(), TooltipText.value_color(), "Token"),
			t.description + ("\nFound in: %s." % where if where != "" else ""), "You have", str(have))
		_tokens.add_child(chip)

func _portrait(id: String) -> Texture2D:
	var fa: FormAsset = GameApp.catalog.find_form(id) if id != "" else null
	if fa != null: return TdMenu.unit_picture(fa.entity.view if fa.entity != null else "", fa.icon)
	return TdCollection.portrait(GameApp.catalog.find_tower(_type.id) if _type != null else null)

func _badge(id: String) -> String:
	var f := WorkshopLogic.form_of(_type, id)
	if f == null or f.badge == "": return ""
	var p := ArtPaths.kit(f.badge)
	return p if p != "" and ResourceLoader.exists(p) else ""

## A medallion of a node with its form badge and tint ring.
func _medal(id: String, d: float) -> Control:
	return TdTowerCard.medallion(_portrait(id), d, _badge(id))

func _refresh_now() -> void:
	TdCollection.clear_children(_now)
	var owned := _owned()
	var cur := WorkshopLogic.current_id(owned, _type)
	var e := _entry(tower_id)
	var body := _scroll_body(_now, 8, 0, true)
	body.add_child(_caption("This tower now"))
	var head := TdMenu.hbox(14)
	body.add_child(head)
	var m := _medal(cur, 76)
	m.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(m)
	var v := TdMenu.vbox(0)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(v)
	var n := TdMenu.wrap_label(e.get("name", ""), "h2", TITLE_INK, 28)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	v.add_child(n)
	var num := TdMenu.label(HandLogic.number_text(e), "header", TdTheme.color("ink.2"), 18)
	num.add_theme_font_override("font", TdTheme.font("plinth"))
	v.add_child(num)
	var line := WorkshopLogic.now_line(owned, _type)
	var fl := TdMenu.rich("%s [color=%s][b]%s[/b][/color]" % [line.get_slice(":", 0) + ":", TdTheme.rich("ink"), line.get_slice(": ", 1)], "body", TdTheme.color("ink.2"), 18)
	fl.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
	v.add_child(fl)
	_def_section(body, WorkshopLogic.def_of(_type, cur))

## The same structure on both Modify cards (and the picker card): the stat tiles, the ⓘ trait lines ("Burn on hit"),
## an "Abilities" caption, the abilities, then the passives (square chips).
func _def_section(body: VBoxContainer, def: EntityDef) -> void:
	if def == null: return
	if _vocab != null: body.add_child(TdTowerCard.stat_grid(HandLogic.stat_tiles(DefStats.new(def), _vocab, 4), 120))
	for line in WorkshopLogic.trait_lines(def, _vocab):
		var tl := TdMenu.rich("[img=18x18 color=%s]%s[/img]  %s" % [TdTheme.rich("ink.2"), TdTheme.texture("icon_info").resource_path, line],
			"body", TdTheme.color("ink"), 18)
		tl.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
		body.add_child(tl)
	var rows := TdTowerCard.def_rows(def, _vocab)
	if rows.is_empty(): return
	body.add_child(_caption("Abilities"))
	var box := TdMenu.vbox(0)
	body.add_child(box)
	for r in rows: box.add_child(r)

func _caption(text: String) -> Label:
	return _cap(text, Color(0, 0, 0, 0))

## A small extrabold caption ("This tower now").
func _cap(text: String, col: Color) -> Label:
	var l := TdMenu.label(text, "body", col if col.a > 0 else TdTheme.color("ink.2"), 18)
	l.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
	return l

## Picks a node of the tree (its card shows).
func select_node(id: String) -> void:
	if not WorkshopLogic.node_ids(_type).has(id): return
	node_id = id
	if flash_id != id: flash_id = ""
	_tree.restyle()
	_refresh_card()

func _refresh_card() -> void:
	TdCollection.clear_children(_card)
	var owned := _owned()
	var id := node_id
	var st := WorkshopLogic.node_state(owned, _type, id, SaveData.tokens)
	var cur := WorkshopLogic.current_id(owned, _type)
	var body := _scroll_body(_card, 6, 0, true)
	if flash_id == id and id != "": body.add_child(_toast(WorkshopLogic.toast(_type, id)))
	var head := TdMenu.hbox(14)
	body.add_child(head)
	var m := _medal(id, 76)
	m.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(m)
	var v := TdMenu.vbox(0)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(v)
	var n := TdMenu.wrap_label(WorkshopLogic.name_of(_type, id), "h2", TITLE_INK, 28)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	v.add_child(n)
	var sub := TdMenu.label(WorkshopLogic.subtitle(_type, id), "header", TdTheme.color("ink.2"), 18)
	sub.add_theme_font_override("font", TdTheme.font("plinth"))
	v.add_child(sub)
	body.add_child(TdMenu.rich(TooltipText.describe(WorkshopLogic.description_of(_type, id)), "body", TdTheme.color("ink"), 18))
	# the selected form as it is (no comparison with the current form: user decision 2026-10-14)
	_def_section(body, WorkshopLogic.def_of(_type, id))
	# the pinned footer: Leads to, the cost row and the one action (only the body above scrolls)
	_card.add_child(TdMenu.spacer(8))
	var foot := TdMenu.vbox(6)
	_card.add_child(foot)
	# "› Leads to: Inferno Archer" (kept out of the scroll so it always shows)
	var leads := WorkshopLogic.leads_to(_type, id)
	if leads != "":
		var ll := TdMenu.rich("[color=%s]›[/color]  %s [color=%s][b]%s[/b][/color]" % [TdTheme.rich("ink.2"), leads.get_slice(":", 0) + ":",
			TdTheme.rich("ink"), leads.get_slice(": ", 1)], "body", TdTheme.color("ink.2"), 18)
		ll.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
		foot.add_child(ll)
	var f := WorkshopLogic.form_of(_type, id)
	if f != null and st in ["can", "need", "locked"]: foot.add_child(_cost_row(f))
	var act := WorkshopLogic.action(owned, _type, id, SaveData.tokens, int(_entry(tower_id).get("index", 0)), _found)
	match act.kind:
		"current":
			foot.add_child(TdTowerCard.disabled_button(act.text, TdTheme.texture("icon_check")))
			foot.add_child(_note(act.note))
		"use":
			var b := TdMenu.button(TdButton.Style.PRIMARY, act.text, Vector2(0, 58), TdTheme.texture("icon_check"))
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			b.clicked.connect(card_action)
			foot.add_child(b)
			foot.add_child(_note(act.note))
		"unlock":
			var b := _unlock_button(f)
			b.clicked.connect(card_action)
			foot.add_child(b)
			foot.add_child(_note(act.note))
		_:
			var why := TdMenu.hbox(6)
			var w := TdMenu.picture(TdMenu.warn_icon(), Vector2(20, 20))
			w.size_flags_vertical = SIZE_SHRINK_BEGIN
			why.add_child(w)
			var wl := TdMenu.wrap_label(act.reason, "body", TdTheme.color("bad.ink"), 18)
			wl.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
			why.add_child(wl)
			foot.add_child(why)
			foot.add_child(TdTowerCard.disabled_button(act.text, TdTheme.texture("icon_plus"), act.reason))

## "Unlock · [coin] 1 Fire Arrow" (one token) or "Unlock · [coin] 1 [coin] 1" (several: coins and counts only; the
## names are in the cost row). Never wraps; gold ring (mockup .ws-gold).
func _unlock_button(f: FormDef) -> TdButton:
	var b := TdMenu.button(TdButton.Style.PRIMARY, "", Vector2(0, 58))
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	TdTowerCard.gold_ring(b)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.offset_bottom = -4 # the face sits above the button's bottom lip
	c.mouse_filter = MOUSE_FILTER_IGNORE
	b.face_node().add_child(c) # on the face (drawn over its sprite; the face moves with the press)
	var h := TdMenu.hbox(6)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	c.add_child(h)
	var parts := WorkshopLogic.unlock_parts(f)
	# never wraps: the label shrinks (26 → 20) until it fits the face with ~26 px each side (QA 2026-10-15: "Unlock ·
	# 1 Fire Arrow" ran to 12 px of the rims, longer token names past them)
	var texts := ["Unlock ·"]
	for part in parts: texts.append(part[1])
	var fs := 26
	var room := CARD_W - 32.0 - 52.0
	while fs > 20:
		var w := (texts.size() - 1) * (30.0 + 12.0) # each token: its coin and the two gaps round it
		for t in texts: w += TdTheme.font("plinth").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w <= room: break
		fs -= 1
	h.add_child(_button_label("Unlock ·", fs))
	for part in parts:
		var t := GameApp.catalog.find_token(part[0])
		var ic := TdMenu.picture(GameApp.kit_texture(t.icon) if t != null else null, Vector2(30, 30))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(_button_label(part[1], fs))
	return b

func _button_label(text: String, fs := 26) -> Label:
	var l := TdMenu.label(text, "header", Color.WHITE, fs)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.4, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	return l

func _note(text: String) -> Label:
	var l := TdMenu.wrap_label(text, "body", TdTheme.color("ink.2"), 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## The single token's icon for the Unlock button (several tokens: none).
func _token_icon(f: FormDef) -> Texture2D:
	if f == null or f.unlock.size() != 1: return TdTheme.texture("icon_plus")
	var t := GameApp.catalog.find_token(f.unlock.keys()[0])
	return GameApp.kit_texture(t.icon) if t != null else TdTheme.texture("icon_plus")

## "Unlock cost  [🔥 1 you have 2] …" (a token short: red).
func _cost_row(f: FormDef) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var cap := _cap("Unlock cost", Color(0, 0, 0, 0))
	cap.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(cap)
	for id in f.unlock:
		var need := int(f.unlock[id])
		var have := SaveData.tokens.count(id)
		var short := have < need
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.13, 0.09, 0.08)
		sb.border_color = TdTheme.color("bad.ink") if short else Color(0.37, 0.29, 0.21, 0.35)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(15)
		sb.content_margin_left = 3; sb.content_margin_right = 10
		chip.add_theme_stylebox_override("panel", sb)
		chip.custom_minimum_size = Vector2(0, 32)
		var h := TdMenu.hbox(6)
		chip.add_child(h)
		var t := GameApp.catalog.find_token(id)
		var ic := TdMenu.picture(GameApp.kit_texture(t.icon) if t != null else null, Vector2(26, 26))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := TdMenu.rich("[font=%s]%d[/font]  [color=%s]you have %d[/color]" % [TdTheme.font("plinth").resource_path, need,
			TdTheme.rich("bad.ink") if short else TdTheme.rich("ink.2"), have], "body", TdTheme.color("bad.ink") if short else TdTheme.color("ink"), 18)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_horizontal = SIZE_SHRINK_BEGIN
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		l.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
		h.add_child(l)
		TdTooltipTrigger.attach(chip, TooltipText.title(t.get_display_name() if t != null else id, TooltipText.value_color(), "Token"),
			"Found in: %s." % _found.get(id, "") if _found.get(id, "") != "" else "", "You have", str(have))
		row.add_child(chip)
	return row

## The gold "Fire Archer unlocked" toast on the card (fades in).
func _toast(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.83, 0.42, 0.35)
	sb.border_color = Color("#C9952A")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := TdMenu.hbox(8)
	p.add_child(h)
	var star := StarGlyph.new()
	star.custom_minimum_size = Vector2(24, 24)
	star.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(star)
	var l := TdMenu.label(text, "header", Color("#7A4E00"), 22)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	h.add_child(l)
	p.modulate.a = 0.0
	TdTheme.tween(p).tween_property(p, "modulate:a", 1.0, 0.3)
	return p

# ------------------------------------------------------------------ actions

## The card's action (Enter): Unlock → the confirm popup; Use this form → switch. Nothing for the current form or a
## refused unlock.
func card_action() -> void:
	if view != "modify" or confirm_open: return
	var act := WorkshopLogic.action(_owned(), _type, node_id, SaveData.tokens, int(_entry(tower_id).get("index", 0)), _found)
	match act.kind:
		"unlock": open_confirm()
		"use": use_form()

## The confirm popup ("Unlock Fire Archer for this Archer?").
func open_confirm() -> void:
	var f := WorkshopLogic.form_of(_type, node_id)
	if f == null: return
	TdCollection.clear_children(_confirm_box)
	var mc := CenterContainer.new()
	_confirm_box.add_child(mc)
	var m := _medal(node_id, 84)
	mc.add_child(m)
	var t := TdMenu.label(WorkshopLogic.confirm_title(_type, f), "h2", TdTheme.color("cream.100"), 34)
	t.add_theme_font_override("font", TdTheme.font("plinth"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_box.add_child(t)
	var body := WorkshopLogic.confirm_body(_type, f, SaveData.tokens)
	var re := RegEx.create_from_string("(\\d+ [^(.]+?) \\(you have")
	body = re.sub(body, "[color=%s][b]$1[/b][/color] (you have" % TdTheme.rich("cream.100"), true)
	var b := TdMenu.rich(body, "body", TdTheme.color("cream.200"), 22)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(690, 0)
	_confirm_box.add_child(b)
	var row := TdMenu.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_box.add_child(row)
	var no := TdMenu.button(TdButton.Style.SECONDARY, "Cancel", Vector2(220, 60))
	no.clicked.connect(cancel_confirm)
	row.add_child(no)
	var yes := TdMenu.button(TdButton.Style.PRIMARY, "Unlock", Vector2(220, 60), TdTheme.texture("icon_plus"))
	TdTowerCard.gold_ring(yes)
	yes.clicked.connect(confirm_unlock)
	row.add_child(yes)
	confirm_open = true
	_confirm_at = Time.get_ticks_msec()
	_confirm.visible = true
	_confirm.modulate.a = 0.0
	TdTheme.tween(_confirm).tween_property(_confirm, "modulate:a", 1.0, 0.15)

func cancel_confirm() -> void:
	confirm_open = false
	_confirm.visible = false

## Confirmed: spends the tokens, unlocks the form on this tower, saves; the node fills, its ring flashes, the toast
## shows and the action becomes Use this form.
func confirm_unlock() -> bool:
	var f := WorkshopLogic.form_of(_type, node_id)
	cancel_confirm()
	if f == null or not Workshop.unlock(_owned(), f, SaveData.tokens): return false
	SaveData.save()
	flash_id = node_id
	refresh_modify()
	_tree.flash(node_id)
	_toast_serial += 1
	var serial := _toast_serial
	get_tree().create_timer(4.0, true, false, true).timeout.connect(func():
		if serial == _toast_serial and is_instance_valid(self) and flash_id != "":
			flash_id = ""
			if view == "modify": _refresh_card())
	changed.emit()
	return true

## Use this form: the tower switches to the selected (unlocked) form; free, saved at once.
func use_form() -> bool:
	if not Workshop.set_form(_owned(), node_id): return false
	SaveData.save()
	flash_id = ""
	_reload_entries()
	refresh_modify()
	changed.emit()
	return true

## Esc / right click: the confirm first, then the Modify view, then the window.
func back() -> void:
	if confirm_open: cancel_confirm()
	elif view == "modify": back_to_picker()
	else: close()

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open or not is_top() or not (event is InputEventKey) or not event.pressed or event.echo: return
	var k: int = event.keycode
	if confirm_open:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			confirm_unlock()
			get_viewport().set_input_as_handled()
		return
	if view == "pick":
		if (k == KEY_ENTER or k == KEY_KP_ENTER) and tower_id != "":
			open_modify(tower_id)
			get_viewport().set_input_as_handled()
		return
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		card_action()
		get_viewport().set_input_as_handled()

## Arrow keys move between the tree's nodes. Read before the GUI: with no focus owner, the GUI would take an arrow
## (ui_left…) to focus some control.
func _input(event: InputEvent) -> void:
	if not is_open or not is_top() or view != "modify" or confirm_open: return
	if not (event is InputEventKey) or not event.pressed: return
	var dir := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: dir = Vector2.LEFT
		KEY_RIGHT: dir = Vector2.RIGHT
		KEY_UP: dir = Vector2.UP
		KEY_DOWN: dir = Vector2.DOWN
	if dir == Vector2.ZERO: return
	select_node(WorkshopLogic.neighbour(WorkshopLogic.positions(_type), node_id, dir))
	get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ the tree

## The forms tree (centre of the Modify view): connectors drawn here, a FormNode per node placed on
## WorkshopLogic.positions() scaled into the well, the caption on top and the legend at the bottom.
class FormTree extends Control:
	var screen
	var nodes := {}      # id → FormNode
	var _pos := {}       # id → Vector2 in the tree frame
	var _legend: HBoxContainer
	var _caption: Label
	var _empty: Label

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size_flags_horizontal = SIZE_EXPAND_FILL
		size_flags_vertical = SIZE_EXPAND_FILL
		clip_contents = true
		resized.connect(_place)

	func rebuild() -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		nodes.clear()
		_caption = TdMenu.label("Forms · click one to see it", "body", TdTheme.color("cream.300"), 18)
		_caption.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
		_caption.position = Vector2(16, 10)
		add_child(_caption)
		var type: TowerType = screen._type
		_pos = WorkshopLogic.positions(type)
		for id in WorkshopLogic.node_ids(type):
			var n := FormNode.new()
			n.id = id
			n.screen = screen
			n.pressed.connect(screen.select_node)
			add_child(n)
			n.build()
			nodes[id] = n
		_empty = null
		if type != null and type.forms.is_empty():
			_empty = TdMenu.label("No forms for %s yet." % type.name, "body", TdTheme.color("cream.200"), 20)
			_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(_empty)
		_legend = TdMenu.hbox(22)
		_legend.alignment = BoxContainer.ALIGNMENT_CENTER
		for pair in [["current", "Current"], ["unlocked", "Unlocked"], ["can", "Can unlock"], ["need", "Needs tokens"]]:
			var h := TdMenu.hbox(8)
			var d := LegendDot.new()
			d.kind = pair[0]
			d.custom_minimum_size = Vector2(24, 24)
			d.size_flags_vertical = SIZE_SHRINK_CENTER
			h.add_child(d)
			var l := TdMenu.label(pair[1], "body", TdTheme.color("cream.200"), 18)
			l.add_theme_font_override("font", TdTheme.font("nunito_bold"))
			h.add_child(l)
			_legend.add_child(h)
		add_child(_legend)
		restyle()
		_place()

	## Restyles every node (selection, states) and redraws the connectors.
	func restyle() -> void:
		for id in nodes: nodes[id].restyle()
		queue_redraw()

	func flash(id: String) -> void:
		if nodes.has(id): nodes[id].flash()

	## The tree frame (TREE_SIZE) scaled into the area between the caption and the legend.
	func _frame() -> Array:
		var top := 34.0
		# the legend (40) + room for a bottom node's token chips, which hang ~118 px under its anchor (QA 2026-10-15:
		# Longbow's "1/2" chip sat on the legend at 46)
		var bottom := 70.0
		var avail := Vector2(size.x, size.y - top - bottom)
		var k := minf(avail.x / WorkshopLogic.TREE_SIZE.x, avail.y / WorkshopLogic.TREE_SIZE.y)
		k = minf(k, 1.15)
		var off := Vector2((size.x - WorkshopLogic.TREE_SIZE.x * k) / 2.0, top + (avail.y - WorkshopLogic.TREE_SIZE.y * k) / 2.0)
		return [off, k]

	func anchor_of(id: String) -> Vector2:
		var f := _frame()
		return f[0] + (_pos.get(id, WorkshopLogic.ROOT_AT) as Vector2) * f[1]

	func _place() -> void:
		for id in nodes:
			var n: FormNode = nodes[id]
			n.position = anchor_of(id) - n.anchor
		if _empty != null:
			_empty.size = Vector2(size.x, 30)
			_empty.position = Vector2(0, anchor_of("").y + 130)
		if _legend != null:
			_legend.size = Vector2(size.x, 30)
			_legend.position = Vector2(0, size.y - 40)
		queue_redraw()

	func _draw() -> void:
		var type: TowerType = screen._type
		if type == null: return
		var owned: OwnedTower = screen._owned()
		var path := WorkshopLogic.path_to(type, WorkshopLogic.current_id(owned, type))
		for f in type.forms:
			var p = WorkshopLogic.parent_id(type, f.id)
			var a := anchor_of(p)
			var b := anchor_of(f.id)
			if path.has(f.id) and path.has(p):
				draw_line(a, b, COBALT_LINE, 8.0, true)
			elif Workshop.is_unlocked(owned, f.id):
				draw_line(a, b, Color("#8E7458"), 6.0, true)
			else:
				draw_dashed_line(a, b, Color(0.933, 0.886, 0.776, 0.35), 6.0, 9.0, true)

## One node: the medallion (real portrait once unlocked, else its first token's coin; ring cobalt for Current, gold + glow for Can
## unlock, else the form's tint), the badge, "Current" above, a green ✓ when unlocked, the name plate (cobalt when
## selected) and, when it is not unlocked, its token chips ("0/1" red when short, "1 ✓" when there).
class FormNode extends Control:
	signal pressed(id: String)
	const W := 190.0
	const TOP := 18.0
	var id := ""
	var screen
	var anchor := Vector2(W / 2.0, TOP + NODE_MEDAL / 2.0)
	var state := ""
	## Shows its token coin (not unlocked yet) instead of the portrait.
	var coin := false
	var _medal: Control
	var _ring: TdTowerCard.RingLine
	var _flash_ring: TdTowerCard.RingLine
	var _plate: PanelContainer
	var _plate_label: Label
	var _tag: PanelContainer
	var _ok: Control
	var _chips: HBoxContainer
	var _hover := false
	var _selected := false

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(W, TOP + NODE_MEDAL + 80)
		size = custom_minimum_size
		mouse_entered.connect(func(): _hover = true; _lift())
		mouse_exited.connect(func(): _hover = false; _lift())

	func build() -> void:
		var type: TowerType = screen._type
		state = WorkshopLogic.node_state(screen._owned(), type, id, SaveData.tokens)
		# a form not unlocked yet shows the coin of its cost's first token in place of the portrait (user decision
		# 2026-10-14); the portrait appears once it is unlocked
		var f0 := WorkshopLogic.form_of(type, id)
		coin = f0 != null and state in ["can", "need", "locked"] and not f0.unlock.is_empty()
		if coin:
			_medal = Control.new()
			_medal.mouse_filter = MOUSE_FILTER_IGNORE
			_medal.custom_minimum_size = Vector2(NODE_MEDAL, NODE_MEDAL)
			_medal.size = _medal.custom_minimum_size
			var t: TokenAsset = GameApp.catalog.find_token(f0.unlock.keys()[0])
			var pic := TdMenu.picture(GameApp.kit_texture(t.icon) if t != null else null, Vector2(NODE_MEDAL, NODE_MEDAL))
			_medal.add_child(pic)
		else:
			_medal = TdMenu.medallion(screen._portrait(id), NODE_MEDAL)
		_medal.position = Vector2((W - NODE_MEDAL) / 2.0, TOP)
		add_child(_medal)
		_ring = TdTowerCard.RingLine.new()
		_ring.size = Vector2(NODE_MEDAL, NODE_MEDAL)
		_medal.add_child(_ring)
		_flash_ring = TdTowerCard.RingLine.new()
		_flash_ring.size = Vector2(NODE_MEDAL, NODE_MEDAL)
		_flash_ring.colour = GOLD_RING
		_flash_ring.glow = Color(GOLD_RING, 0.6)
		_flash_ring.modulate.a = 0.0
		_medal.add_child(_flash_ring)
		TdFormBadge.attach(_medal, screen._badge(id), NODE_MEDAL, 0.34)
		# Current tag over the top
		_tag = TdMenu.pill("[b]Current[/b]", TdTheme.color("accent.fill"), Color.WHITE, 18, TdTheme.color("rim"))
		add_child(_tag)
		_tag.visible = state == "current"
		# unlocked ✓ at the lower-left
		_ok = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = TdTheme.color("good.ink")
		sb.border_color = TdTheme.color("rim")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		_ok.add_theme_stylebox_override("panel", sb)
		_ok.size = Vector2(26, 26)
		_ok.position = Vector2(W / 2.0 - 52, TOP + NODE_MEDAL - 30)
		_ok.mouse_filter = MOUSE_FILTER_IGNORE
		var ck := TdMenu.picture(TdTheme.texture("icon_check"), Vector2(16, 16))
		ck.position = Vector2(5, 5)
		_ok.add_child(ck)
		add_child(_ok)
		_ok.visible = state == "unlocked"
		# name plate
		_plate = PanelContainer.new()
		_plate.mouse_filter = MOUSE_FILTER_IGNORE
		_plate_label = TdMenu.label(WorkshopLogic.name_of(type, id), "header", TdTheme.color("cream.100"), 20)
		_plate_label.add_theme_font_override("font", TdTheme.font("plinth"))
		_plate.add_child(_plate_label)
		add_child(_plate)
		# cost chips
		_chips = TdMenu.hbox(4)
		_chips.mouse_filter = MOUSE_FILTER_IGNORE
		var f := WorkshopLogic.form_of(type, id)
		if f != null and state in ["can", "need", "locked"]:
			for t in f.unlock:
				_chips.add_child(_chip(t, int(f.unlock[t])))
		add_child(_chips)
		TdTooltipTrigger.attach(self, "", WorkshopLogic.node_hint(type, id, state))

	func _chip(token_id: String, need: int) -> Control:
		var have: int = SaveData.tokens.count(token_id)
		var short := have < need
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.067, 0.05, 0.88)
		sb.border_color = SHORT if short else Color("#2D7238")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		sb.content_margin_left = 1; sb.content_margin_right = 7
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(0, 26)
		p.mouse_filter = MOUSE_FILTER_IGNORE
		var h := TdMenu.hbox(2)
		p.add_child(h)
		var t: TokenAsset = GameApp.catalog.find_token(token_id)
		var ic := TdMenu.picture(GameApp.kit_texture(t.icon) if t != null else null, Vector2(24, 24))
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := TdMenu.label(WorkshopLogic.chip_text(have, need), "header", SHORT if short else TdTheme.color("cream.100"), 18)
		l.add_theme_font_override("font", TdTheme.font("plinth"))
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(l)
		if not short:
			var okl := TdMenu.label("✓", "header", OK, 18)
			okl.size_flags_vertical = SIZE_SHRINK_CENTER
			h.add_child(okl)
		return p

	func restyle() -> void:
		_selected = screen.node_id == id
		var c := Color(0, 0, 0, 0)
		var glow := Color(0, 0, 0, 0)
		match state:
			"current":
				c = COBALT
				glow = Color(0.3, 0.56, 0.9, 0.55)
			"can":
				c = GOLD_RING
				glow = Color(GOLD_RING, 0.5)
			_:
				var b: String = screen._badge(id)
				if coin: c = Color(0, 0, 0, 0) # a coin: no ring unless it can be unlocked
				elif b != "": c = TdFormBadge.colour_of(b)
				else: c = TdTheme.color("ink") # the base form, not current: a neutral ink ring (cobalt means Current)
		_ring.colour = c
		_ring.glow = glow
		_ring.visible = c.a > 0.0
		_ring.queue_redraw()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 1; sb.content_margin_bottom = 3
		if _selected:
			sb.bg_color = TdTheme.color("accent.fill")
			sb.border_color = TdTheme.color("accent.light")
			sb.set_border_width_all(3)
			_plate_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			sb.bg_color = Color(0.09, 0.067, 0.05, 0.85)
			sb.border_color = TdTheme.color("rim")
			sb.set_border_width_all(2)
			var col := TdTheme.color("cream.100")
			if state == "need": col = TdTheme.color("cream.200")
			elif state == "locked": col = TdTheme.color("cream.300")
			_plate_label.add_theme_color_override("font_color", col)
		_plate.add_theme_stylebox_override("panel", sb)
		_layout_parts.call_deferred()
		queue_redraw()

	func _layout_parts() -> void:
		if not is_instance_valid(_plate): return
		_plate.size = _plate.get_combined_minimum_size()
		_plate.position = Vector2((W - _plate.size.x) / 2.0, TOP + NODE_MEDAL + 6)
		_tag.size = _tag.get_combined_minimum_size()
		_tag.position = Vector2((W - _tag.size.x) / 2.0, TOP - 16)
		_chips.size = _chips.get_combined_minimum_size()
		_chips.position = Vector2((W - _chips.size.x) / 2.0, _plate.position.y + _plate.size.y + 6)

	func _lift() -> void:
		if _medal != null: _medal.position.y = TOP - (3.0 if _hover else 0.0)

	## The ring flash after an unlock (3 gold pulses).
	func flash() -> void:
		var tw := TdTheme.tween(_flash_ring)
		for i in 3:
			tw.tween_property(_flash_ring, "modulate:a", 1.0, 0.15)
			tw.tween_property(_flash_ring, "modulate:a", 0.0, 0.3)

	func _draw() -> void:
		if not _selected: return
		# the soft halo behind a selected node
		var c := anchor
		for i in 10:
			var r := 105.0 - i * 6.0
			draw_circle(c, r, Color(1.0, 0.92, 0.75, 0.018 + i * 0.006))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit(id)
			accept_event()

## A legend swatch (mockup .lg i).
class LegendDot extends Control:
	var kind := ""
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size / 2.0
		var r := 10.0
		match kind:
			"current":
				draw_circle(c, r + 4, COBALT)
				draw_circle(c, r + 1.5, TdTheme.color("rim"))
				draw_circle(c, r, Color("#5E4A3A"))
			"unlocked":
				draw_circle(c, r + 2, TdTheme.color("rim"))
				draw_circle(c, r, TdTheme.color("good.ink"))
			"can":
				draw_circle(c, r + 6, Color(GOLD_RING, 0.25))
				draw_circle(c, r + 4, GOLD_RING)
				draw_circle(c, r + 1.5, TdTheme.color("rim"))
				draw_circle(c, r, Color("#5E4A3A"))
			_:
				draw_circle(c, r + 2, TdTheme.color("rim"))
				draw_circle(c, r, SHORT)
				draw_circle(c, r - 2, Color("#4A4440"))

## The toast's star.
class StarGlyph extends Control:
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size / 2.0
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			var r := size.x / 2.0 if i % 2 == 0 else size.x / 4.4
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, TdTheme.color("gold"))
		pts.append(pts[0])
		draw_polyline(pts, Color("#C9952A"), 1.5, true)
