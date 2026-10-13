extends Control
## Kit demo: every ui-kit element in its states at the 1920x1080 reference.
##   ~/godot/run.sh projects/td res://game/ui/elements/demo.tscn                      interactive (Tab: next page)
##   ~/godot/run.sh projects/td res://game/ui/elements/demo.tscn -- --page=b --shot=user://ui_demo_b.png
## Pages: a = buttons, ability / end turn / name plates, chips and badges, bars; b = panels, Theme controls, type
## scale, dialogue box, tooltip stack; c = tooltip beside an ability (tail), text bubbles. --shot saves a PNG after a few frames and quits (not on the web).

var page := "a"
var shot := ""
var _frames := 0
var _root: Control

func _ready() -> void:
	theme = TdTheme.theme()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="): page = a.trim_prefix("--page=")
		if a.begins_with("--shot="): shot = a.trim_prefix("--shot=")
	set_anchors_preset(PRESET_FULL_RECT)
	_build()

func _build() -> void:
	if _root: _root.queue_free()
	TdTooltip.hide_immediate()
	TdTooltipStack.hide()
	_root = Control.new()
	_root.set_anchors_preset(PRESET_FULL_RECT)
	_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := TextureRect.new()
	bg.texture = TdTheme.texture("backdrop_wood")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	match page:
		"b": _page_b()
		"c": _page_c()
		_: _page_a()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		page = {"a": "b", "b": "c"}.get(page, "a")
		_build()

func _process(_d: float) -> void:
	if shot == "" or OS.has_feature("web"): return
	_frames += 1
	if _frames == 30:
		get_viewport().get_texture().get_image().save_png(shot)
		print("demo: saved ", ProjectSettings.globalize_path(shot))
		get_tree().quit()

# ------------------------------------------------------------------ helpers

func _at(c: Control, x: float, y: float) -> Control:
	c.position = Vector2(x, y)
	_root.add_child(c)
	return c

func _text(t: String, x: float, y: float, role := "small", col := Color(0, 0, 0, 0)) -> Label:
	var l := TdTheme.label(t, role, col)
	_at(l, x, y)
	return l

func _button(style: int, label: String, x: float, y: float, sz := Vector2.ZERO) -> TdButton:
	var b := TdButton.new()
	b.style = style
	if sz != Vector2.ZERO:
		b.custom_minimum_size = sz
		b.size = sz
	b.text = label
	_at(b, x, y)
	return b

# ------------------------------------------------------------------ page A

