extends TdPopup
## The Codex (UI_Codex.cs; Codex — Design; the Unity build's layout): tabs Towers / Enemies / Statuses / Tips,
## "5 / 9 discovered" with a gold bar, a list on the left (one row per entry: medallion, name, "• New" while new,
## a lock and "Not met yet" / towers "Not found yet" while undiscovered; every tower is listed, locked until owned or
## shown as a prize) and the selected entry's page on paper at the right: towers and enemies get a model
## preview turning (drag to turn), stat tiles, description and ability / passive rows (icon, cooldown pips, CD words,
## tags, description, result chips); statuses their icon, description and rules (lasts, again); tips their text with
## the player's keys (KeyBinds.fill_keys). Opening an entry marks it seen (SaveData.codex) and saves. Reusable from
## the main menu, the Camp and the pause menu: open(), close(), closed; open_at(section, id).
## Tower and enemy pages have page tabs (mockup codex2): Overview · Abilities · Forms · Immunities (Immunities disabled,
## Forms disabled on enemies: "Coming later"). The Forms page lists the base form and the forms some tower of yours has unlocked; picking one
## shows it on every page (the base row goes back). Read-only reference: no link to the Workshop.

const SECTIONS := [CodexSection.Towers, CodexSection.Enemies, CodexSection.Statuses, CodexSection.Tips]
const TAB_NAMES := ["Towers", "Enemies", "Statuses", "Tips"]
const TAB_ICONS := ["icon_castle", "icon_enemy", "icon_eye", "icon_info"]
const TAB_WIDTHS := [236.0, 262.0, 262.0, 180.0] # faces; TdButton adds its bleed room (Towers: room for "N new")
const WIDTH := 1700.0
## The header's progress block and its bar: one width whatever the count text says.
const PROGRESS_W := 246.0
const HEIGHT := 900.0
const STAT_ICONS := {"MaxHp": "icon_heart", "Power": "icon_power", "Potency": "icon_del-spark", "Duration": "icon_clock",
	"Speed": "icon_speed", "Range": "icon_range", "Radius": "icon_range"}

var section := CodexSection.Towers
var entries: Array = []
var selected: Dictionary = {}
var tab_buttons: Array = []
var rows: Array = []          # TdButton per entry

