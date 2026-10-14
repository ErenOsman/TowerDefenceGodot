extends TestCase
## The Missions & Guild screens' texts and states (game/ui/screens/parts/mission_ui_logic.gd): mode chips, the
## board's card states and lines, the detail's notes and pips, the hand strip marks ("▲ goes", tired) and the cap
## divider, the Guild's station line, the Camp's Signpost, the end screen's lines and reward groups, the co-op rows,
## Join refusal and the auto-leave popup; plus the Workshop's "Found in" reading missions and SceneFlow's Guild.

static var _lib: ContentLibrary

const DAY := "2026-10-14T19:00:00"  # 5 h before midnight

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func setup() -> void:
	MissionBoard.energy_per_day = 1

func m(id: String) -> MissionDef:
	return MissionBoard.find(lib().catalog.to_missions(), id)

func test_mode_chips() -> void:
	assert_eq(MissionUiLogic.mode_chip(m("patrol")), "Any · solo or 1–4")
	assert_eq(MissionUiLogic.mode_chip(m("hold-the-gate")), "Co-op 2–6")
	assert_eq(MissionUiLogic.mode_short(m("patrol")), "Any 1–4")
	assert_eq(MissionUiLogic.mode_short(m("hold-the-gate")), "Co-op 2–6")
	var solo := MissionDef.new()
	assert_eq(MissionUiLogic.mode_chip(solo), "Solo")
	assert_eq(MissionUiLogic.mode_chip(null), "")

func test_board_lines() -> void:
	assert_eq(MissionUiLogic.board_subtitle(DAY), "Earn tokens for the Workshop · plays reset at midnight (in 5 h)")
	assert_eq(MissionUiLogic.level_line(m("patrol"), "Two Roads"), "Two Roads")
	assert_eq(MissionUiLogic.level_line(m("drum-line"), "The Drummer"), "The Drummer · 2 plays a day")
	assert_eq(MissionUiLogic.plays_level("Two Roads"), "plays Two Roads")

func test_card_states() -> void:
	var mp := MissionProgress.new()
	var p := m("patrol")
	var g := m("hold-the-gate")
	assert_eq(MissionUiLogic.card_state(p, true, "", mp, DAY), {"state": "play", "text": "1 play left today", "button": "Play"})
	assert_eq(MissionUiLogic.card_state(g, true, "", mp, DAY), {"state": "room", "text": "1 play left today", "button": "Find a room"})
	assert_eq(MissionUiLogic.card_state(m("drum-line"), true, "", mp, DAY).text, "2 plays left today")
	assert_eq(MissionUiLogic.card_state(g, false, "Win Hold the Gate first", mp, DAY), {"state": "locked", "text": "Win Hold the Gate first", "button": ""})
	MissionBoard.record_play(p, mp, [], DAY)
	assert_eq(MissionUiLogic.card_state(p, true, "", mp, DAY), {"state": "done", "text": "Done today · resets in 5 h", "button": ""})
	# the detail's list lines
	assert_eq(MissionUiLogic.list_line(p, "done", "", mp, DAY), "Done today")
	assert_eq(MissionUiLogic.list_line(m("drum-line"), "play", "", mp, DAY), "2 left today")
	assert_eq(MissionUiLogic.list_line(g, "room", "", mp, DAY), "Co-op · find a room")
	assert_eq(MissionUiLogic.list_line(g, "locked", "Win X first", mp, DAY), "Win X first")
	assert_eq(MissionUiLogic.primary_label(p), "Play")
	assert_eq(MissionUiLogic.primary_label(g), "Find a room")

func test_drops_and_claimed() -> void:
	var n := m("night-watch")
	assert_eq(MissionUiLogic.drop_rows(n), [["Each win", {"fire-arrow": 1, "poison-gland": 1}], ["First win", {"arcane-shard": 1}]])
	var mp := MissionProgress.new()
	assert_false(MissionUiLogic.first_win_claimed(n, mp))
	var r := LevelResult.new()
	r.level_id = n.level_id
	r.won = true
	mp.record(r, n.id)
	assert_true(MissionUiLogic.first_win_claimed(n, mp))
	assert_eq(MissionUiLogic.drop_rows(null), [])

