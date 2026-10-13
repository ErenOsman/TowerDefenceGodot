extends TdPopup
## The credits window (UI_Credits.cs, the user's rule): a wood window "Credits" with a paper card holding only
## "Game by EREN OSMAN", "Music by EMRE OSMAN" and the Nunito copyright + OFL line. No scrolling.
## Secrets (CreditsSecret.cs): a click on the first E of "EREN" completes Chapter 1 (GameApp.complete_chapter1),
## on the first E of "EMRE" wins the first 8 levels (GameApp.win_first_levels(8)); the title says what happened
## and `secret_used` lets the main menu refresh its Continue button.

signal secret_used(message: String)

const NAMES := [["Game by", "EREN OSMAN"], ["Music by", "EMRE OSMAN"]]
const FONT_LINES := ["Nunito: Copyright 2014 The Nunito Project Authors", "SIL Open Font License, Version 1.1"]

var title_label: Label
var name_labels: Array = []

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 24)
	p.custom_minimum_size = Vector2(752, 0)
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(20)
	p.add_child(col)
	var head := TdMenu.hbox(12)
	col.add_child(head)
	title_label = TdMenu.label("Credits", "h1", TdTheme.color("cream.100"))
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title_label)
	var x := TdMenu.close_button()
	x.clicked.connect(close)
	head.add_child(x)
	var card := TdMenu.panel(TdPanel.Kind.PAPER, 36)
	col.add_child(card)
	var lines := TdMenu.vbox(4)
	card.add_child(lines)
	for pair in NAMES:
		var by := TdMenu.label(pair[0], "small", TdTheme.color("ink.2"), 20)
		by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.add_child(by)
		var n := TdMenu.label(pair[1], "body", TdTheme.color("accent.ink"), 76)
		n.add_theme_font_override("font", TdTheme.font("nunito_extrabold"))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = MOUSE_FILTER_STOP
		var nm: String = pair[1]
		n.gui_input.connect(func(e): _on_name_input(n, nm, e))
		lines.add_child(n)
		name_labels.append(n)
		lines.add_child(TdMenu.spacer(14))
	var fonts := TdMenu.label("Fonts", "h3", TdTheme.color("ink"))
	fonts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(fonts)
	for l in FONT_LINES:
		var t := TdMenu.label(l, "body", TdTheme.color("ink"))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.add_child(t)

func _on_open() -> void:
	title_label.text = "Credits"
	title_label.add_theme_font_size_override("font_size", TdTheme.font_size("h1"))

## The character of a centred label under a local x (-1 outside the text).
static func letter_at(l: Label, text: String, x: float) -> int:
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var start := (l.size.x - w) / 2.0
	if x < start or x > start + w: return -1
	for i in text.length():
		if x < start + f.get_string_size(text.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x: return i
	return -1

func _on_name_input(l: Label, text: String, e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT: return
	if letter_at(l, text, e.position.x) != text.find("E"): return
	run_secret(text)

## Runs a name's secret; returns what the title says.
func run_secret(text: String) -> String:
	var said := ""
	if text.begins_with("EREN"):
		var won: int = GameApp.complete_chapter1()
		said = "Chapter 1 complete (%d level%s won)" % [won, "" if won == 1 else "s"] if won > 0 else "Chapter 1 is already complete"
	elif text.begins_with("EMRE"):
		var won2: int = GameApp.win_first_levels(8)
		said = "The first 8 levels are won (%d new)" % won2 if won2 > 0 else "The first 8 levels are already won"
	if said != "":
		title_label.text = said
		title_label.add_theme_font_size_override("font_size", 30)
		secret_used.emit(said)
	return said