var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _progress: Label
var _bar_fill: Control
var _bar: Control
var _page_scroll: ScrollContainer
var _left: VBoxContainer
var _preview_card: PanelContainer
var _chip_card: PanelContainer
var _chip_icon: TextureRect
var _preview: TdModelPreview
var _picture: TextureRect
var _hint: Label
var _stats: GridContainer
var _facts: VBoxContainer
var _stage_badge: TextureRect
var _title: Label
var _subtitle: RichTextLabel
var _description: RichTextLabel
var _forms: VBoxContainer
## The page head (medallion with the form badge, title, subtitle) and the page tab strip.
var _page_top: VBoxContainer
var _head_medal: CenterContainer
var _strip: HBoxContainer
## The tower / enemy page shown: "overview" | "abilities" | "forms"; the form shown on every page ("" = default).
var page := "overview"
var form_id := ""
var _abilities_head: Control
var _abilities: VBoxContainer
var _body: RichTextLabel
var _locked_card: PanelContainer
var _locked_hint: Label
var _locked_overlay: CenterContainer
var _locked_pic: TextureRect
var _locked_title: Label
var _locked_kind: Label
var _cols: Control
var _pending: Array = []
var _abilities_gap: Control

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 28)
	p.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(20)
	p.add_child(col)
	# header: title, tabs, progress, close
	var head := TdMenu.hbox(16)
	col.add_child(head)
	var t := TdMenu.label("Codex", "display", TdTheme.color("cream.100"), 64)
	t.custom_minimum_size = Vector2(200, 0)
	head.add_child(t)
	var tabs := TdMenu.hbox(14)
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(tabs)
	var icons := []
	for n in TAB_ICONS: icons.append(TdTheme.texture(n))
	tab_buttons = TdMenu.tabs(tabs, TAB_NAMES, icons, Vector2(220, 64), func(i): show_section(SECTIONS[i]))
	for k in TAB_WIDTHS.size(): # wide enough for the label + its "N new" pill with 16 px padding
		tab_buttons[k].custom_minimum_size.x = TAB_WIDTHS[k]
		tab_buttons[k].size.x = TAB_WIDTHS[k]
		tab_buttons[k].size_flags_vertical = SIZE_SHRINK_CENTER # 64 px faces, not stretched to the title's line height
	var prog := TdMenu.vbox(6)
	prog.custom_minimum_size = Vector2(PROGRESS_W, 0) # a fixed block: the bar has the same width on every tab
	prog.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(prog)
	_progress = TdMenu.label("", "header", TdTheme.color("cream.100"), 28)
	_progress.clip_text = true # never widens the block
	prog.add_child(_progress)
	_bar = Panel.new()
	_bar.custom_minimum_size = Vector2(PROGRESS_W, 10)
	_bar.size_flags_horizontal = SIZE_SHRINK_BEGIN
	var bg := StyleBoxFlat.new()
	bg.bg_color = TdTheme.color("wood.900")
	bg.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("panel", bg)
	prog.add_child(_bar)
	_bar_fill = Panel.new()
	var fill := StyleBoxFlat.new()
	fill.bg_color = TdTheme.color("gold")
	fill.set_corner_radius_all(5)
	_bar_fill.add_theme_stylebox_override("panel", fill)
	_bar_fill.size = Vector2(0, 10)
	_bar.add_child(_bar_fill)
	var x := TdMenu.close_button()
	x.size_flags_vertical = SIZE_SHRINK_CENTER # its 52 px face, not stretched to the title row
	x.clicked.connect(close)
	head.add_child(x)
	# body: list + page
	var body := TdMenu.hbox(28)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(body)
	var well := TdMenu.panel(TdPanel.Kind.WELL, 12)
	well.custom_minimum_size = Vector2(336, 0)
	body.add_child(well)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TdDragScroll.attach(_list_scroll)
	well.add_child(_list_scroll)
	_list = TdMenu.vbox(16)
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	var page := TdMenu.panel(TdPanel.Kind.PAPER, 24)
	page.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(page)
	# the model box and stat tiles stay put on the left; only the text column on the right scrolls
	var cols := TdMenu.hbox(30)
	cols.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	var pagecol := TdMenu.vbox(0)
	pagecol.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_child(pagecol)
	_page_top = TdMenu.vbox(0)
	pagecol.add_child(_page_top)
	var phead := TdMenu.hbox(14)
	_page_top.add_child(phead)
	_head_medal = CenterContainer.new()
	_head_medal.size_flags_vertical = SIZE_SHRINK_CENTER
	phead.add_child(_head_medal)
	var hv := TdMenu.vbox(0)
	hv.size_flags_vertical = SIZE_SHRINK_CENTER
	phead.add_child(hv)
	_title = TdMenu.label("", "display", TdTheme.color("accent.ink"), 50)
	hv.add_child(_title)
	_subtitle = TdMenu.rich("", "body", TdTheme.color("ink.2"), 26)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	hv.add_child(_subtitle)
	_strip = TdMenu.hbox(6)
	_page_top.add_child(_strip)
	var rule := HSeparator.new()
	var rs := StyleBoxLine.new()
	rs.color = Color(TdTheme.color("ink.2"), 0.3)
	rs.thickness = 2
	rule.add_theme_stylebox_override("separator", rs)
	_page_top.add_child(rule)
	_page_top.add_child(TdMenu.spacer(10))
	pagecol.add_child(cols)
	_cols = cols
	# an undiscovered entry: one compact card in the middle of the page (silhouette, muted ???, kind, hint)
	_locked_overlay = CenterContainer.new()
	_locked_overlay.visible = false
	page.add_child(_locked_overlay)
	_locked_card = PanelContainer.new()
	var lc := StyleBoxFlat.new()
	lc.bg_color = Color(TdTheme.color("paper.edge"), 0.35)
	lc.border_color = TdTheme.color("paper.edge")
	lc.set_border_width_all(2)
	lc.set_corner_radius_all(14)
	lc.set_content_margin_all(28)
	_locked_card.add_theme_stylebox_override("panel", lc)
	_locked_card.custom_minimum_size = Vector2(480, 0)
	_locked_overlay.add_child(_locked_card)
	var lv := TdMenu.vbox(10)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	_locked_card.add_child(lv)
	var lcen := CenterContainer.new()
	lv.add_child(lcen)
	_locked_pic = TdMenu.picture(null, Vector2(128, 128))
	lcen.add_child(_locked_pic)
	_locked_title = TdMenu.label("Not met yet", "display", TdTheme.color("ink.2"), 40)
	_locked_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_locked_title)
	_locked_kind = TdMenu.label("", "body", TdTheme.color("ink.2"), 22)
	_locked_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_locked_kind)
	_locked_hint = TdMenu.wrap_label("", "body", TdTheme.color("ink"), 24)
	_locked_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_locked_hint)
	_left = TdMenu.vbox(16)
	_left.custom_minimum_size = Vector2(276, 0)
	cols.add_child(_left)
	_preview_card = PanelContainer.new()
	var card := StyleBoxFlat.new()
	card.bg_color = Color(TdTheme.color("paper.edge"), 0.55)
	card.border_color = TdTheme.color("paper.edge")
	card.set_border_width_all(2)
	card.set_corner_radius_all(10)
	_preview_card.add_theme_stylebox_override("panel", card)
	_preview_card.custom_minimum_size = Vector2(276, 364)
	_left.add_child(_preview_card)
	# a status's icon: a small chip box of its own (the model card is for units)
	_chip_card = PanelContainer.new()
	_chip_card.add_theme_stylebox_override("panel", card)
	_chip_card.custom_minimum_size = Vector2(150, 150)
	_chip_card.size_flags_horizontal = SIZE_SHRINK_BEGIN
	var cc := CenterContainer.new()
	_chip_card.add_child(cc)
	_chip_icon = TdMenu.picture(null, Vector2(104, 104))
	cc.add_child(_chip_icon)
	_left.add_child(_chip_card)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(276, 364)
	_preview_card.add_child(stage)
	_preview = TdModelPreview.new()
	_preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_preview.offset_bottom = -44
	stage.add_child(_preview)
	_picture = TdMenu.picture(null, Vector2(160, 160))
	_picture.set_anchors_and_offsets_preset(PRESET_CENTER)
	_picture.offset_left = -80; _picture.offset_right = 80; _picture.offset_top = -100; _picture.offset_bottom = 60
	stage.add_child(_picture)
	_hint = TdMenu.label("‹  Drag to turn  ›", "small", TdTheme.color("ink.2"), 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_hint.offset_top = -40; _hint.offset_bottom = -10
	stage.add_child(_hint)
	# a formed tower's badge: a 48 px overlay at the preview frame's top-right (not on the model)
	_stage_badge = TextureRect.new()
	_stage_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stage_badge.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_stage_badge.offset_left = -64; _stage_badge.offset_right = -16; _stage_badge.offset_top = 16; _stage_badge.offset_bottom = 64
	_stage_badge.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(_stage_badge)
	# the Overview's wide 2 × 2 stat tiles and facts sit in the text column, beside the model (mockup codex2)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 10)
	_stats.size_flags_horizontal = SIZE_EXPAND_FILL
	_facts = TdMenu.vbox(10)
	_page_scroll = ScrollContainer.new()
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(_page_scroll)
	TdDragScroll.attach(_page_scroll, true)
	# room for rims (sprite outsets) the scroll area would clip, and the text column capped at ~60 characters a line
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "top", "bottom"]: pad.add_theme_constant_override("margin_" + side, 6)
	pad.add_theme_constant_override("margin_right", 22)
	_page_scroll.add_child(pad)
	var right := TdMenu.vbox(14)
	right.size_flags_horizontal = SIZE_EXPAND_FILL # rows and ability lists use the page's full width (mockup codex2)
	pad.add_child(right)
	_description = TdMenu.rich("", "body", TdTheme.color("ink"), 24)
	right.add_child(_description)
	right.add_child(TdTowerCard.bleed_margin(_stats))
	right.add_child(_facts)
	_body = TdMenu.rich("", "body", TdTheme.color("ink"), 24)
	right.add_child(_body)

	_abilities_head = TdMenu.hbox(16)
	var ah := TdMenu.label("Abilities", "h2", TdTheme.color("ink"), 34)
	_abilities_head.add_child(ah)
	var line := HSeparator.new()
	line.size_flags_horizontal = SIZE_EXPAND_FILL
	var ls := StyleBoxLine.new()
	ls.color = Color(TdTheme.color("ink.2"), 0.45)
	ls.thickness = 2
	line.add_theme_stylebox_override("separator", ls)
	_abilities_head.add_child(line)
	_abilities_gap = TdMenu.spacer(6)
	right.add_child(_abilities_gap)
	right.add_child(_abilities_head)
	_abilities = TdMenu.vbox(0)
	right.add_child(_abilities)
	# a tower's Forms page: the forms some tower of yours has unlocked (Workshop — Design § Codex; mockup codex2)
	_forms = TdMenu.vbox(10)
	right.add_child(_forms)

