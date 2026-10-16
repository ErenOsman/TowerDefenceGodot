class_name UpgradeScreen
extends TdPopup
## The Upgrade screens (Upgrades — Design § Player flow / The Upgrade view; UI/UX mockups screens-b/upgrade*.html):
## the Blacksmith's Upgrade station. Modelled on the Workshop (workshop.gd): one window, two panes that slide.
##  Step 1, the picker: "Upgrade · Pick a tower", the collection (TdCollection, filter set "upgrade": search and a
##  "Ready to upgrade" toggle that keeps the towers that can be upgraded now in their current form, "5 ready"),
##  tiles with their Lv chip and a green ↑ when ready (no cost coin), and a paper card: name, "tower 3", Lv chip,
##  "Level 3: 1 of 2 tasks done" and "✓ Archer is ready to upgrade" (current form), stat tiles, Upgrade.
##  Step 2, the Upgrade view (Eren 2026-10-16: now vs after, nothing else): "← Back", the name, "tower 3", Lv chip;
##  it works on the tower's CURRENT form (wearing Fire Archer: the Fire Archer ladder; no forms row). Left "Now":
##  the card as it is (medallion with badge and Lv chip, name, "Form of Archer" for a form only, stats,
##  abilities); centre "Level 3", the tasks with progress bars ("42 / 60 damage", a green ✓ when done) and ONE
##  primary "Upgrade to level 3" (simply disabled while tasks are missing, the bars say it; only the form cap gets
##  a line under it, "Raise Archer to level 3 first" with a lock); right "After upgrade": the same card at level + 1 (TowerLevels.apply on a
##  copy) with every changed stat marked by a green "+5" badge. No max level shown; at max level the centre says
##  "Archer is at its highest level." and the right card is empty.
##  Upgrade → the shared TdConfirm ("Upgrade Archer to level 3?", "It gives +5 Max HP. …") → GameApp.upgrade_tower
##  (saves) → the gold beat "Archer reached level 3!" over the next level. The gold task's row has a Pay button
##  ("Pay 15" = min(gold, missing); GameApp.pay_into; disabled with the red "You have no gold. Missions give gold."),
##  and both headers carry the Backpack button (TdBackpackButton; Backpack — Design).
## Keys: Esc / right click = Back one step (confirm → cancel; view → picker; picker → close); Enter = the picker's
## Upgrade / the view's Upgrade (confirm: Enter = Upgrade). Texts and rules: UpgradeLogic, TowerLevels, TowerTasks.
## Open it like any station popup: `open_popup("upgrade")` in the Blacksmith (game/ui/screens/upgrade.tscn), or
## UpgradeScreen.show_over(parent).

signal changed

const SCENE := "res://game/ui/screens/upgrade.tscn"
const WIN := Vector2(1460, 864)
const PAD := 22.0
const SLIDE_TIME := 0.35
## The view's columns: now · tasks · after (the two cards the same width).
const NOW_W := 340.0
const RIGHT_W := 340.0
const TITLE_INK := Color("#2B5594")
const GOOD := Color("#2F8A45")
const GOLD_BAR := Color("#C9952A")
const BEAT_TIME := 4.0

## "pick" or "view".
var view := "pick"
## The owned tower picked / shown.
var tower_id := ""
## The ladder shown in the view: the tower's current form ("" = the base, else a form id).
var ladder := ""
## The beat line over the centre column ("Archer reached level 3!") until another ladder is picked or 4 s pass.
var beat := ""
## The upgrade confirm (a TdConfirm) is open.
var confirm_open: bool:
	get: return is_instance_valid(_confirm) and _confirm.is_open and _confirm.answer == null

var collection: TdCollection
## The Backpack buttons: the picker's header (left of ×) and the view's header (right; Pay refreshes it).
var pick_backpack: TdBackpackButton
var backpack_button: TdBackpackButton
## The view's Pay button of the gold task (null when there is none / max; tests and tools).
var pay_button: TdButton
var _entries: Array = []
var _ready_ids := {}   # tower id → bool
var _type: TowerType = null
var _vocab: Vocabulary