func _page_a() -> void:
	_text("ui kit · buttons, chips, bars, tooltip", 32, 16, "h2", TdTheme.color("cream.100"))
	# --- button styles x states
	var states := ["Normal", "Hover", "Pressed", "Selected", "Disabled"]
	var styles := [[TdButton.Style.PRIMARY, "Primary"], [TdButton.Style.SECONDARY, "Secondary"], [TdButton.Style.DANGER, "Danger"],
		[TdButton.Style.TAB, "Tab"]]
	for j in states.size():
		_text(states[j], 150 + j * 236, 68, "small")
	for i in styles.size():
		var y := 100 + i * 78
		_text(styles[i][1], 32, y + 18, "small")
		for j in states.size():
			var sz := Vector2(140, 56) if styles[i][0] == TdButton.Style.TAB else Vector2(220, 60)
			var b := _button(styles[i][0], styles[i][1] if j != 4 else "Disabled", 150 + j * 236, y, sz)
			if j == 3: b.selectable = true; b.selected = true
			if j == 4: b.set_interactable(false, "Needs 40 energy")
			b.force_state(j == 1, j == 2)
	# menu buttons (deep sprites)
	var my := 420
	_text("Menu", 32, my + 20, "small")
	var m1 := _button(TdButton.Style.MENU_PRIMARY, "Continue", 150, my, Vector2(340, 64))
	m1.icon = TdTheme.texture("icon_continue")
	var m2 := _button(TdButton.Style.MENU_WOOD, "Codex", 510, my, Vector2(340, 64))
	m2.icon = TdTheme.texture("icon_codex"); m2.force_state(true, false)
	var m3 := _button(TdButton.Style.MENU_WOOD, "Settings", 870, my, Vector2(340, 64))
	m3.icon = TdTheme.texture("icon_settings"); m3.force_state(true, true)
	# rows
	var r1 := _button(TdButton.Style.ROW, "Archer", 1340, 100, Vector2(320, 60))
	var r2 := _button(TdButton.Style.ROW, "Guardian", 1340, 176, Vector2(320, 60)); r2.force_state(true, false)
	var r3 := _button(TdButton.Style.ROW, "Mage", 1340, 252, Vector2(320, 60)); r3.selectable = true; r3.selected = true
	var r4 := _button(TdButton.Style.ROW, "???", 1340, 328, Vector2(320, 60)); r4.set_extra_state("Locked")
	r1.set_key_hint("1")
	# icon buttons
	var ix := 1700
	_text("Icon", ix, 68, "small")
	var icons := ["icon_pause", "icon_fast-forward", "icon_skip", "icon_settings", "icon_close"]
	for k in icons.size():
		var b := _button(TdButton.Style.ICON, "", ix + (k % 3) * 72, 100 + (k / 3) * 72, Vector2(56, 56))
		b.icon = TdTheme.texture(icons[k])
		if k == 1: b.set_tag("2x"); b.selectable = true; b.selected = true
		if k == 2: b.force_state(true, false)
		if k == 4: b.set_interactable(false, "Nothing to skip")
	# --- ability buttons
	var ay := 540
	_text("Ability: ready · hover · aiming · cooldown 1 · cooldown 2/3 · held · blocked · passive", 32, ay - 34, "small")
	var faces := ["Shoot", "Fireball", "TowerWalk", "Volley", "Bombard", "Execute", "Mend", "Rally"]
	for k in faces.size():
		var b := _button(TdButton.Style.ABILITY, "", 60 + k * 132, ay + 14, Vector2(84, 84))
		b.icon = TdTheme.ability_face(faces[k])
		match k:
			0: b.set_ability_state(0, 1, false, false, "1")
			1: b.set_ability_state(0, 2, false, false, "2"); b.force_state(true, false)
			2: b.set_ability_state(0, 2, false, true, "3")
			3: b.set_ability_state(1, 2, false, false, "4")
			4: b.set_ability_state(2, 3, false, false, "5")
			5: b.set_ability_state(1, 1, true, false, "6")
			6: b.set_ability_state(0, 1, false, false, "7"); b.set_interactable(false, "No target in range")
			7: b.set_passive(true)
	# end turn
	var ex := 1140
	_text("End turn: normal · hover · attention · enemy", ex, ay - 34, "small")
	var e1 := _button(TdButton.Style.END_TURN, "End turn", ex, ay + 4, Vector2(168, 168))
	e1.set_key_hint("Enter")
	e1.scale = Vector2(0.7, 0.7)
	var e2 := _button(TdButton.Style.END_TURN, "End turn", ex + 190, ay + 4, Vector2(168, 168))
	e2.set_key_hint("Enter"); e2.force_state(true, false); e2.scale = Vector2(0.7, 0.7)
	var e3 := _button(TdButton.Style.END_TURN, "End turn", ex + 380, ay + 4, Vector2(168, 168))
	e3.set_key_hint("Enter"); e3.set_attention(true); e3.scale = Vector2(0.7, 0.7)
	var e4 := _button(TdButton.Style.END_TURN, "Enemy turn", ex + 570, ay + 4, Vector2(168, 168))
	e4.set_interactable(false, "Enemies are moving"); e4.scale = Vector2(0.7, 0.7)
	# name plates
	var ny := 700
	_text("Name plates", 32, ny - 30, "small")
	var plates := [["Archer", ""], ["Guardian", "hover"], ["Priest", "Picked"], ["Cannon", "Placed"], ["Mage", "Selected"], ["Alchemist", "poor"]]
	for k in plates.size():
		var b := _button(TdButton.Style.NAME_PLATE, plates[k][0], 60 + k * 132, ny, Vector2(108, 28))
		match plates[k][1]:
			"hover": b.force_state(true, false)
			"poor": b.set_interactable(false, "Needs 120 energy")
			"": pass
			_: b.set_extra_state(plates[k][1])
	# --- chips
	var cy := 790
	_text("Chips 32 / 40 / 48 with time + stacks pills", 32, cy - 34, "small")
	var statuses := [["Acid", 2, 3], ["Poison", 12, 15], ["Burn", 1, 140], ["Shield", -1, 1250], ["Haste", 25, 3]]
	var sizes := [32.0, 40.0, 48.0]
	var x := 60.0
	for sz in sizes:
		for st in statuses:
			var c := TdIconChip.new()
			c.chip_size = sz
			c.shape = TdIconChip.ChipShape.STATUS
			_at(c, x, cy + (48.0 - sz) / 2.0 + 10.0)
			c.set_icon(load("res://art/icons/Statuses/%s.png" % st[0]))
			c.set_status(st[1], st[2], st[0] == "Shield")
			x += sz + 12.0
		x += 28.0
	var ab := TdIconChip.new()
	ab.chip_size = 48; ab.shape = TdIconChip.ChipShape.ABILITY
	_at(ab, x + 10, cy + 10)
	ab.set_icon(TdTheme.kit("abilities/Shoot"))
	ab.set_label("Ready")
	var pa := TdIconChip.new()
	pa.chip_size = 48; pa.shape = TdIconChip.ChipShape.PASSIVE
	_at(pa, x + 100, cy + 10)
	pa.set_icon(load("res://art/icons/Passives/Shielded.png"))
	pa.set_label("Always on")
	var gl := TdIconChip.new()
	gl.chip_size = 48; gl.shape = TdIconChip.ChipShape.ABILITY
	_at(gl, 960, cy + 104)
	gl.set_glyph(TdTheme.texture("icon_eye"))
	# icon bar with overflow
	var bar := TdIconBar.new()
	bar.icon_size = 40; bar.h_spacing = 12; bar.max_icons = 4
	_at(bar, 60, cy + 110)
	for st in ["Burn", "Poison", "Rooted", "Shield", "Haste", "Acid"]:
		var chip := bar.add_icon(st, load("res://art/icons/Statuses/%s.png" % st), "", false)
		chip.set_status(2, 1)
	_text("TdIconBar (max 4: 3 + \"+N\")", 290, cy + 118, "small")
	# --- health bars
	var hx := 1140
	var hy := 800
	_text("Health bars: 100 % · 50 % · 20 % · preview", hx, hy - 44, "small")
	var hps := [[20, 20], [10, 20], [4, 20]]
	for k in hps.size():
		var hb := TdHealthBar.new()
		hb.size = Vector2(300, 14)
		hb.show_label = true
		_at(hb, hx + (k % 2) * 340, hy + 10 + (k / 2) * 56)
		hb.set_health_immediate(hps[k][0], hps[k][1])
	var pv := TdHealthBar.new()
	pv.size = Vector2(300, 14); pv.show_label = true
	_at(pv, hx + 340, hy + 66)
	pv.set_health_immediate(16, 20)
	pv.set_preview(9)
	# entity status compact + full
	var es := TdEntityStatus.new()
	_at(es, hx, hy + 130)
	es.set_health_immediate(14, 20)
	for st in [["Burn", 2, 2], ["Poison", 12, 15], ["Rooted", 1, 1], ["Shield", -1, 1250], ["Haste", -1, 1]]:
		es.add_status(st[0], load("res://art/icons/Statuses/%s.png" % st[0]), st[1], st[2], st[0] == "Shield", false)
	var ef := TdEntityStatus.new()
	ef.full = true
	_at(ef, hx + 200, hy + 110)
	ef.set_entity_name("Big Slime")
	ef.set_health_immediate(14, 20)
	for st in [["Shield", -1, 1250], ["Rooted", 1, 1], ["Poison", 12, 15], ["Burn", 2, 2], ["Haste", -1, 1]]:
		ef.add_status(st[0], load("res://art/icons/Statuses/%s.png" % st[0]), st[1], st[2], st[0] == "Shield", false)