func _on_open() -> void:
	catch_up()
	if not _pending.is_empty():
		var s: int = _pending[0]
		var id: String = _pending[1]
		_pending = []
		show_section(s)
		for e in entries:
			if e.id == id:
				select(e)
				break
	else:
		show_section(section)

## Opens at an entry (e.g. from a unit's info popup).
func open_at(s: int, id: String) -> void:
	_pending = [s, id]
	open()

## Records what the save already proves the player has met (towers owned, enemies of levels played).
static func catch_up() -> void:
	var data: GameData = SaveData.data
	var catalog: GameCatalogAsset = GameApp.catalog
	if catalog == null: return
	var found := MenuLogic.discover_owned(data.codex, data.towers, catalog)
	var levels := [catalog.tutorial]
	for e in catalog.entries(): levels.append(e[0].level)
	for l in levels:
		if l == null or data.progress.find(l.get_id()) == null: continue
		for enemy in CodexAsset.enemies_of(l): found = data.codex.discover(CodexSection.Enemies, enemy.get_id()) or found
	if found: SaveData.save()

func _known(e: Dictionary) -> bool:
	return SaveData.codex.is_discovered(e.section, e.id)

## Shows a section's list and selects its first discovered entry.
func show_section(s: int) -> void:
	section = s
	for i in SECTIONS.size():
		tab_buttons[i].selected = SECTIONS[i] == s
		var n := _new_count(SECTIONS[i])
		_tab_new(i, n)
	# every entry is listed; undiscovered ones (towers too, like enemies) are locked rows (MenuLogic.codex_list)
	entries = MenuLogic.codex_list(GameApp.catalog.codex if GameApp.catalog != null else null, s, SaveData.codex)
	var total := entries.size()
	for r in rows: r.queue_free()
	rows.clear()
	for e in entries: rows.append(_make_row(e))
	var known := MenuLogic.codex_known_count(entries)
	_progress.text = MenuLogic.codex_progress_text(s, known, total)
	_bar.visible = s != CodexSection.Tips and entries.size() > 0
	_bar_fill.size = Vector2(_bar.custom_minimum_size.x * (float(known) / maxf(1.0, total)), 10)
	_bar_fill.visible = known > 0
	TdMenu.pop_in(rows, 0.02)
	var first: Dictionary = entries[0] if not entries.is_empty() else {}
	for e in entries:
		if _known(e):
			first = e
			break
	select(first)

