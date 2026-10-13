class_name HudTopBar
extends Control
## The battle HUD's top bar and End turn (hud-menu-spec §6.1, §6.5; UI_LevelTopBar): base HP and energy pills at the
## top-left (HP red at 30 % or less, the heart pulses on a hit; energy counts over 0.3 s with a "+20" / "-100" delta
## for 1.2 s), the tracker at the top-centre (round · wave text and pips · phase tag), Skip and Pause at the top-right,
## End turn at the bottom-right ("End turn" / "Enemy turn", its key from KeyBinds, the attention pulse 0.6 s after it
## becomes usable when nothing is left to do, hover → the enemy phase previewed on the board, tooltip with what is
## still usable). Full-rect, pointer-transparent; only the pills and buttons take the pointer. Refreshed every frame.

signal pause_pressed

var controller: LevelController

var _hp_pill: PanelContainer
var _hp_value: Label
var _hp_max: Label
var _heart: TextureRect
var _energy_pill: PanelContainer
var _energy_value: Label
var _energy_delta: Label
var _tracker: PanelContainer
var _round: Label
var _wave: Label
var _pips: HBoxContainer
var _phase_tag: PanelContainer
var _phase: Label
var _skip: TdButton
var _pause: TdButton
var end_turn: TdButton

var _shown_energy := -1.0
var _target_energy := -1
var _energy_from := 0.0
var _energy_t := 1.0
var _delta_left := 0.0
var _last_hp := -1
var _heart_t := 1.0
var _can_end_since := -1.0
var _clock := 0.0
var _tip_version := -1
var _nothing_left := false
var _phase_shown := -1

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	_build()

