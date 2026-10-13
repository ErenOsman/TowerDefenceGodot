class_name HudEndScreen
extends HudPopup
## The end of a level (UI_EndScreen): "Victory" (gold) or "Defeat" (red), a summary (rounds, waves cleared, the base's
## HP, towers lost; a reward tower "An Archer joined you!"), and one centred row: Retry (not after winning the
## tutorial), the leave button (controller.leave_label) and Next level (won, and a next level exists). It cannot be
## closed with Esc or right click: one of its buttons decides.

var retry_button: TdButton
var leave_button: TdButton
var next_button: TdButton
var _summary: RichTextLabel

func _ready() -> void:
	closable = false
	make("Victory", 760, false, true)
	title_label.add_theme_font_size_override("font_size", TdTheme.font_size("display"))
	body.add_theme_constant_override("separation", 28)
	_summary = HudArt.rich("body", TdTheme.color("cream.200"), 24)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.custom_minimum_size = Vector2(680, 0)
	body.add_child(_summary)
	var row := HudArt.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	retry_button = HudPopup.wide_button("Retry", TdButton.Style.SECONDARY, "", 210)
	retry_button.clicked.connect(func(): if controller != null: controller.retry())
	row.add_child(retry_button)
	leave_button = HudPopup.wide_button("Level select", TdButton.Style.SECONDARY, "", 210)
	leave_button.clicked.connect(func(): if controller != null: controller.level_select())
	row.add_child(leave_button)
	next_button = HudPopup.wide_button("Next level", TdButton.Style.PRIMARY, "", 210)
	next_button.clicked.connect(func(): if controller != null: controller.next_level())
	row.add_child(next_button)
	visible = false

func show_outcome(outcome: int) -> void:
	var c := controller
	var s := c.session
	var won := outcome == Outcome.Won
	title_label.text = "Victory" if won else "Defeat"
	title_label.add_theme_color_override("font_color", TdTheme.color("gold") if won else TdTheme.color("bad"))
	var cleared := 0
	for w in s.waves:
		if w.finished: cleared += 1
	var hp := 0
	var max_hp := 0
	for id in s.bases:
		var b: Entity = s.state.get_entity(id)
		if b != null:
			max_hp += b.max_hp
			if b.alive: hp += b.hp
	var lost: int = LevelResults.from(s, "", "").towers_lost
	var text := HudText.end_summary(won, s.round, cleared, s.waves.size(), hp, max_hp, lost)
	if c.reward != null:
		text += "\n" + TooltipText.colored(TdTheme.rich("teal"), HudText.joined(c.reward.display_name))
	_summary.text = "[center]%s[/center]" % text
	retry_button.visible = c.can_retry
	leave_button.text = c.leave_label
	leave_button.fit_to_content(210)
	next_button.visible = won and c.next_level_asset != null
	open()