## "Enemies [2 new]": an inline pill after the tab's label (the label moves left to make room).
func _tab_new(i: int, n: int) -> void:
	var b: TdButton = tab_buttons[i]
	var old = b.get_meta("new_pill") if b.has_meta("new_pill") else null
	if old != null and is_instance_valid(old): old.queue_free()
	b.remove_meta("new_pill")
	var f: Font = TdTheme.font("plinth")
	var p := TdMenu.pill("[b]%d new[/b]" % n, TdTheme.color("accent.fill"), Color.WHITE, 18)
	var room := 10.0 + 22.0 + TdTheme.font("nunito_extrabold").get_string_size("%d new" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	b.text = TAB_NAMES[i] + (" ".repeat(ceili(room / f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x)) if n > 0 else "")
	if n <= 0:
		p.free()
		return
	p.mouse_filter = MOUSE_FILTER_IGNORE
	b.face_node().add_child(p)
	b.set_meta("new_pill", p)
	var place := func() -> void:
		if not is_instance_valid(p): return
		var w := f.get_string_size(TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		p.position = Vector2(b._label.position.x + w + 10.0, (b.face_rect().size.y - p.size.y) / 2.0)
	place.call_deferred()

func _new_count(s: int) -> int:
	var n := 0
	for e in MenuLogic.codex_entries(GameApp.catalog.codex if GameApp.catalog != null else null, s):
		if SaveData.codex.is_new(e.section, e.id): n += 1
	return n

func _make_row(e: Dictionary) -> TdButton:
	var b := TdButton.new()
	b.style = TdButton.Style.ROW
	b.custom_minimum_size = Vector2(268, 60) # + the button's bleed room: fits the list beside its scrollbar
	b.size = Vector2(268, 60)
	b.selectable = true
	b.clicked.connect(func(): select(e))
	_list.add_child(b)
	_draw_row(b, e)
	return b

func _draw_row(b: TdButton, e: Dictionary) -> void:
	for c in b.face_node().get_children():
		if c.has_meta("row_part"): c.queue_free()
	var known := _known(e)
	var tex: Texture2D = null
	if known: tex = _entry_picture(e)
	var icon: Control
	var kit_medal := _kit_medallion(e, "medallion_256")
	if not known:
		icon = TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(26, 26)) # a lock, "Not met yet" / "Not found yet" (no "???")
		icon.modulate = TdTheme.color("cream.300")
		icon.position = Vector2(7, 7)
	elif e.section == CodexSection.Towers and kit_medal != null:
		icon = TdMenu.picture(kit_medal, Vector2(40, 40)) # the kit's medallion, mipmapped down
	elif e.section == CodexSection.Towers or e.section == CodexSection.Enemies:
		icon = TdMenu.medallion(tex, 40, e.section == CodexSection.Enemies)
	else:
		icon = TdMenu.picture(tex if tex != null else TdTheme.texture("icon_info"), Vector2(36, 36))
	icon.position += Vector2(12, 10)
	icon.set_meta("row_part", true)
	b.face_node().add_child(icon)
	var l := TdMenu.label(e.name if known else MenuLogic.locked_title(e.section), "header", TdTheme.color("cream.100") if known else TdTheme.color("cream.300"), 26 if known else 22)
	var dot := known and SaveData.codex.is_new(e.section, e.id)
	l.position = Vector2(66, 0)
	l.size = Vector2(140 if dot else 194, 60)
	# a long name ("Placing towers") steps down in size until it fits, instead of losing its end to the ellipsis
	var lf: Font = l.get_theme_font("font")
	var lfs: int = l.get_theme_font_size("font_size")
	while lfs > 20 and lf.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x > l.size.x:
		lfs -= 1
	l.add_theme_font_size_override("font_size", lfs)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.set_meta("row_part", true)
	b.face_node().add_child(l)
	if dot:
		var n := TdMenu.label("• New", "small", TdTheme.color("accent.light"), 20)
		n.position = Vector2(204, 0)
		n.size = Vector2(60, 60)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.mouse_filter = MOUSE_FILTER_IGNORE
		n.set_meta("row_part", true)
		b.face_node().add_child(n)
	b.selected = not selected.is_empty() and selected.section == e.section and selected.id == e.id

## The kit's per-unit medallion (units/<folder>/<icon name>.png: medallion_256, locked_128), or null.
static func _kit_medallion(e: Dictionary, folder: String) -> Texture2D:
	if e.section != CodexSection.Towers and e.section != CodexSection.Enemies: return null
	var n := MenuLogic.icon_name(e.icon)
	return TdTheme.kit("units/%s/%s" % [folder, n]) if n != "" else null

func _entry_picture(e: Dictionary) -> Texture2D:
	var a = e.asset
	if a is TowerAsset: return TdMenu.unit_picture(a.entity.view if a.entity != null else "", e.icon)
	if a is EntityAsset: return TdMenu.unit_picture(a.view, e.icon)
	return GameApp.icon_texture(e.icon) if e.icon != "" else null

## Selects an entry (an empty Dictionary: nothing), marks it seen, shows its page.
func select(e: Dictionary) -> void:
	if e.get("id", "") != selected.get("id", "") or e.get("section", -1) != selected.get("section", -1):
		page = "overview"
		form_id = ""
	selected = e
	if not e.is_empty() and _known(e) and SaveData.codex.mark_viewed(e.section, e.id):
		SaveData.save()
		var n := _new_count(e.section)
		_tab_new(SECTIONS.find(e.section), n)
	for i in entries.size(): _draw_row(rows[i], entries[i])
	_show_page(e)
	_page_scroll.scroll_vertical = 0

# ------------------------------------------------------------------ the page

func _show_page(e: Dictionary) -> void:
	for c in _stats.get_children(): c.queue_free()
	for c in _facts.get_children(): c.queue_free()
	_stage_badge.texture = null
	_stats.visible = true
	_facts.visible = true
	for c in _abilities.get_children(): c.queue_free()
	for c in _forms.get_children(): c.queue_free()
	_description.text = ""
	_body.text = ""
	_body.visible = true
	_stats.get_parent().visible = true
	_abilities_gap.visible = true
	_locked_overlay.visible = false
	_cols.visible = true
	_abilities_head.visible = false
	_preview.clear()
	_preview.visible = false
	_picture.visible = false
	_picture.offset_left = -80; _picture.offset_right = 80; _picture.offset_top = -100; _picture.offset_bottom = 60
	_hint.visible = false
	_left.visible = true
	_preview_card.visible = true
	_chip_card.visible = false
	_left.custom_minimum_size.x = 276.0
	_subtitle.visible = true
	_description.size_flags_horizontal = SIZE_EXPAND_FILL
	_description.custom_minimum_size = Vector2.ZERO
	_title.add_theme_color_override("font_color", TdTheme.color("accent.ink"))
	_page_top.visible = true
	_strip.visible = false
	_forms.visible = false
	_description.visible = true
	_abilities.visible = true
	TdCollection.clear_children(_head_medal)
	_head_medal.visible = false
	if e.is_empty():
		_title.text = ""
		_subtitle.text = ""
		_body.text = "Nothing here yet."
		_left.visible = false
		return
	if not _known(e):
		_cols.visible = false
		_page_top.visible = false
		_locked_overlay.visible = true
		_locked_pic.texture = TdTheme.texture("lock_badge")
		var n := _locked_pic.texture.get_size() * (0.5 if _locked_pic.texture == TdTheme.texture("lock_badge") else 1.0)
		_locked_pic.custom_minimum_size = n
		_locked_title.text = MenuLogic.locked_title(e.section)
		_locked_kind.text = MenuLogic.section_name(e.section)
		_locked_hint.text = MenuLogic.locked_text(e.section)
		_locked_hint.visible = _locked_hint.text != ""
		return
	var a = e.asset
	if a is TowerAsset:
		_tower_page(a)
	elif a is EntityAsset:
		_title.text = MenuLogic.entity_name(a)
		_title.add_theme_color_override("font_color", TdTheme.color("bad.ink"))
		_subtitle.text = "Enemy · Boss" if a.tags.has(Tags.Boss) else "Enemy"
		_unit_page(a, a.description)
		_build_strip(ENEMY_PAGES, null)
		_apply_page()
	elif a is StatusAsset:
		var d: StatusDef = GameApp.convert.status(a)
		_title.text = d.display_name
		_title.add_theme_color_override("font_color", TdTheme.color("bad.ink") if d.tags.has(Tags.Debuff) else (TdTheme.color("good.ink") if d.tags.has(Tags.Buff) else TdTheme.color("status.ink")))
		_subtitle.text = MenuLogic.status_kind(d.tags)
		var desc := MenuLogic.status_description(d.description, 1, d.duration, TdTheme.rich("gold.ink")) if d.description != "" else "No description."
		_description.text = TooltipText.describe(TooltipText.from_rich(desc))
		var rows := []
		if d.duration >= 0: rows.append(TooltipText.row("Lasts", MenuLogic.lasts_text(d.duration, d.duration_unit == DurationUnit.Rounds)))
		rows.append(TooltipText.row("Again", MenuLogic.stacking_shown(d.stacking, d.max_stacks)))
		_body.text = "\n".join(PackedStringArray(rows))
		_chip_icon.texture = GameApp.icon_texture(a.icon) if a.icon != "" else null
		_chip_card.visible = _chip_icon.texture != null
		_preview_card.visible = false
		_left.custom_minimum_size.x = 150.0 # the text starts right after the small chip box
	else:
		var tip: CodexTip = e.tip
		_title.text = tip.title
		_subtitle.text = ""
		_subtitle.visible = false
		_description.text = TooltipText.describe(KeyBinds.fill_keys(tip.text).replace("End Turn", "End turn"))

		var img: Texture2D = GameApp.icon_texture(tip.image) if tip.image != "" else null
		_picture.texture = img
		_picture.visible = img != null
		_left.visible = img != null

func _unit_page(entity: EntityAsset, description: String) -> void:
	if entity == null: return
	var d: EntityDef = GameApp.convert.entity(entity)
	_description.text = TooltipText.describe(description)
	var sc: PackedScene = GameApp.model_scene(entity.view)
	_preview.visible = sc != null
	_hint.visible = sc != null
	if sc != null: _preview.show_model(sc)
	else:
		_picture.texture = TdMenu.unit_picture(entity.view, entity.icon)
		_picture.visible = _picture.texture != null
	var me := DefStats.new(d)
	var vocab: Vocabulary = GameApp.rules.vocabulary if GameApp.rules != null else CombatVocabulary.create()
	var values := {}
	var tiles := stat_tiles(me, vocab)
	_stats.columns = 2 # always two per row, extra stats go down, never a third column (Eren 2026-10-15)
	for tile in tiles:
		_stats.add_child(TdTowerCard.stat_tile(tile[0], tile[1], tile[2], 200))
		if tile[0] != "MaxHp": values[tile[0]] = tile[2]
	var passives := PassiveView.of(d)
	_abilities_head.visible = d.abilities.size() + passives.size() > 0
	for ab in d.abilities:
		var icon := TdTowerCard.ability_icon(ab)
		var pips := 0 if ab.cooldown_until_reset else maxi(1, ab.cooldown)
		_abilities.add_child(_ability_row(icon, ab.display_name, ability_kind(ab),
			TooltipText.describe(MenuLogic.fill_stat_words(ab.description, values)), TooltipText.cooldown_words(ab.cooldown, ab.cooldown_until_reset), pips,
			result_tags(ab, me, vocab), false))
	for pv in passives:
		var asset = GameApp.convert.asset_of(pv.def, "PassiveAsset")
		var icon: Texture2D = GameApp.icon_texture(asset.icon) if asset != null and asset.icon != "" else null
		_abilities.add_child(_ability_row(icon, pv.name, "Passive", TooltipText.describe(MenuLogic.fill_stat_words(pv.def.description, values)), "Always on", 0, [], true))

## A unit page's tabs, built from a list so pages can be added: [id, label, enabled]. The same strip on towers and
## enemies; a disabled tab (Immunities everywhere, Forms on enemies) is dimmed, not clickable, tooltip "Coming later"
## (user decisions 2026-10-14).
const TOWER_PAGES := [["overview", "Overview", true], ["abilities", "Abilities", true], ["forms", "Forms", true], ["immunities", "Immunities", false]]
const ENEMY_PAGES := [["overview", "Overview", true], ["abilities", "Abilities", true], ["forms", "Forms", false], ["immunities", "Immunities", false]]

## A tower's page (mockup codex2): the head shows the form picked on the Forms page (badge, "Form of Archer"; the
## base row goes back); Overview = model, stats, description; Abilities = abilities and passives; Forms = the rows.
func _tower_page(t: TowerAsset) -> void:
	var type := GameApp.tower_type(t.get_id())
	var ids := WorkshopLogic.codex_form_ids(SaveData.towers, type)
	if not ids.has(form_id): form_id = ""
	var fa: FormAsset = GameApp.catalog.find_form(form_id) if form_id != "" else null
	_head_medal.visible = true
	var ent: EntityAsset = fa.entity if fa != null and fa.entity != null else t.entity
	var pic := TdMenu.unit_picture(ent.view if ent != null else "", fa.icon if fa != null else t.icon)
	var hm := TdTowerCard.medallion(pic, 64, MenuLogic.form_badge(fa))
	_head_medal.add_child(hm)
	# Upgrades — Design: the highest level among your towers of this type (in this form) once the Blacksmith is open
	if TdLvChip.shown(): TdLvChip.attach(hm, UpgradeLogic.best_level(SaveData.towers.towers, t.get_id(), form_id), 64)
	if fa != null:
		_title.text = fa.get_display_name()
		_subtitle.text = WorkshopLogic.subtitle(type, form_id)
	else:
		_title.text = t.get_display_name()
		_subtitle.text = "Tower · [b][color=%s]%d[/color][/b] energy" % [TdTheme.rich("gold.ink"), t.cost]
	_unit_page(ent, fa.description if fa != null and fa.description != "" else t.description)
	var bp := MenuLogic.form_badge(fa)
	_stage_badge.texture = load(bp) if bp != "" else null
	_tower_facts(t, fa, ent)
	_build_strip(TOWER_PAGES, type)
	if page == "forms": _forms_rows(t, type, ids)
	_apply_page()

## The Overview's facts (mockup codex2): energy, role chips, "In your collection: 6" (no "First earned", Eren 2026-10-15).
func _tower_facts(t: TowerAsset, fa: FormAsset, ent: EntityAsset) -> void:
	var cost := fa.cost if fa != null and fa.cost >= 0 else t.cost
	_facts.add_child(_fact("icon_energy", "[color=%s][b]%d[/b][/color] energy" % [TdTheme.rich("ink"), cost], TdTheme.color("gold.ink")))
	var def: EntityDef = GameApp.convert.entity(ent) if ent != null else null
	var roles: Array = HandLogic.traits(def).roles
	if not roles.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		for r in roles:
			var dot: Color = HandLogic.ROLE_COLORS.get(r, TdTheme.color("ink.2"))
			chips.add_child(TdMenu.pill("[color=%s]●[/color] [b]%s[/b]" % [dot.to_html(false), r], Color(0.18, 0.13, 0.09, 0.06), TdTheme.color("ink"), 18,
				Color(0.37, 0.29, 0.21, 0.3)))
		_facts.add_child(chips)
	# no "In your collection" and no "Levels" list on the page (Eren 2026-10-17: "codex'te buralar olmayacak")
	# Upgrades — Design § Codex: read-only "Levels", what each level gives (the shown form's own ladder); no tasks.
	# Not before the Blacksmith opens (nothing shows levels then).
	if false and TdLvChip.shown():
		var lines := UpgradeLogic.codex_levels(GameApp.tower_type(t.get_id()), fa.get_id() if fa != null else "")
		if not lines.is_empty():
			var parts := []
			for line in lines:
				var cut: int = line.find(":")
				parts.append("[b][color=%s]%s[/color][/b]%s" % [TdTheme.rich("ink"), line.substr(0, cut + 1), line.substr(cut + 1)])
			var lf := _fact("icon_plus", "[b]Levels[/b]\n" + "\n".join(parts))
			lf.get_child(0).size_flags_vertical = SIZE_SHRINK_BEGIN # the icon by the "Levels" heading, not mid-list
			_facts.add_child(lf)

func _fact(icon: String, bbcode: String, tint := Color(0, 0, 0, 0)) -> Control:
	var h := TdMenu.hbox(8)
	var ic := TdMenu.picture(TdTheme.texture(icon), Vector2(20, 20))
	ic.modulate = tint if tint.a > 0 else TdTheme.color("ink.2")
	ic.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := TdMenu.rich(bbcode, "body", TdTheme.color("ink.2"), 20)
	l.add_theme_font_override("normal_font", TdTheme.font("nunito_bold"))
	h.add_child(l)
	return h

## The page tab strip (an underlined tab per page; disabled ones dimmed with "Coming later").
func _build_strip(pages: Array, type: TowerType) -> void:
	TdCollection.clear_children(_strip)
	_strip.visible = true
	for pg in pages:
		var id: String = pg[0]
		var label: String = pg[1]
		var b := PageTab.new()
		b.text = label
		b.on = page == id
		b.enabled = pg[2]
		if pg[2]: b.pressed.connect(func(): show_page_tab(id))
		else: TdTooltipTrigger.attach(b, "", "Coming later")
		_strip.add_child(b)

## Shows one page of the selected unit.
func show_page_tab(id: String) -> void:
	page = id
	_show_page(selected)
	_page_scroll.scroll_vertical = 0

## Shows a form on every page of the selected tower ("" = the default form).
func show_form(id: String) -> void:
	form_id = id
	_show_page(selected)

func _apply_page() -> void:
	_left.visible = page == "overview"
	_description.visible = page == "overview"
	_stats.visible = page == "overview"
	_facts.visible = page == "overview"
	_abilities.visible = page == "abilities"
	_abilities_head.visible = false
	_forms.visible = page == "forms"
	_tidy_column()

## Hidden blocks leave nothing behind in the text column: the stat tiles' bleed wrapper, an empty body, the gap
## before the (hidden) abilities heading — else the Abilities and Forms pages start ~70 px down.
func _tidy_column() -> void:
	_stats.get_parent().visible = _stats.visible
	_body.visible = _body.text != ""
	_abilities_gap.visible = _abilities_head.visible

## The Forms page rows: "Archer · Base form" first (a row like the others), then the unlocked forms; a click shows
## that form on every page; only the base row: "Unlock more forms in the Workshop.". Read-only: no Workshop link.
func _forms_rows(t: TowerAsset, type: TowerType, ids: Array) -> void:
	for id in ids:
		var fa: FormAsset = GameApp.catalog.find_form(id) if id != "" else null
		var row := FormRow.new()
		row.selected = id == form_id
		row.pressed.connect(func(): show_form(id))
		var h := TdMenu.hbox(16)
		h.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(h)
		var ent: EntityAsset = fa.entity if fa != null and fa.entity != null else t.entity
		var m := TdTowerCard.medallion(TdMenu.unit_picture(ent.view if ent != null else "", fa.icon if fa != null else t.icon), 64, MenuLogic.form_badge(fa))
		m.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(m)
		var v := TdMenu.vbox(0)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		v.size_flags_vertical = SIZE_SHRINK_CENTER
		v.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(v)
		var nm := WorkshopLogic.codex_row_name(type, id)
		var nl := TdMenu.label(nm, "header", TdTheme.color("ink"), 24)
		nl.add_theme_font_override("font", TdTheme.font("plinth"))
		v.add_child(nl)
		var sl := TdMenu.label(WorkshopLogic.codex_row_sub(type, id), "body", TdTheme.color("ink.2"), 18)
		sl.add_theme_font_override("font", TdTheme.font("nunito_bold"))
		v.add_child(sl)
		_forms.add_child(row)
	if ids.size() == 1:
		var e := TdMenu.label("Unlock more forms in the Workshop.", "body", TdTheme.color("ink.2"), 20)
		_forms.add_child(e)

## A page tab (mockup .cx-pg): the label, underlined in ink when on; disabled: 45 % and not clickable.
class PageTab extends Control:
	signal pressed
	var text := ""
	var on := false
	var enabled := true
	var _hover := false
	var _label: Label
	func _ready() -> void:
		_label = TdMenu.label(text, "body", TdTheme.color("ink") if on or _hover else TdTheme.color("ink.2"), 20)
		_label.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
		_label.position = Vector2(16, 6)
		_label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_label)
		custom_minimum_size = Vector2(_label.get_minimum_size().x + 32, 44)
		modulate.a = 1.0 if enabled else 0.45
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if enabled else CURSOR_ARROW
		mouse_entered.connect(func(): _hover = true; _restyle())
		mouse_exited.connect(func(): _hover = false; _restyle())
	func _restyle() -> void:
		if enabled: _label.add_theme_color_override("font_color", TdTheme.color("ink") if on or _hover else TdTheme.color("ink.2"))
	func _draw() -> void:
		if on: draw_rect(Rect2(8, size.y - 4, size.x - 16, 4), TdTheme.color("ink"))
	func _gui_input(event: InputEvent) -> void:
		if enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit()
			accept_event()