var _clip: Control
var _slider: Control
var _pick: VBoxContainer
var _view: VBoxContainer
var _pdetail: VBoxContainer
var _vname: HBoxContainer
var _now: VBoxContainer
var _mid: VBoxContainer
var _right: VBoxContainer
var _confirm: TdConfirm
var _slide_tween: Tween
var _beat_serial := 0
## The view's Upgrade button (null when blocked / max; tests and tools).
var upgrade_button: TdButton

## Opens the Upgrade picker over a parent (adds it, frees it on close); returns it.
static func show_over(parent: Node) -> UpgradeScreen:
	var s: UpgradeScreen = load(SCENE).instantiate()
	s.free_on_close = true
	parent.add_child(s)
	s.open()
	return s

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
	_view = TdMenu.vbox(14)
	_slider.add_child(_view)
	_clip.resized.connect(_layout_panes)
	_build_pick()
	_build_view()

func _layout_panes() -> void:
	var s := _clip.size
	_pick.position = Vector2.ZERO
	_pick.size = s
	_view.position = Vector2(s.x + PAD * 2.0, 0)
	_view.size = s
	if _slide_tween == null or not _slide_tween.is_running(): _slider.position.x = _slide_x()

func _slide_x() -> float:
	return 0.0 if view == "pick" else -(_clip.size.x + PAD * 2.0)

func _build_pick() -> void:
	var head := TdMenu.hbox(14)
	_pick.add_child(head)
	head.add_child(TdMenu.label("Upgrade", "h1", TdTheme.color("cream.100"), 44))
	var sub := TdMenu.label("Pick a tower", "small", TdTheme.color("cream.300"), 22)
	sub.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(sub)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(fill)
	pick_backpack = TdBackpackButton.make(self) # left of × (Backpack — Design)
	head.add_child(pick_backpack)
	var x := TdMenu.close_button()
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	var body := TdMenu.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	_pick.add_child(body)
	collection = TdCollection.new()
	collection.filter_set = "upgrade"
	collection.extras = false
	collection.hand_keys = false
	collection.show_cost = false
	collection.filter_width = 224.0
	collection.tile_size = TdTowerTile.WIDE
	collection.gap = 8
	collection.ready_of = func(id: String) -> bool: return bool(_ready_ids.get(id, false))
	collection.level_of = func(e: Dictionary) -> int: return int(e.get("level", 1))
	collection.build()
	collection.selected.connect(_pick_tower)
	collection.activated.connect(open_view)
	body.add_child(collection)
	var paper := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	paper.custom_minimum_size = Vector2(360, 0)
	_pdetail = TdMenu.vbox(10)
	paper.add_child(_pdetail)
	body.add_child(paper)

func _build_view() -> void:
	var top := TdMenu.hbox(20)
	top.custom_minimum_size = Vector2(0, 56)
	_view.add_child(top)
	var back_b := TdMenu.button(TdButton.Style.SECONDARY, "Back", Vector2(190, 52), TdTheme.texture("icon_back"))
	back_b.size_flags_vertical = SIZE_SHRINK_CENTER
	back_b.clicked.connect(back_to_picker)
	top.add_child(back_b)
	_vname = TdMenu.hbox(10)
	_vname.size_flags_vertical = SIZE_SHRINK_CENTER
	top.add_child(_vname)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(fill)
	backpack_button = TdBackpackButton.make(self) # the gold the Pay button spends (mockup upgrade-pay)
	top.add_child(backpack_button)
	var body := TdMenu.hbox(16)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	_view.add_child(body)
	var left := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	left.custom_minimum_size = Vector2(NOW_W, 0)
	left.padding = 14
	_now = TdMenu.vbox(8)
	left.add_child(_now)
	body.add_child(left)
	var mid := TdMenu.panel(TdPanel.Kind.PAPER, 22)
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	_mid = TdMenu.vbox(10)
	mid.add_child(_mid)
	body.add_child(mid)
	var right := TdMenu.panel(TdPanel.Kind.PAPER, 16)
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.padding = 14
	_right = TdMenu.vbox(8)
	right.add_child(_right)
	body.add_child(right)

# ------------------------------------------------------------------ open / data

