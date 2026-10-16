class_name BackpackScreen
extends TdPopup
## The Backpack (Backpack — Design; UI/UX mockup screens-b/backpack.html): what the player carries, as a centred
## popup over the place it opened from (nothing else changes). "Backpack" and × only (Esc, a right click or the scrim
## close it). A big gold row ("[coin] 240 gold · From missions; spent on upgrades", always shown, "0 gold" too), then
## "Tokens": one row per kind ever earned (coin, name, "×2", muted "Found in: …" as the Workshop derives it from the
## mission drops); a spent-out kind stays at ×0, dimmed; never-earned kinds are not listed. Then a muted "Items ·
## Nothing here yet." (items and keys get sections later: the popup grows by sections, not tabs).
## Texts and rules: BackpackLogic. Data: GameData.gold and GameData.tokens (no new save data).
## Open it with BackpackScreen.show_over(parent) (TdBackpackButton does).

const SCENE := "res://game/ui/screens/backpack.tscn"
const WIN_W := 1140.0
const PAD := 30.0
const ROW_BG := Color(0.09, 0.067, 0.05, 0.35)
const GOLD_BG := Color(0.09, 0.067, 0.05, 0.55)

var _body: VBoxContainer
## The token rows shown at the last open (BackpackLogic.token_rows; tests and tools).
var rows: Array = []

## Opens the Backpack over a parent (adds it, frees it on close); returns it.
static func show_over(parent: Node) -> BackpackScreen:
	var s: BackpackScreen = load(SCENE).instantiate()
	s.free_on_close = true
	parent.add_child(s)
	s.open()
	return s

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, PAD)
	p.custom_minimum_size = Vector2(WIN_W, 0)
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(14)
	p.add_child(col)
	var head := TdMenu.hbox(14)
	col.add_child(head)
	head.add_child(TdMenu.label(BackpackLogic.Title, "h1", TdTheme.color("cream.100"), 44))
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(fill)
	var x := TdMenu.close_button()
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	_body = TdMenu.vbox(10)
	col.add_child(_body)

func _on_open() -> void:
	refresh()

## Rebuilds the gold row and the sections from the save.
func refresh() -> void:
	TdCollection.clear_children(_body)
	var gold: int = GameApp.gold()
	_body.add_child(_gold_row(gold))
	_body.add_child(TdMenu.spacer(4))
	var missions := GameApp.missions()
	rows = BackpackLogic.token_rows(GameApp.catalog.tokens if GameApp.catalog != null else [], SaveData.tokens,
		func(id: String) -> String: return WorkshopLogic.found_in_text(id, missions))
	_body.add_child(_heading(BackpackLogic.TokensHead, false))
	if rows.is_empty():
		_body.add_child(_muted(BackpackLogic.ItemsEmpty))
	for r in rows: _body.add_child(_token_row(r))
	_body.add_child(TdMenu.spacer(4))
	_body.add_child(_heading(BackpackLogic.ItemsHead, true))
	_body.add_child(_muted(BackpackLogic.ItemsEmpty))

func _box(bg: Color, radius: int, pad_x: int, pad_y: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x; sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y; sb.content_margin_bottom = pad_y
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	return p

## "[coin] 240 gold        From missions; spent on upgrades"
func _gold_row(gold: int) -> Control:
	var p := _box(GOLD_BG, 16, 22, 14)
	var h := TdMenu.hbox(14)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(h)
	var coin := TdMenu.picture(TdDrops.gold_coin_texture(), Vector2(64, 64))
	coin.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(coin)
	var n := TdMenu.label(BackpackLogic.gold_text(gold), "h1", TdTheme.color("gold"), 50)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(n)
	var w := TdMenu.label(BackpackLogic.GoldWord, "body", TdTheme.color("cream.100"), 32)
	w.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	w.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(w)
	var fill := TdMenu.spacer()
	fill.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(fill)
	var sub := TdMenu.label(BackpackLogic.GoldSub, "body", TdTheme.color("cream.300"), 24)
	sub.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(sub)
	return p

func _heading(text: String, muted: bool) -> Label:
	var l := TdMenu.label(text, "h3", TdTheme.color("cream.300") if muted else TdTheme.color("cream.200"), 30)
	l.add_theme_font_override("font", TdTheme.font("plinth"))
	return l

func _muted(text: String) -> Label:
	return TdMenu.label(text, "body", TdTheme.color("cream.300"), 24)

## One token: coin, name, "×2", "Found in: …" (dimmed at ×0). Tooltip: the token's description.
func _token_row(r: Dictionary) -> Control:
	var p := _box(ROW_BG, 14, 18, 8)
	p.mouse_filter = MOUSE_FILTER_PASS
	var h := TdMenu.hbox(18)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := TdMenu.picture(TdDrops.token_texture(r.id), Vector2(54, 54))
	ic.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(ic)
	var n := TdMenu.label(r.name, "h3", TdTheme.color("cream.100"), 28)
	n.add_theme_font_override("font", TdTheme.font("plinth"))
	n.custom_minimum_size = Vector2(250, 0)
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(n)
	var c := TdMenu.label(r.count_text, "h3", TdTheme.color("cream.100"), 30)
	c.add_theme_font_override("font", TdTheme.font("plinth"))
	c.custom_minimum_size = Vector2(80, 0)
	c.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(c)
	var f := TdMenu.label(r.found, "body", TdTheme.color("cream.300"), 24)
	f.size_flags_horizontal = SIZE_EXPAND_FILL
	f.size_flags_vertical = SIZE_SHRINK_CENTER
	f.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	f.clip_text = true
	h.add_child(f)
	if r.dim: p.modulate = Color(1, 1, 1, 0.5)
	var t: TokenAsset = GameApp.catalog.find_token(r.id) if GameApp.catalog != null else null
	if t != null: TdTooltipTrigger.attach(p, TooltipText.title(t.get_display_name(), TooltipText.value_color(), "Token"),
		t.description, "You have", str(r.count))
	return p