## A Forms row (mockup .cx-frow): a rounded paper row, cobalt outline when selected; click = show that form.
class FormRow extends PanelContainer:
	signal pressed
	var selected := false
	var _hover := false
	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; _restyle())
		mouse_exited.connect(func(): _hover = false; _restyle())
		_restyle.call_deferred()
	func _restyle() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.73, 1.0, 0.12) if selected else Color(0.18, 0.13, 0.09, 0.12 if _hover else 0.06)
		sb.border_color = TdTheme.color("accent.light") if selected else Color(0.37, 0.29, 0.21, 0.3)
		sb.set_border_width_all(3 if selected else 2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 12; sb.content_margin_bottom = 12
		add_theme_stylebox_override("panel", sb)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit()

## The result tags shown under an ability: AbilityText.tags plus how long a status it applies lasts ("2 Duration",
## from the Apply Status step's duration, else the status's own) when AbilityText leaves it out (it only names a
## duration that scales).
static func result_tags(ab: AbilityDef, me: IEntity, vocab: Vocabulary) -> Array:
	return TdTowerCard.result_tags(ab, me, vocab)

## An ability's type words ("Attack · Projectile"); an ability without tags is named from what it does: a status
## that controls (taunt, stun, root…) → "Control", healing → "Support", a move → "Movement".
static func ability_kind(ab: AbilityDef) -> String:
	return HandLogic.ability_kind(ab)

## The stat tiles (EntityText.StatTiles): Max HP first, then Power, Potency, Duration, Speed, Range, Radius the unit
## has. Array of [stat, label, value text].
static func stat_tiles(me: IEntity, vocab: Vocabulary) -> Array:
	var out := []
	var hp := me.stat("MaxHp")
	if hp > 0: out.append(["MaxHp", "Max HP", _num(hp)])
	for s in ["Power", "Potency", "Duration", "Speed", "Range", "Radius"]:
		var v = AbilityText.speed(me, vocab) if s == "Speed" else AbilityText.own_stat(me, s, vocab)
		if v != null: out.append([s, s, _num(v)])
	return out

static func _num(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else str(snappedf(f, 0.01))

func _ability_row(icon: Texture2D, name_text: String, tags: String, description: String, cd: String, pips: int,
		results: Array, passive: bool) -> Control:
	var row := MarginContainer.new()
	row.add_theme_constant_override("margin_top", 16)
	row.add_theme_constant_override("margin_bottom", 16)
	var h := TdMenu.hbox(24)
	row.add_child(h)
	var left := TdMenu.vbox(6)
	left.custom_minimum_size = Vector2(104, 0)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	h.add_child(left)
	var icon_box := CenterContainer.new()
	left.add_child(icon_box)
	if passive:
		icon_box.add_child(TdMenu.picture(icon, Vector2(88, 88))) # the passive's double-rim square chip (circles are statuses)
	else:
		var ic := TdMenu.picture(icon, Vector2(88, 88))
		icon_box.add_child(ic)
	if pips > 0:
		var pr := TdMenu.hbox(4)
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in mini(pips, 6):
			pr.add_child(_pip()) # brown / gold pips (blue means active)
		left.add_child(pr)
	var cdl := TdMenu.label(cd, "small", TdTheme.color("ink"), 20)
	cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(cdl)
	var right := TdMenu.vbox(4)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(right)
	var name_row := TdMenu.hbox(12)
	right.add_child(name_row)
	name_row.add_child(TdMenu.label(name_text, "h3", TdTheme.color("gold.ink"), 30)) # one name colour for abilities and passives (the chip carries the role)
	if tags != "":
		var tl := TdMenu.label(tags, "small", TdTheme.color("ink.2"), 20)
		tl.size_flags_vertical = SIZE_SHRINK_CENTER
		name_row.add_child(tl)
	right.add_child(TdMenu.rich(description, "body", TdTheme.color("ink"), 22))
	# the pill line sits at the row's bottom, on the baseline of the "1 turn CD" label under the icon
	right.size_flags_vertical = SIZE_FILL
	var push := Control.new()
	push.size_flags_vertical = SIZE_EXPAND_FILL
	push.mouse_filter = MOUSE_FILTER_IGNORE
	right.add_child(push)
	if not results.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 12)
		chips.add_theme_constant_override("v_separation", 8)
		for r in results: chips.add_child(_chip(str(r[0]), str(r[1])))
		right.add_child(chips)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(row)
	var sep := HSeparator.new()
	var ls := StyleBoxLine.new()
	ls.color = Color(TdTheme.color("ink.2"), 0.3)
	ls.thickness = 2
	sep.add_theme_stylebox_override("separator", ls)
	box.add_child(sep)
	return box

## A cooldown pip on paper: a gold dot with a brown rim.
func _pip() -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = TdTheme.color("gold")
	sb.border_color = Color("#6B4E2E")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(16, 16)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	return p

func _chip(value: String, label: String) -> Control:
	var n := MenuLogic.result_name(label)
	var icon_name: String = CHIP_ICONS.get(n, "")
	var img := "[img=20x20 color=%s]%s[/img] " % [TdTheme.rich("ink.2"), TdTheme.texture(icon_name).resource_path] if icon_name != "" else ""
	return TdMenu.pill("%s[b]%s[/b] [color=%s]%s[/color]" % [img, value, TdTheme.rich("ink.2"), n],
		TdTheme.color("paper.2"), TdTheme.color("ink"), 20, TdTheme.color("paper.edge"))

const CHIP_ICONS := {"Damage": "icon_power", "Heal": "icon_heart", "Range": "icon_range", "Area": "icon_range",
	"Hits": "icon_volley", "Jumps": "icon_next", "Duration": "icon_clock", "Pushback": "icon_move", "Pull": "icon_move"}