func _on_open() -> void:
	_vocab = GameApp.rules.vocabulary if GameApp.rules != null else null
	view = "pick"
	beat = ""
	cancel_confirm()
	_reload_entries()
	TdBackpackButton.refresh_all(get_tree())
	if tower_id == "" or SaveData.towers.find(tower_id) == null:
		tower_id = _entries[0].id if not _entries.is_empty() else ""
	_refresh_pick()
	_layout_panes.call_deferred()

func _reload_entries() -> void:
	_entries = HandLogic.entries(SaveData.towers, GameApp.catalog, GameApp.convert)
	_ready_ids.clear()
	for e in _entries:
		var o: OwnedTower = SaveData.towers.find(e.id)
		_ready_ids[e.id] = o != null and UpgradeLogic.is_ready(o, GameApp.tower_type(o.type))

func _entry(id: String) -> Dictionary:
	for e in _entries:
		if e.id == id: return e
	return {}

func _owned() -> OwnedTower:
	return SaveData.towers.find(tower_id)

func _index_text(e: Dictionary) -> String:
	return "tower %d" % int(e.get("index", 0))

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
		var l := TdMenu.wrap_label("Select a tower to see its level.", "body", TdTheme.color("ink.2"), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_vertical = SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_pdetail.add_child(l)
		return
	var type := GameApp.tower_type(owned.type)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 10)
	var n := TdMenu.label(e.name, "h2", TdTheme.color("accent.ink"), 32)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	head.add_child(n)
	var num := TdMenu.label(_index_text(e), "header", TdTheme.color("ink.2"), 20)
	num.add_theme_font_override("font", TdTheme.font("plinth"))
	num.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(num)
	var chip := TdLvChip.make(TowerLevels.current_level(owned, type), 18)
	chip.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(chip)
	_pdetail.add_child(head)
	var tl := TdMenu.label(UpgradeLogic.tasks_done_line(owned, type, UpgradeLogic.start_ladder(owned, type)), "body", TdTheme.color("ink.2"), 20)
	tl.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	_pdetail.add_child(tl)
	var rl := UpgradeLogic.ready_line(owned, type)
	if rl != "": _pdetail.add_child(_check_line(rl, 20))
	var def: EntityDef = GameApp.resolved_type(owned).entity if GameApp.resolved_type(owned) != null else null
	if def != null and _vocab != null: _pdetail.add_child(TdTowerCard.stat_grid(HandLogic.stat_tiles(DefStats.new(def), _vocab, 4), 120))
	var fill := TdMenu.spacer()
	fill.size_flags_vertical = SIZE_EXPAND_FILL
	_pdetail.add_child(fill)
	var b := TdMenu.button(TdButton.Style.PRIMARY, "Upgrade", Vector2(0, 58), star_texture())
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.clicked.connect(func(): open_view(tower_id))
	_pdetail.add_child(b)

## "✓ Fire Archer is ready to upgrade" in green.
func _check_line(text: String, size: int) -> Control:
	var h := TdMenu.hbox(6)
	var ck := TdMenu.picture(TdTheme.texture("icon_check"), Vector2(size - 2, size - 2))
	ck.modulate = GOOD
	ck.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(ck)
	var l := TdMenu.wrap_label(text, "body", GOOD, size)
	l.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(l)
	return h

# ------------------------------------------------------------------ the Upgrade view

## Opens the Upgrade view for a tower (slides in from the right), on its current form's ladder.
func open_view(id: String) -> void:
	var owned := SaveData.towers.find(id)
	if owned == null: return
	tower_id = id
	collection.selected_id = id
	_type = GameApp.tower_type(owned.type)
	ladder = UpgradeLogic.start_ladder(owned, _type)
	beat = ""
	view = "view"
	refresh_view()
	_slide()

## Back to the picker (slides back).
func back_to_picker() -> void:
	if view != "view": return
	view = "pick"
	beat = ""
	cancel_confirm()
	_reload_entries()
	_refresh_pick()
	_slide()