func test_detail_notes_and_pips() -> void:
	var mp := MissionProgress.new()
	var p := m("patrol")
	assert_eq(MissionUiLogic.pips(p, mp, DAY), [1, 1])
	assert_eq(MissionUiLogic.pips_text(p, mp, DAY), "1 of 1 play left today")
	assert_eq(MissionUiLogic.detail_note(p, "play", "", "", DAY), {"kind": "info", "text": "Starting uses a play, win or lose."})
	assert_eq(MissionUiLogic.detail_note(p, "play", "", MissionBoard.AllTired, DAY),
		{"kind": "warn", "text": "All your towers are tired: change your hand or come back tomorrow."})
	assert_eq(MissionUiLogic.detail_note(m("hold-the-gate"), "room", "", "", DAY).text, "Co-op only (2–6 players). Starting the match uses your play.")
	assert_eq(MissionUiLogic.detail_note(p, "locked", "Win X first", "", DAY), {"kind": "lock", "text": "Win X first"})
	MissionBoard.record_play(p, mp, [], DAY)
	assert_eq(MissionUiLogic.pips_text(p, mp, DAY), "0 of 1 play left today · resets in 5 h")
	assert_eq(MissionUiLogic.detail_note(p, "done", "", "", DAY).text, "Done today: you used today's play. Resets in 5 h.")
	assert_eq(MissionUiLogic.detail_note(m("drum-line"), "done", "", "", DAY).text, "Done today: you used today's plays. Resets in 5 h.")
	assert_true(MissionUiLogic.primary_enabled("play", ""))
	assert_false(MissionUiLogic.primary_enabled("play", MissionBoard.AllTired))
	assert_true(MissionUiLogic.primary_enabled("room", MissionBoard.AllTired), "towers are checked at Ready")
	assert_false(MissionUiLogic.primary_enabled("done", ""))
	assert_false(MissionUiLogic.primary_enabled("locked", ""))

func test_hand_marks_and_divider() -> void:
	var mp := MissionProgress.new()
	var hand := ["a", "b", "c", "d", "e"]
	# nothing tired: the first 4 go, the divider after 4
	var marks := MissionUiLogic.hand_marks(hand, mp, 4, DAY)
	assert_eq(marks.map(func(k): return k.goes), [true, true, true, true, false])
	assert_eq(MissionUiLogic.divider_at(hand, mp, 4, DAY), 4)
	# b tired: a, c, d, e go; the divider after e
	mp.tire("b", "2026-10-14")
	marks = MissionUiLogic.hand_marks(hand, mp, 4, DAY)
	assert_eq(marks.map(func(k): return k.tired), [false, true, false, false, false])
	assert_eq(marks.map(func(k): return k.goes), [true, false, true, true, true])
	assert_eq(MissionUiLogic.divider_at(hand, mp, 4, DAY), 5)
	assert_true(MissionUiLogic.any_tired(hand, mp, DAY))
	# all tired: nobody goes, the divider after the hand
	for id in hand: mp.tire(id, "2026-10-14")
	assert_eq(MissionUiLogic.hand_marks(hand, mp, 4, DAY).filter(func(k): return k.goes).size(), 0)
	assert_eq(MissionUiLogic.divider_at(hand, mp, 4, DAY), 5)
	# no divider at the end of a full hand or with no cap
	assert_eq(MissionUiLogic.divider_at(["a", "b", "c", "d", "e", "f", "g", "h"], MissionProgress.new(), 8, DAY), -1)
	assert_eq(MissionUiLogic.divider_at(hand, mp, 0, DAY), -1)
	assert_false(MissionUiLogic.any_tired(hand, mp, "2026-10-15"), "rested after midnight")

func test_hand_notes() -> void:
	var p := m("patrol")
	assert_eq(MissionUiLogic.hand_note(p, "Two Roads", 5, 4, false), "Two Roads takes the first 4 towers; the rest wait on the bench.")
	assert_eq(MissionUiLogic.hand_note(p, "Two Roads", 5, 4, true), "Patrol takes the first 4 rested towers; tired ones stay home.")
	assert_eq(MissionUiLogic.hand_note(m("hold-the-gate"), "Three at the Gate", 5, 3, false),
		"Three at the Gate takes the first 3 towers (co-op: per player); the rest wait on the bench.")
	assert_eq(MissionUiLogic.hand_note(p, "Two Roads", 0, 4, false), "Your hand is empty: add towers with Change hand.")
	assert_eq(MissionUiLogic.editor_cap_note("Night Watch", 4), "Night Watch takes the first 4 rested")
	assert_eq(MissionUiLogic.editor_cap_note("", 4), "")
	assert_eq(MissionUiLogic.tired_line(DAY), "Tired ·\nrests in 5 h")
	assert_eq(MissionUiLogic.tired_line(DAY, false), "Tired · rests in 5 h")
	assert_eq(MissionUiLogic.tired_detail(DAY), "Tired: went on a mission today. Rests in 5 h.")