func _build() -> void:
	# --- resources: HP and energy pills
	var res := HudArt.hbox(12)
	res.position = Vector2(32, 20)
	add_child(res)
	_hp_pill = _pill()
	res.add_child(_hp_pill)
	var hp_row := HudArt.hbox(10)
	_hp_pill.add_child(hp_row)
	var hp_socket := _socket("badge_circle_dark", "icon_heart", TdTheme.color("bad"))
	_heart = hp_socket.get_child(0)
	hp_row.add_child(hp_socket)
	_hp_value = HudArt.label("-", "micro", TdTheme.color("cream.100"), 32)
	_hp_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(_hp_value)
	_hp_max = HudArt.label("", "micro", TdTheme.color("cream.300"), 22)
	_hp_max.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_max.visible = false
	hp_row.add_child(_hp_max)
	TdTooltipTrigger.attach(_hp_pill, TooltipText.title("Base health", TooltipText.neutral_color()),
		"If it reaches 0, the level is lost.").set_placement(TdTooltipPlacement.Side.BELOW)

	_energy_pill = _pill()
	res.add_child(_energy_pill)
	var en_row := HudArt.hbox(10)
	_energy_pill.add_child(en_row)
	en_row.add_child(_socket("badge_circle_gold", "icon_energy", TdTheme.color("ink")))
	_energy_value = HudArt.label("-", "micro", TdTheme.color("gold"), 32)
	_energy_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	en_row.add_child(_energy_value)
	_energy_delta = HudArt.label("", "micro", TdTheme.color("good"), 20)
	_energy_delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_delta.visible = false
	en_row.add_child(_energy_delta)
	TdTooltipTrigger.attach(_energy_pill, TooltipText.title("Energy", TooltipText.neutral_color()),
		"Spent to place towers. You get more at the start of each round and for every enemy defeated.").set_placement(TdTooltipPlacement.Side.BELOW)

	# --- tracker: round · wave · phase
	_tracker = HudArt.panel("pill_wood", [28, 8, 10, 8])
	_tracker.name = "Tracker"
	add_child(_tracker)
	var tr := HudArt.hbox(18)
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	_tracker.add_child(tr)
	_round = HudArt.label("Round 1", "h3", TdTheme.color("cream.100"))
	_round.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tr.add_child(_round)
	var sep := ColorRect.new()
	sep.color = TdTheme.color("wood.500")
	sep.custom_minimum_size = Vector2(2, 32)
	sep.size_flags_vertical = SIZE_SHRINK_CENTER
	sep.mouse_filter = MOUSE_FILTER_IGNORE
	tr.add_child(sep)
	var wave_box := HudArt.hbox(8)
	tr.add_child(wave_box)
	var flag := HudArt.sprite("icon_wave", Vector2(24, 24), TdTheme.color("cream.300"))
	flag.size_flags_vertical = SIZE_SHRINK_CENTER
	wave_box.add_child(flag)
	_wave = HudArt.label("1/1", "small", TdTheme.color("cream.200"))
	_wave.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_box.add_child(_wave)
	_pips = HudArt.hbox(6)
	_pips.size_flags_vertical = SIZE_SHRINK_CENTER
	wave_box.add_child(_pips)
	_phase_tag = HudArt.panel("tag_phase_player", [18, 4, 18, 4])
	_phase_tag.mouse_filter = MOUSE_FILTER_IGNORE
	_phase_tag.custom_minimum_size = Vector2(0, 44)
	tr.add_child(_phase_tag)
	_phase = HudArt.label("Your turn", "micro", Color.WHITE, 22)
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_tag.add_child(_phase)
	TdTooltipTrigger.attach(_tracker, TooltipText.title("Round and waves", TooltipText.neutral_color()),
		"Each wave's pip lights when it starts and turns green once all its enemies are gone.").set_placement(TdTooltipPlacement.Side.BELOW)

	# --- tools: Skip, Pause
	_skip = _icon_button("icon_skip", "SkipButton")
	_skip.clicked.connect(func(): if controller != null: controller.skip())
	_pause = _icon_button("icon_pause", "PauseButton")
	_pause.clicked.connect(func(): pause_pressed.emit())

	# --- End turn
	end_turn = TdButton.new()
	end_turn.name = "EndTurnButton"
	end_turn.style = TdButton.Style.END_TURN
	end_turn.custom_minimum_size = Vector2(168, 168)
	end_turn.size = Vector2(168, 168)
	end_turn.text = "End turn"
	add_child(end_turn)
	end_turn.clicked.connect(func(): if controller != null: controller.end_round())
	TdTooltipTrigger.attach(end_turn).set_placement(TdTooltipPlacement.Side.LEFT)
	resized.connect(_layout)
	_layout()
	refresh_keys()

func _pill() -> PanelContainer:
	var p := HudArt.panel("pill_wood", [8, 8, 20, 8])
	p.custom_minimum_size = Vector2(0, 56)
	return p

func _socket(badge: String, glyph: String, tint: Color) -> Control:
	var s := HudArt.sprite(badge, Vector2(40, 40))
	s.size_flags_vertical = SIZE_SHRINK_CENTER
	var g := HudArt.sprite(glyph, Vector2(24, 24), tint)
	g.position = Vector2(8, 8)
	g.pivot_offset = Vector2(12, 12)
	s.add_child(g)
	return s

func _icon_button(glyph: String, node_name: String) -> TdButton:
	var b := TdButton.new()
	b.name = node_name
	b.style = TdButton.Style.ICON
	b.custom_minimum_size = Vector2(56, 56)
	b.size = Vector2(56, 56)
	b.icon = TdTheme.texture(glyph)
	add_child(b)
	TdTooltipTrigger.attach(b).set_placement(TdTooltipPlacement.Side.BELOW)
	return b

func _layout() -> void:
	if end_turn == null: return
	var s := size
	_tracker.position = Vector2((s.x - _tracker.get_combined_minimum_size().x) / 2.0, 16)
	_tracker.size = _tracker.get_combined_minimum_size()
	_pause.position = Vector2(s.x - 32 - 56, 20)
	_skip.position = Vector2(s.x - 32 - 56 - 8 - 56, 20)
	end_turn.position = HudLayout.end_turn_rect(s).position