# ------------------------------------------------------------------ page B

func _page_b() -> void:
	_text("ui kit · panels, built-in controls (Theme), type, dialogue, tooltip stack", 32, 16, "h2", TdTheme.color("cream.100"))
	# window panel with a title + close
	var w := TdPanel.make_window("Settings")
	var panel: TdPanel = w["panel"]
	panel.size = Vector2(560, 300)
	_at(panel, 40, 80)
	var body: VBoxContainer = w["body"]
	var l := Label.new(); l.text = "Music volume"; body.add_child(l)
	var sl := HSlider.new(); sl.value = 60; sl.custom_minimum_size = Vector2(300, 36); body.add_child(sl)
	var cb := CheckButton.new(); cb.text = "Instant playback"; cb.button_pressed = true; body.add_child(cb)
	var le := LineEdit.new(); le.placeholder_text = "Your name (Çağrı, İpek, Şule…)"; le.custom_minimum_size = Vector2(0, 56); body.add_child(le)
	# paper card + wood + enemy panel
	var card := TdPanel.new(); card.kind = TdPanel.Kind.PAPER; card.size = Vector2(300, 120)
	_at(card, 640, 80)
	var cl := Label.new(); cl.theme_type_variation = "InkLabel"; cl.text = "Paper card\nReward: 50 energy"; card.add_child(cl)
	var wood := TdPanel.new(); wood.kind = TdPanel.Kind.WOOD; wood.size = Vector2(300, 100)
	_at(wood, 640, 230)
	var wl := Label.new(); wl.theme_type_variation = "H2Label"; wl.text = "Archer"; wood.add_child(wl)
	var en := TdPanel.new(); en.kind = TdPanel.Kind.ENEMY; en.size = Vector2(300, 100)
	_at(en, 980, 230)
	var enl := Label.new(); enl.theme_type_variation = "H2Label"; enl.text = "Big Slime"; enl.add_theme_color_override("font_color", TdTheme.color("bad")); en.add_child(enl)
	# built-in Button variations from the Theme
	var bx := 980
	for v in [["PrimaryButton", "Play"], ["Button", "Back"], ["DangerButton", "Quit"]]:
		var b := Button.new(); b.theme_type_variation = v[0]; b.text = v[1]
		b.custom_minimum_size = Vector2(220, 60)
		_at(b, bx, 80)
		bx += 240
	var tb := Button.new(); tb.theme_type_variation = "TextButton"; tb.text = "Skip tutorial, I know how to play"
	_at(tb, 980, 160)
	var ob := OptionButton.new(); ob.add_item("Fullscreen"); ob.add_item("Window"); ob.custom_minimum_size = Vector2(300, 52)
	_at(ob, 1360, 240)
	var tabs := TabBar.new(); tabs.clip_tabs = false; tabs.add_tab("Audio"); tabs.add_tab("Display"); tabs.add_tab("Controls"); tabs.current_tab = 1
	_at(tabs, 1360, 160)
	# type scale
	var ty := 380
	for role in ["display", "h1", "h2", "h3", "header", "body", "small", "micro", "plate"]:
		var t := TdTheme.label("%s %d · Çğİıöşü" % [role, TdTheme.font_size(role)], role)
		_at(t, 1180, ty)
		ty += TdTheme.font_size(role) + 14
	# tooltip stack beside a status chip
	var chip := TdIconChip.new(); chip.chip_size = 40
	_at(chip, 660, 400)
	chip.set_icon(load("res://art/icons/Statuses/Poison.png")); chip.set_status(12, 15)
	var items := [TooltipText.status("Poison", "Takes 75 damage at the start of each turn.", true, false, 15, 12, false, true, "Alchemist (Acid Flask)"),
		TooltipText.status("Shield", "Absorbs damage before HP: one point per stack (1250 left).", false, true, 1250, -1, false, false, "Rockjaw"),
		TooltipText.status("Rooted", "Cannot move.", true, false, 1, 1)]
	# dialogue box with portrait
	var dlg := TdDialogueBox.new()
	dlg.size = Vector2(1100, 220)
	_at(dlg, 410, 830)
	dlg.letters_per_second = 0
	dlg.show_line("Speaker", "Place your [color=%s]Archer[/color] by the road. Click it in the tray at the bottom, and the tiles you can build on light up." % TdTheme.rich("accent.light"), true, load("res://art/portraits/Archer.png"))
	dlg.set_notes("Tutorial · 2/12", "Click or [b]Space[/b] to continue")
	await get_tree().process_frame
	await get_tree().process_frame
	TdTooltipStack.show(self, chip.get_global_rect(), items, TdTooltipStack.Side.RIGHT)