func _slide() -> void:
	if _slide_tween != null: _slide_tween.kill()
	_slide_tween = TdTheme.tween(_slider)
	_slide_tween.tween_property(_slider, "position:x", _slide_x(), SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Redraws the whole view.
func refresh_view() -> void:
	var owned := _owned()
	if owned == null or _type == null: return
	ladder = UpgradeLogic.start_ladder(owned, _type)
	var e := _entry(tower_id)
	TdCollection.clear_children(_vname)
	var n := TdMenu.label(UpgradeLogic.ladder_name(_type, ladder) if ladder != "" or owned.custom_name == "" else owned.custom_name,
		"h1", TdTheme.color("accent.light"), 34)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	_vname.add_child(n)
	var num := TdMenu.label(_index_text(e), "header", TdTheme.color("cream.300"), 20)
	num.add_theme_font_override("font", TdTheme.font("plinth"))
	num.size_flags_vertical = SIZE_SHRINK_END
	_vname.add_child(num)
	var chip := TdLvChip.make(TowerLevels.level_of(owned, ladder), 18)
	chip.size_flags_vertical = SIZE_SHRINK_CENTER
	_vname.add_child(chip)
	var now := UpgradeLogic.levelled_type(owned, _type, ladder)
	var after := UpgradeLogic.after_type(owned, _type, ladder)
	_card(_now, "Now", now, TowerLevels.level_of(owned, ladder), {})
	_refresh_mid()
	TdCollection.clear_children(_right)
	if after != null:
		var diffs := UpgradeLogic.stat_diffs(_tiles(now), _tiles(after))
		_card(_right, "After upgrade", after, after.level, diffs)

func _portrait(form_id: String) -> Texture2D:
	var fa: FormAsset = GameApp.catalog.find_form(form_id) if form_id != "" else null
	if fa != null: return TdMenu.unit_picture(fa.entity.view if fa.entity != null else "", fa.icon)
	return TdCollection.portrait(GameApp.catalog.find_tower(_type.id) if _type != null else null)

func _badge(form_id: String) -> String:
	var f := _type.find_form(form_id) if _type != null and form_id != "" else null
	if f == null or f.badge == "": return ""
	var p := ArtPaths.kit(f.badge)
	return p if p != "" and ResourceLoader.exists(p) else ""

## The stat tiles of a type's entity ([[stat, label, value], …]).
func _tiles(t: TowerType) -> Array:
	if t == null or t.entity == null or _vocab == null: return []
	return HandLogic.stat_tiles(DefStats.new(t.entity), _vocab, 4)

## One card (the left "Now" and the right "After upgrade"): caption, medallion with badge and Lv chip, name,
## "Form of Archer" for a form (nothing for the base), the stat tiles (diffs: stat → "+5" badge in the good colour on
## the changed tiles) and the abilities (their numbers are the levelled ones).
func _card(col: VBoxContainer, caption: String, t: TowerType, lv: int, diffs: Dictionary) -> void:
	TdCollection.clear_children(col)
	var body := _scroll_body(col, 8)
	body.add_theme_constant_override("separation", 10) # the "+5" badges hang 10 px above their tiles
	body.add_child(_caption(caption))
	var head := TdMenu.hbox(12)
	body.add_child(head)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(84, 92)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	head.add_child(holder)
	var m := TdTowerCard.medallion(_portrait(ladder), 84, _badge(ladder))
	m.position = Vector2(0, 2)
	holder.add_child(m)
	TdLvChip.attach(m, lv, 84, 18)
	var v := TdMenu.vbox(0)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(v)
	var n := TdMenu.wrap_label(UpgradeLogic.ladder_name(_type, ladder), "h2", TITLE_INK, 28)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	v.add_child(n)
	var sub_text := UpgradeLogic.form_sub(_type, ladder)
	if sub_text != "":
		var sub := TdMenu.label(sub_text, "header", TdTheme.color("ink.2"), 18)
		sub.add_theme_font_override("font", TdTheme.font("plinth"))
		v.add_child(sub)
	if t == null or t.entity == null: return
	var grid := TdTowerCard.stat_grid(_tiles(t), 120)
	grid.get_child(0).add_theme_constant_override("v_separation", 12 if not diffs.is_empty() else 6)
	for tile in grid.get_child(0).get_children():
		var stat: String = tile.get_meta("stat", "")
		if diffs.has(stat): _mark(tile, diffs[stat])
	body.add_child(grid)
	for r in TdTowerCard.def_rows(t.entity, _vocab): body.add_child(r)

## Marks a changed stat tile: a good-coloured outline and a small "+5" badge hanging on its top-right corner (an
## overlay: the tile's value and name keep their room, "Max HP" is never squeezed).
func _mark(tile: Control, text: String) -> void:
	var ring := Panel.new()
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = GOOD
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(8)
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(ring) # a PanelContainer child: fitted to the tile
	var holder := Control.new() # fitted too; the badge inside it keeps its own size
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(holder)
	var b := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOOD
	sb.border_color = Color("#1E5A2C")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 0; sb.content_margin_bottom = 1
	b.add_theme_stylebox_override("panel", sb)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	var l := TdMenu.label(text, "micro", Color.WHITE, 16)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	b.add_child(l)
	holder.add_child(b)
	b.set_anchors_preset(PRESET_TOP_RIGHT)
	var bs := b.get_combined_minimum_size()
	b.offset_left = -bs.x + 4
	b.offset_right = 4
	b.offset_top = -10
	b.offset_bottom = -10 + bs.y

func _refresh_mid() -> void:
	TdCollection.clear_children(_mid)
	upgrade_button = null
	pay_button = null
	var owned := _owned()
	if beat != "": _mid.add_child(_beat_line(beat))
	var act := UpgradeLogic.action(owned, _type, ladder, GameApp.blacksmith_unlocked())
	if act.kind == "max":
		_mid.add_child(_title("Highest level"))
		var h := TdMenu.hbox(8)
		var st := TdMenu.picture(star_texture(), Vector2(24, 24))
		st.modulate = TdTheme.color("gold")
		st.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(st)
		h.add_child(TdMenu.label(UpgradeLogic.max_line(_type, ladder), "body", TdTheme.color("ink"), 22))
		_mid.add_child(h)
		return
	_mid.add_child(_title("Level %d" % act.to))
	_mid.add_child(_caption("Tasks"))
	var list := _scroll_body(_mid, 10)
	for row in UpgradeLogic.task_rows(owned, _type, ladder): list.add_child(_task_row(row))
	if act.kind == "upgrade":
		upgrade_button = TdMenu.button(TdButton.Style.PRIMARY, act.text, Vector2(0, 64), star_texture())
		upgrade_button.size_flags_horizontal = SIZE_EXPAND_FILL
		upgrade_button.clicked.connect(open_confirm)
		_mid.add_child(upgrade_button)
	else:
		var b := TdMenu.button(TdButton.Style.PRIMARY, act.text, Vector2(0, 64), star_texture())
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.set_interactable(false, act.reason)
		_mid.add_child(b)
		if act.note == "": return # a missing task: the bars say it (Eren 2026-10-16), no line
		var why := TdMenu.hbox(8)
		var ic := TdMenu.picture(TdTheme.texture("icon_lock" if act.lock else "icon_info"), Vector2(20, 20))
		ic.modulate = TdTheme.color("ink.2")
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		why.add_child(ic)
		var wl := TdMenu.wrap_label(act.note, "body", TdTheme.color("ink.2"), 20)
		wl.add_theme_font_override("font", TdTheme.font("nunito_bold"))
		wl.size_flags_horizontal = SIZE_EXPAND_FILL
		why.add_child(wl)
		_mid.add_child(why)

# ------------------------------------------------------------------ parts

## A ScrollContainer filling a column (vertically), holding a vbox (returned).
func _scroll_body(parent: Control, sep := 10) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	TdDragScroll.attach(scroll, true)
	parent.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 4)
	gutter.add_theme_constant_override("margin_left", 2)
	gutter.add_theme_constant_override("margin_top", 2)
	gutter.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(gutter)
	var body := TdMenu.vbox(sep)
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	gutter.add_child(body)
	return body