## Tooltips that name keys (after a rebind too).
func refresh_keys() -> void:
	var keys = _keys()
	var skip_key: String = keys.describe("Skip") if keys != null else "Space"
	var pause_key: String = keys.describe("Pause") if keys != null else "P"
	var busy := controller != null and controller.director != null and controller.director.busy
	_shortcut(_skip, "Skip", "Finishes the action that is playing." if busy else "Nothing to skip: no action is playing.", skip_key)
	_shortcut(_pause, "Pause", "Pauses the game: Settings, or leave the level.", "Esc · " + pause_key if pause_key != "" else "Esc")
	end_turn.set_key_hint(keys.first("EndRound") if keys != null else "Enter")

func _shortcut(b: TdButton, title: String, body: String, key: String) -> void:
	TdTooltipTrigger.find_on(b).set_content(TooltipText.title(title, TooltipText.neutral_color()), body, "Key" if key != "" else "", key)

func _keys():
	return get_tree().root.get_node_or_null("KeyBinds") if is_inside_tree() else null

# ------------------------------------------------------------------ refresh (every frame)

func _process(delta: float) -> void:
	if controller == null or controller.session == null: return
	var dt := TdTheme.unscaled(delta)
	_clock += dt
	var f: ViewFrame = controller.shown
	if f == null: return
	_round.text = "Round %d" % f.round
	var phase_text := HudText.phase_name(f.phase, f.outcome)
	_phase.text = phase_text
	_phase_tag.visible = phase_text != ""
	if _phase_shown != f.phase:
		_phase_shown = f.phase
		var sprite := "tag_phase_player" if f.phase == Phase.Player else "tag_phase_enemy"
		_phase_tag.add_theme_stylebox_override("panel", TdTheme.stylebox(sprite, Color.WHITE, [18, 4, 18, 4]))
		_phase_tag.modulate.a = 0.0
		TdTheme.tween(_phase_tag).tween_property(_phase_tag, "modulate:a", 1.0, TdTheme.motion("quick"))
	_wave.text = HudText.wave_text(f.waves)
	_show_pips(f.waves)
	_show_energy(f.energy, dt)
	_show_hp(f, dt)
	_show_end_turn(f)
	_tracker.size = _tracker.get_combined_minimum_size()
	_tracker.position.x = (size.x - _tracker.size.x) / 2.0

func _show_pips(waves: Array) -> void:
	while _pips.get_child_count() < waves.size():
		var r := HudArt.sprite("pip_wave_off", Vector2(26, 10))
		_pips.add_child(r)
	for i in _pips.get_child_count():
		var pip: TextureRect = _pips.get_child(i)
		pip.visible = i < waves.size()
		if not pip.visible: continue
		var look := HudText.wave_pip(waves, i)
		pip.texture = TdTheme.texture("pip_wave_off" if look == "off" else "pip_wave_on")
		pip.modulate = TdTheme.color("good") if look == "done" else Color.WHITE

func _show_energy(now: int, dt: float) -> void:
	if _target_energy < 0:
		_target_energy = now
		_shown_energy = now
	if now != _target_energy:
		var change := now - _target_energy
		_energy_delta.text = ("+%d" % change) if change > 0 else str(change)
		_energy_delta.add_theme_color_override("font_color", TdTheme.color("good") if change > 0 else TdTheme.color("bad"))
		_delta_left = 1.2
		_energy_from = _shown_energy
		_energy_t = 0.0
		_target_energy = now
	_energy_t = minf(1.0, _energy_t + dt / 0.3)
	_shown_energy = lerpf(_energy_from, float(_target_energy), TdTheme.eased("out", _energy_t))
	_energy_value.text = str(int(roundf(_shown_energy)))
	_delta_left = maxf(0.0, _delta_left - dt)
	_energy_delta.visible = _delta_left > 0.0

