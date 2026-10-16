class_name RewardsScreen
extends TdPopup
## A mission's Rewards popup (Missions & Guild — Design § Rewards popup; UI/UX mockup screens-b/mission-rewards.html):
## the one place that lists what a mission gives. A centred window over whatever opened it (the board card, the
## mission detail, the co-op lobby / create popup / room card): "Rewards · Night Watch" and ×, a dark band with the tier
## diamonds and "[coin] 150 gold" (every win), then the rows "Every win" (token coins), "First win" (gold-rimmed coins,
## dimmed with "✓ claimed" once taken) and "Chance" ("30%" and the coin; listed, not rolled yet). Nothing else: no
## explanatory sentences (Eren 2026-10-16). Rows: MissionUiLogic.rewards_rows. Esc / right click / the scrim close it.
## Open it with RewardsScreen.show_over(parent, mission_id).

const SCENE := "res://game/ui/screens/rewards.tscn"
const WIN_W := 660.0
const PAD := 30.0
const LABEL_W := 130.0

var mission_id := ""
## The rows shown at the last open (MissionUiLogic.rewards_rows; tests and tools).
var rows: Array = []
var _title: Label
var _body: VBoxContainer

## Opens the Rewards popup of a mission over a parent (adds it, frees it on close); returns it.
static func show_over(parent: Node, id: String) -> RewardsScreen:
	var s: RewardsScreen = load(SCENE).instantiate()
	s.free_on_close = true
	s.mission_id = id
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
	var col := TdMenu.vbox(16)
	p.add_child(col)
	var head := TdMenu.hbox(14)
	col.add_child(head)
	_title = TdMenu.label("", "h1", TdTheme.color("cream.100"), 44)
	_title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := TdMenu.close_button()
	x.tooltip_text = "Close (Esc)"
	x.clicked.connect(close)
	head.add_child(x)
	_body = TdMenu.vbox(14)
	col.add_child(_body)

func _on_open() -> void:
	refresh()

func mission() -> MissionDef:
	return MissionBoard.find(GameApp.missions(), mission_id)

## Rebuilds the band and the rows from the mission and the save (claimed = the mission was won once).
func refresh() -> void:
	TdCollection.clear_children(_body)
	var m := mission()
	_title.text = MissionUiLogic.rewards_title(m)
	var claimed := MissionUiLogic.first_win_claimed(m, SaveData.missions)
	rows = MissionUiLogic.rewards_rows(m, claimed, func(id: String) -> String: return TdDrops.token_name(id))
	if m == null: return
	_body.add_child(_band(m, rows))
	for r in rows:
		if r.kind != "gold": _body.add_child(_row(r))

## The dark band: tier diamonds, the gold coin, "150" big and "gold".
func _band(m: MissionDef, list: Array) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.067, 0.05, 0.55)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := TdMenu.hbox(16)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(TdDrops.tier_diamonds(m, 26.0))
	for r in list:
		if r.kind != "gold": continue
		var g := TdMenu.hbox(8)
		g.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(g)
		var coin := TdMenu.picture(TdDrops.gold_coin_texture(), Vector2(44, 44))
		coin.size_flags_vertical = SIZE_SHRINK_CENTER
		g.add_child(coin)
		var n := TdMenu.label(str(r.gold), "h1", TdTheme.color("gold"), 40)
		n.add_theme_font_override("font", TdTheme.font("plinth"))
		n.size_flags_vertical = SIZE_SHRINK_CENTER
		g.add_child(n)
		var w := TdMenu.label("gold", "body", TdTheme.color("cream.100"), 26)
		w.add_theme_font_override("font", TdTheme.font("nunito_bold"))
		w.size_flags_vertical = SIZE_SHRINK_CENTER
		g.add_child(w)
	return p

## "Every win [coins]", "First win [gold-rimmed coins] ✓ claimed", "Chance 30% [coin ×1]".
func _row(r: Dictionary) -> Control:
	var h := TdMenu.hbox(10)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	h.name = "Row_" + str(r.kind)
	var pad := TdMenu.spacer(0, 4)
	h.add_child(pad)
	var l := TdMenu.label(r.label, "plate", TdTheme.color("cream.100"), 24)
	l.add_theme_font_override("font", TdTheme.font("nunito_bold"))
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(l)
	match str(r.kind):
		"every":
			for c in TdDrops.coins(r.tokens, false, false, 42.0): h.add_child(c)
		"first":
			var dim: bool = r.get("claimed", false)
			for c in TdDrops.coins(r.tokens, true, dim, 42.0): h.add_child(c)
			if dim: h.add_child(TdDrops.claimed_tag(22))
		"chance":
			for d in r.drops:
				var pct := TdMenu.label("%d%%" % clampi(roundi(float(d.chance) * 100.0), 1, 100), "h3", TdTheme.color("cream.100"), 26)
				pct.add_theme_font_override("font", TdTheme.font("plinth"))
				pct.size_flags_vertical = SIZE_SHRINK_CENTER
				h.add_child(pct)
				h.add_child(TdDrops.coin(str(d.token), 1, false, false, 42.0))
				h.add_child(TdMenu.spacer(0, 8))
	return h
