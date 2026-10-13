extends TestCase
## Battle HUD words and small rules: cost missing, ready count, refusals, row states, phase / wave / base HP,
## status placeholders, stat tiles, end screen summary, sequence hints, content icon names.

func test_cost_missing() -> void:
	assert_eq(HudText.energy_missing(180, 150), 30)
	assert_eq(HudText.energy_missing(100, 150), 0)
	assert_eq(HudText.cost_missing(180, 150), "Needs 180 energy (you have 150)")

func test_ready_count_and_line() -> void:
	assert_eq(HudText.ready_count([]), 0)
	assert_eq(HudText.ready_count([true, false, true]), 2)
	assert_eq(HudText.ready_line(2), "2 ready")
	assert_eq(HudText.ready_line(0, 100), "100 energy")

func test_ability_refusal() -> void:
	assert_eq(HudText.ability_refusal("Shoot", true, 0, false, ""), "")
	assert_eq(HudText.ability_refusal("Tower Walk", false, 1, false, ""), "Tower Walk is ready in 1 turn.")
	assert_eq(HudText.ability_refusal("Tower Walk", false, 2, false, ""), "Tower Walk is ready in 2 turns.")
	assert_eq(HudText.ability_refusal("Execute", false, 0, true, ""), "Execute waits for a reset.")
	assert_eq(HudText.ability_refusal("Shoot", false, 0, false, "No target in range"), "Shoot: No target in range")

func test_row_state() -> void:
	assert_eq(HudText.row_state(0, false), "Ready")
	assert_eq(HudText.row_state(1, false), "1 turn")
	assert_eq(HudText.row_state(3, false), "3 turns")
	assert_eq(HudText.row_state(0, true), "After a reset")

func test_top_bar_words() -> void:
	assert_eq(HudText.phase_name(Phase.Player, Outcome.Running), "Your turn")
	assert_eq(HudText.phase_name(Phase.Enemy, Outcome.Running), "Enemy turn")
	assert_eq(HudText.phase_name(Phase.Player, Outcome.Won), "Victory")
	assert_eq(HudText.phase_name(Phase.Enemy, Outcome.Lost), "Defeat")
	assert_eq(HudText.end_turn_label(Phase.Player, Outcome.Running), "End\nturn")
	assert_eq(HudText.end_turn_label(Phase.Enemy, Outcome.Running), "Enemy\nturn")
	assert_true(HudText.base_low(3, 10))
	assert_false(HudText.base_low(4, 10))
	assert_false(HudText.base_low(0, 0))

func test_waves() -> void:
	assert_eq(HudText.wave_text([]), "-")
	var a := WaveView.new()
	var b := WaveView.new()
	var c := WaveView.new()
	assert_eq(HudText.wave_text([a, b, c]), "1/3")
	assert_eq(HudText.wave_pip([a, b, c], 0), "on")
	assert_eq(HudText.wave_pip([a, b, c], 1), "off")
	a.started = true; a.finished = true; b.started = true
	assert_eq(HudText.wave_text([a, b, c]), "2/3")
	assert_eq(HudText.wave_pip([a, b, c], 0), "done")
	assert_eq(HudText.wave_pip([a, b, c], 1), "on")

func test_status_placeholders() -> void:
	assert_eq(HudText.status_description("Takes {stacks*5} damage for {turns} turns.", 3, 2), "Takes [b]15[/b] damage for [b]2[/b] turns.")
	assert_eq(HudText.status_description("Lasts {turns}.", 1, -1), "Lasts [b]–[/b].")
	assert_eq(HudText.status_description("No placeholders.", 1, 1), "No placeholders.")
	assert_eq(HudText.status_description("{ Stacks } left", 4, 1), "[b]4[/b] left")

func test_stat_tiles() -> void:
	var d := EntityDef.new()
	d.base_stats = {"MaxHp": 20.0, "Speed": 2.0}
	var tiles := HudText.stat_tiles(DefStats.new(d), d, CombatVocabulary.create())
	assert_true(tiles.size() >= 1)
	assert_eq(tiles[0]["label"], "Max HP")
	assert_eq(tiles[0]["value"], "20")
	assert_eq(tiles[0]["bonus"], "")