## The weakest base's HP (UI_LevelTopBar.BaseHealth).
func _show_hp(f: ViewFrame, dt: float) -> void:
	var weakest: EntityFrame = null
	for id in controller.session.bases:
		var b: EntityFrame = f.get_frame(id)
		if b != null and (weakest == null or b.hp < weakest.hp): weakest = b
	if weakest == null:
		_hp_value.text = "-"
		return
	_hp_value.text = str(weakest.hp)
	var low := HudText.base_low(weakest.hp, weakest.max_hp)
	_hp_value.add_theme_color_override("font_color", TdTheme.color("bad") if low else TdTheme.color("cream.100"))
	if _last_hp >= 0 and weakest.hp < _last_hp: _heart_t = 0.0
	_last_hp = weakest.hp
	_heart_t = minf(1.0, _heart_t + dt / 0.25)
	var k := sin(_heart_t * PI)
	_heart.scale = Vector2.ONE * (1.0 + 0.15 * k)

func _show_end_turn(f: ViewFrame) -> void:
	var busy: bool = controller.director != null and controller.director.busy
	var can_end := f.phase == Phase.Player and f.outcome == Outcome.Running and not busy and controller.can_act
	end_turn.text = HudText.end_turn_label(f.phase, f.outcome)
	end_turn.set_interactable(can_end, "Enemies are moving" if f.phase != Phase.Player else "Wait for the action to finish")
	var keys = _keys()
	end_turn.set_key_hint((keys.first("EndRound") if keys != null else "Enter") if f.phase == Phase.Player else "")
	_skip.set_interactable(busy, "Nothing to skip")
	if _tip_version != controller.version:
		_tip_version = controller.version
		_nothing_left = not controller.session.anything_to_do()
		if can_end: _end_turn_tip()
		refresh_keys()
	controller.preview_enemy_phase = can_end and end_turn.hovered
	if not can_end: _can_end_since = -1.0
	elif _can_end_since < 0.0: _can_end_since = _clock
	end_turn.set_attention(can_end and _nothing_left and _clock - _can_end_since >= 0.6)

## End turn's tooltip: what is still usable, what is ready next turn, and what the enemy turn would do to you.
func _end_turn_tip() -> void:
	var session := controller.session
	var usable: Array[String] = []
	var next: Array[String] = []
	var reason := session.last_reason
	for unit in session.player_units:
		for a in unit.abilities:
			if a.targeting.is_movement: continue
			if session.can_cast(unit, a): usable.append("%s · %s" % [unit.def.display_name, a.display_name])
			elif unit.cooldown(a) == 1: next.append("%s · %s" % [unit.def.display_name, a.display_name])
	session.last_reason = reason
	var threat: Array[String] = []
	var forecast := controller.enemy_forecast
	if forecast != null:
		for id in forecast.loss:
			var hurt: Entity = session.state.get_entity(id)
			if hurt != null and session.is_commanded(hurt):
				threat.append("%s dies" % hurt.def.display_name if forecast.killed.has(id) else "%s -%d" % [hurt.def.display_name, int(forecast.loss[id])])
	var lines: Array[String] = ["Ends your turn: the enemies move and attack, then a new round starts."]
	if usable.size() > 0: lines.append(TooltipText.colored(TooltipText.helpful_color(), "Usable now: " + ", ".join(usable)))
	if next.size() > 0: lines.append(TooltipText.colored(TooltipText.neutral_color(), "Ready next turn: " + ", ".join(next)))
	if threat.size() > 0: lines.append(TooltipText.colored(TooltipText.harmful_color(), "Enemy turn: " + " · ".join(threat)))
	var keys = _keys()
	var key: String = keys.describe("EndRound") if keys != null else ""
	TdTooltipTrigger.find_on(end_turn).set_content(TooltipText.title("End turn anyway?" if usable.size() > 0 else "End turn", TooltipText.neutral_color()),
		"\n".join(lines), "Key" if key != "" else "", key)