# ------------------------------------------------------------------ page C

func _page_c() -> void:
	_text("ui kit · tooltip (beside, with tail), text bubble, denied reason", 32, 16, "h2", TdTheme.color("cream.100"))
	# a fake board strip
	var board := ColorRect.new(); board.color = Color("#5d7a45"); board.size = Vector2(1920, 560)
	_at(board, 0, 300)
	# ability buttons in a bar
	var bar := TdPanel.new(); bar.kind = TdPanel.Kind.WOOD; bar.padding = 16; bar.size = Vector2(330, 120)
	_at(bar, 760, 920)
	var ab := _button(TdButton.Style.ABILITY, "", 900, 938, Vector2(84, 84))
	ab.icon = TdTheme.ability_face("TowerWalk")
	ab.set_ability_state(1, 2, false, false, "2")
	var ab0 := _button(TdButton.Style.ABILITY, "", 790, 938, Vector2(84, 84))
	ab0.icon = TdTheme.ability_face("Shoot")
	ab0.set_ability_state(0, 1, false, false, "1")
	TooltipText.set_keywords(["Burn", "Stunned"])
	var c := TooltipText.ability("Tower Walk", "Moves the tower up to 2 tiles. Burns the tile it leaves for 3 damage.", "Movement",
		[["2", "Range"], ["3", "Damage"]], 2, false, 1, [TooltipText.note("2 aims · Shift+2 quick casts")])
	# a unit marker and a bubble pointing at it
	var marker := ColorRect.new(); marker.color = TdTheme.color("hp.high"); marker.size = Vector2(48, 48)
	_at(marker, 420, 560)
	var bub := TdTextBubble.new()
	bub.size = Vector2(1920, 1080)
	_root.add_child(bub)
	bub.letters_per_second = 0
	bub.show_line("Princess", "A Slime! It is too far to shoot. Click your [color=%s]Archer[/color], click [b]Tower Walk[/b] on the bar above your hand, then a tile on the way." % TdTheme.rich("accent.ink"), true, load("res://art/portraits/Archer.png"))
	bub.set_hint("Goes on when a tower moves", "Click or [b]Space[/b]")
	bub.point_at(Vector2(444, 556))
	# second bubble pointing up from below (no room above)
	var marker2 := ColorRect.new(); marker2.color = TdTheme.color("team.player"); marker2.size = Vector2(48, 48)
	_at(marker2, 1500, 120)
	var bub2 := TdTextBubble.new()
	bub2.size = Vector2(1920, 1080)
	_root.add_child(bub2)
	bub2.letters_per_second = 0
	bub2.show_line("Archer", "Energy is up here. Each tower costs some.", true)
	bub2.set_hint("", "Click or [b]Space[/b]")
	bub2.point_at(Vector2(1524, 168))
	await get_tree().process_frame
	await get_tree().process_frame
	TdTooltip.show_content_beside(c, ab.get_global_rect().grow(20), TdTooltip.Side.ABOVE_CENTRED)