func test_numbers_and_names() -> void:
	assert_eq(HudText.num(10.0), "10")
	assert_eq(HudText.num(2.5), "2.5")
	assert_eq(HudText.icon_name("Assets/Art/Icons/Abilities/Shoot.png#Shoot"), "Shoot")
	assert_eq(HudText.icon_name("Assets/Art/Icons/Passives/Shielded.png"), "Shielded")
	assert_eq(HudText.model_name("Assets/Art/Models/Archer/Archer Blender.prefab"), "Archer")
	assert_eq(HudText.model_name(""), "")
	assert_eq(HudText.ability_key(0), "Ability1")
	assert_eq(HudText.key_note("1", "Shift-click"), "Key 1 · Shift-click for quick cast")
	assert_eq(HudText.key_note("", "Shift-click"), "Shift-click for quick cast")

func test_end_screen_words() -> void:
	assert_eq(HudText.joined("Archer"), "An Archer joined you!")
	assert_eq(HudText.joined("Mage"), "A Mage joined you!")
	assert_eq(HudText.end_summary(true, 7, 3, 3, 8, 10, 1), "Every wave cleared in 7 rounds.\nBase: 8 / 10 HP left  ·  Towers lost: 1")
	assert_eq(HudText.end_summary(false, 5, 1, 3, 0, 10, 2), "The base fell in round 5. Waves cleared: 1 of 3.\nTowers lost: 2")

func test_sequence_hints() -> void:
	assert_eq(HudText.how_it_goes_on(SequenceContinue.Click, 0, "Space"), "Click or press Space")
	assert_eq(HudText.how_it_goes_on(SequenceContinue.Click, 0, ""), "Click to go on")
	assert_eq(HudText.how_it_goes_on(SequenceContinue.Seconds, 0, "Space"), "")
	assert_eq(HudText.how_it_goes_on(SequenceContinue.Event, SequenceEvent.RoundEnded, "Space"), "Click to hide. Goes on when you end the round")

func test_fill_stats_in_descriptions() -> void:
	var v := {"Speed": 2.0, "Range": 3.0}
	assert_eq(HudText.fill_stats("Walks along its path, up to Speed tiles.", v), "Walks along its path, up to [b]2[/b] tiles.")
	assert_eq(HudText.fill_stats("Speed is how far it walks.", v), "Speed is how far it walks.")
	assert_eq(HudText.fill_stats("Hits anything within Range.", v), "Hits anything within [b]3[/b].")
	assert_eq(HudText.fill_stats("Moves up to Speed tiles.", {}), "Moves up to Speed tiles.")

func test_hint_wording() -> void:
	assert_eq(Hud.hint_text("Click a green tile. Right-click cancels.", true, ""), "Click a marked enemy. Right-click cancels.")
	assert_eq(Hud.hint_text("Click a green tile. Right-click cancels.", false, ""), "Click a green tile. Right-click cancels.")
	assert_eq(Hud.hint_text("No damage this turn", false, "No damage this turn"), "")
	assert_eq(Hud.hint_text("Click a free tile off the path. Right-click cancels.", false, ""), "Click a free tile off the path. Right-click cancels.")

func test_piece_key() -> void:
	assert_eq(HudText.piece_key("4", "Ctrl"), "4")
	assert_eq(HudText.piece_key("4", ""), "4")
	assert_eq(HudText.piece_key("", "Ctrl"), "")

func test_round3_copy() -> void:
	assert_eq(HudText.cost_missing_hint("Cannon", 280, 0), "Cannon needs 280 energy (you have 0).")
	assert_eq(HudText.shortfall(280, 100), "Needs 180 more")
	assert_eq(HudText.singular_after_one("for [b]1[/b] turns, [b]2[/b] tiles"), "for [b]1[/b] turn, [b]2[/b] tiles")

func test_unit_labels() -> void:
	var l := HudTopBar.unit_labels([[5, "Archer"], [7, "Base"], [9, "Archer"]])
	assert_eq(l[5], "Archer 1")
	assert_eq(l[9], "Archer 2")
	assert_eq(l[7], "Base")

func test_aiming_label() -> void:
	assert_eq(HudText.aiming_label("Shoot"), "Shoot: pick a target")

func test_info_tags_and_pips() -> void:
	assert_eq(HudText.shown_tags([["2", "Move"], ["10", "Damage"]]), [["2", "Range"], ["10", "Damage"]])
	assert_eq(HudInfoPopup.pip_names(0, false, 2), ["pip_mini_ready", "pip_mini_ready"])
	assert_eq(HudInfoPopup.pip_names(1, false, 2), ["pip_mini_ready", "pip_mini_wait"])
	assert_eq(HudInfoPopup.pip_names(0, true, 1), ["pip_mini_held"])