## A small extrabold caption ("This tower now", "Tasks").
func _caption(text: String) -> Label:
	var l := TdMenu.label(text, "body", TdTheme.color("ink.2"), 18)
	l.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
	return l

func _title(text: String) -> Label:
	var l := TdMenu.label(text, "h2", TITLE_INK, 38)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	return l

## One task: an icon box (green ✓ when done, else the kind's icon), the task text ("Done" after it when a one-off is
## done), and for counted tasks the bar (gold, green when full) with "42 / 60 damage".
func _task_row(row: Dictionary) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.09, 0.06)
	sb.border_color = Color(0.37, 0.29, 0.21, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := TdMenu.hbox(12)
	p.add_child(h)
	var box := Panel.new()
	box.custom_minimum_size = Vector2(48, 48)
	box.size_flags_vertical = SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.set_corner_radius_all(8)
	if row.done:
		bs.bg_color = GOOD
		bs.border_color = Color("#1E5A2C")
		bs.set_border_width_all(2)
	else:
		bs.bg_color = Color(0.18, 0.13, 0.09, 0.08)
	box.add_theme_stylebox_override("panel", bs)
	var ic := TdMenu.picture(TdTheme.texture("icon_check") if row.done else TdDrops.icon_texture(UpgradeLogic.task_icon(row.kind)), Vector2(26, 26))
	ic.modulate = Color.WHITE if row.done else TdTheme.color("ink.2")
	ic.position = Vector2(11, 11)
	box.add_child(ic)
	h.add_child(box)
	var v := TdMenu.vbox(6)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(v)
	var t := "[font_size=22][color=%s]%s[/color][/font_size]" % [TdTheme.rich("ink"), row.text]
	if row.done and not row.bar: t += "  [color=%s]Done[/color]" % GOOD.to_html(false)
	var tl := TdMenu.rich(t, "body", TdTheme.color("ink"), 18)
	tl.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
	v.add_child(tl)
	if row.bar:
		var bar := TaskBar.new()
		bar.ratio = row.ratio
		bar.colour = GOOD if row.done else GOLD_BAR
		bar.custom_minimum_size = Vector2(0, 12)
		v.add_child(bar)
		var pl := TdMenu.rich("[b][color=%s]%s[/color][/b] / %s" % [TdTheme.rich("ink"), row.have_text, row.need_text],
			"body", GOOD if row.done else TdTheme.color("ink.2"), 18)
		pl.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
		v.add_child(pl)
	if row.get("gold", false) and not row.done: h.add_child(_pay_column(row))
	return p

## The gold task's Pay (mockups upgrade-pay / upgrade-pay-nogold): a secondary "Pay 15" naming what it deposits
## (min(gold, missing): BackpackLogic.pay_text), and under it the muted "You have 15: pays what you can." when the
## gold is short, or with no gold the button disabled and the red 18 px "You have no gold. Missions give gold.".
func _pay_column(row: Dictionary) -> Control:
	var gold: int = GameApp.gold()
	var missing: int = int(row.get("missing", 0))
	var col := TdMenu.vbox(4)
	col.size_flags_vertical = SIZE_SHRINK_CENTER
	var b := TdMenu.button(TdButton.Style.SECONDARY, BackpackLogic.pay_text(gold, missing), Vector2(168, 52), TdDrops.gold_icon())
	b.size_flags_horizontal = SIZE_SHRINK_END
	var idx: int = int(row.get("index", -1))
	if BackpackLogic.pay_enabled(gold, missing): b.clicked.connect(func(): pay(idx))
	else: b.set_interactable(false, BackpackLogic.NoGold)
	pay_button = b
	col.add_child(b)
	var note := BackpackLogic.pay_note(gold, missing)
	if note.text != "":
		# the red line breaks after its first sentence, as the mockup ("You have no gold." / "Missions give gold.")
		var l := TdMenu.wrap_label(note.text.replace(". ", ".\n") if note.bad else note.text, "body", Color("#A3301F") if note.bad else TdTheme.color("ink.2"), 18)
		l.add_theme_font_override("font", TdTheme.font("nunito_extrabold" if note.bad else "nunito_bold"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size = Vector2(290, 0)
		col.add_child(l)
	return col

## Pay: deposits min(gold, missing) into the gold task (GameApp.pay_into saves), then redraws the view and every
## Backpack button. task_index -1 = the current step's gold task. Returns the gold deposited.
func pay(task_index := -1) -> int:
	var owned := _owned()
	if owned == null or _type == null: return 0
	if task_index < 0: task_index = TowerTasks.gold_task_index(TowerLevels.step_for(owned, _type, ladder))
	var got: int = GameApp.pay_into(owned, ladder, task_index)
	if got <= 0: return 0
	_reload_entries()
	refresh_view()
	TdBackpackButton.refresh_all(get_tree())
	changed.emit()
	return got

## The gold beat over the centre column ("★ Archer reached level 3!"), fading in.
func _beat_line(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.83, 0.42, 0.35)
	sb.border_color = Color("#C9952A")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := TdMenu.hbox(8)
	p.add_child(h)
	var st := TdMenu.picture(star_texture(), Vector2(24, 24))
	st.modulate = TdTheme.color("gold")
	st.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(st)
	var l := TdMenu.label(text, "header", Color("#7A4E00"), 22)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	h.add_child(l)
	p.modulate.a = 0.0
	TdTheme.tween(p).tween_property(p, "modulate:a", 1.0, 0.3)
	return p

## The Upgrade buttons' star (TdLvChip.star_texture).
static func star_texture() -> Texture2D:
	return TdLvChip.star_texture()

# ------------------------------------------------------------------ actions

## The confirm popup ("Upgrade Archer to level 3?" / "It gives +5 Max HP. The next level's tasks start counting."):
## the shared TdConfirm with the ladder's medallion, Cancel / Upgrade; Enter = Upgrade, Esc = Cancel.
func open_confirm() -> void:
	if view != "view" or confirm_open: return
	var owned := _owned()
	var act := UpgradeLogic.action(owned, _type, ladder, GameApp.blacksmith_unlocked())
	if act.kind != "upgrade": return
	var body := UpgradeLogic.confirm_body(owned, _type, ladder)
	var step := TowerLevels.step_for(owned, _type, ladder)
	var g := TowerLevels.bonuses_text(step.bonuses) if step != null else ""
	if g != "": body = body.replace(g, "[color=#7EE08A][b]%s[/b][/color]" % g)
	_confirm = TdConfirm.ask(self, UpgradeLogic.confirm_title(_type, ladder, act.to), body, "Upgrade",
		func(yes: bool): if yes: confirm_upgrade(),
		{"confirm_icon": star_texture()})

func cancel_confirm() -> void:
	if confirm_open: _confirm.cancel()

## Confirmed: raises the level (GameApp.upgrade_tower saves), shows the beat over the next level.
func confirm_upgrade() -> bool:
	if confirm_open: # called directly (tests, tools): close the question without answering it again
		_confirm.answer = true
		_confirm.close()
	var owned := _owned()
	if not GameApp.upgrade_tower(owned, ladder): return false
	beat = UpgradeLogic.beat_text(_type, ladder, TowerLevels.level_of(owned, ladder))
	_reload_entries()
	refresh_view()
	_beat_serial += 1
	var serial := _beat_serial
	get_tree().create_timer(BEAT_TIME, true, false, true).timeout.connect(func():
		if serial == _beat_serial and is_instance_valid(self) and beat != "":
			beat = ""
			if view == "view": _refresh_mid())
	changed.emit()
	return true

## Esc / right click: the confirm first, then the view, then the window.
func back() -> void:
	if confirm_open: cancel_confirm()
	elif view == "view": back_to_picker()
	else: close()

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open or not is_top() or not (event is InputEventKey) or not event.pressed or event.echo: return
	if confirm_open: return # the TdConfirm on top takes Enter / Esc
	var k: int = event.keycode
	if k != KEY_ENTER and k != KEY_KP_ENTER: return
	if view == "pick" and tower_id != "": open_view(tower_id)
	elif view == "view": open_confirm()
	get_viewport().set_input_as_handled()

## A task's progress bar (track + fill).
class TaskBar extends Control:
	var ratio := 0.0
	var colour := Color.WHITE
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		size_flags_horizontal = SIZE_EXPAND_FILL
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.18, 0.13, 0.09, 0.14)
		track.border_color = Color(0.37, 0.29, 0.21, 0.35)
		track.set_border_width_all(1)
		track.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(track, r)
		if ratio <= 0.0: return
		var fill := StyleBoxFlat.new()
		fill.bg_color = colour
		fill.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * clampf(ratio, 0.0, 1.0)), size.y)))