func test_guild_and_signpost() -> void:
	var c := lib().catalog
	var ms := c.to_missions()
	var p := LevelProgress.new()
	var mp := MissionProgress.new()
	assert_eq(MissionUiLogic.to_play_count(ms, p, mp, c, DAY), 0, "the Guild is closed")
	var g := GameData.new()
	g.progress = p
	DevShortcuts.complete_main_chapters(g, c, 2)
	assert_eq(MissionUiLogic.to_play_count(ms, p, mp, c, DAY), 5)
	MissionBoard.record_play(m("patrol"), mp, [], DAY)
	assert_eq(MissionUiLogic.to_play_count(ms, p, mp, c, DAY), 4)
	assert_eq(MissionUiLogic.missions_station_sub(3), "Today’s missions · 3 to play")
	assert_eq(MissionUiLogic.missions_station_sub(0), "Today’s missions · all done")
	assert_eq(MissionUiLogic.signpost_locked_text(c), "Opens after Chapter 2")
	assert_eq(MissionUiLogic.players_reason(m("hold-the-gate")), "Hold the Gate needs 2–6 players")
	assert_eq(MissionUiLogic.retry_takes_line(["Mage"], 4), "Retry takes 1 rested tower (Mage)")
	assert_eq(MissionUiLogic.retry_takes_line(["Mage", "Priest"], 4), "Retry takes 2 rested towers (Mage, Priest)")
	assert_eq(MissionUiLogic.retry_takes_line(["a", "b", "c", "d"], 4), "", "the full cap: no line")
	assert_eq(MissionUiLogic.retry_takes_line([], 4), "")
	assert_eq(MissionUiLogic.signpost_tag(false), "New")
	assert_eq(MissionUiLogic.signpost_tag(true), "")
	assert_eq(MissionUiLogic.Stations.map(func(s): return s.id), ["Missions", "Multiplayer", "Towers", "Camp"])
	assert_eq(SceneFlow.NAMES[SceneFlow.Guild], "Guild")
	assert_eq(SceneFlow.candidates(SceneFlow.Guild)[1], "res://game/ui/screens/guild.tscn")
	assert_true(ResourceLoader.exists("res://game/ui/screens/guild.tscn"))

func test_end_screen_lines() -> void:
	var mp := MissionProgress.new()
	var p := m("patrol")
	var d := m("drum-line")
	assert_eq(MissionUiLogic.end_subtitle(p), "Mission · Patrol")
	MissionBoard.record_play(d, mp, [], DAY)
	assert_eq(MissionUiLogic.end_plays_line(d, mp, DAY), "1 play left today")
	MissionBoard.record_play(p, mp, [], DAY)
	assert_eq(MissionUiLogic.end_plays_line(p, mp, DAY), "Done today: no plays left · resets in 5 h")
	assert_eq(MissionUiLogic.end_reward_groups(p, true, true), [["Rewards", {"yew-bow": 1}, false], ["First win", {"fire-arrow": 1}, true]])
	assert_eq(MissionUiLogic.end_reward_groups(p, true, false), [["Rewards", {"yew-bow": 1}, false]])
	assert_eq(MissionUiLogic.end_reward_groups(p, false, true), [], "a loss gives nothing")

func test_coop_texts() -> void:
	var mp := MissionProgress.new()
	var n := m("night-watch")
	assert_eq(MissionUiLogic.picker_line(n, mp, DAY), "1 play left today · Any 1–4")
	assert_eq(MissionUiLogic.picker_line(m("hold-the-gate"), mp, DAY), "1 play left today · Co-op 2–6")
	assert_eq(MissionUiLogic.create_plays_note(n, mp, DAY), "[b]1 play left today[/b]: the match start uses one for everyone.")
	MissionBoard.record_play(n, mp, [], DAY)
	assert_eq(MissionUiLogic.picker_line(n, mp, DAY), "Done today · resets in 5 h")
	assert_eq(MissionUiLogic.room_row_line("Night Watch", true), "Night Watch · done today")
	assert_eq(MissionUiLogic.room_row_line("Patrol", false), "Patrol")
	assert_eq(MissionUiLogic.join_done_text("Night Watch", DAY), "Done today: you played Night Watch today. Resets in 5 h.")
	var a := MissionUiLogic.auto_left("Night Watch", DAY)
	assert_eq(a.title, "Done today")
	assert_eq(a.body, "The room switched to [b]Night Watch[/b], which you already played today. You left the room.")
	assert_eq(a.resets, "Resets in [b]5 h[/b].")
