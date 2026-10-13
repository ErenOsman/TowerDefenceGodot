extends TestCase
## Port of SequenceTests.cs.

func _click(text: String) -> SequenceLine:
	var l := SequenceLine.new(); l.text = text; l.continue_on = SequenceContinue.Click
	return l

func _timed(text: String, s: float) -> SequenceLine:
	var l := SequenceLine.new(); l.text = text; l.continue_on = SequenceContinue.Seconds; l.seconds = s
	return l

func _wait(text: String, e: int) -> SequenceLine:
	var l := SequenceLine.new(); l.text = text; l.continue_on = SequenceContinue.Event; l.wait_for = e; l.pauses_play = false
	return l

func test_lines_continue_on_click_time_and_events() -> void:
	var run := SequenceRun.new([_click("hello"), _timed("wait", 2.0), _wait("place", SequenceEvent.TowerPlaced)])
	assert_eq(run.current.text, "hello")
	assert_true(run.blocking, "intro lines pause play")

	run.tick(10.0, true)
	assert_eq(run.current.text, "hello", "a click line waits for the click")
	run.click()
	assert_eq(run.current.text, "wait")

	run.click()
	assert_eq(run.current.text, "wait", "a timed line ignores clicks")
	run.tick(1.5, true)
	run.tick(0.6, true)
	assert_eq(run.current.text, "place")
	assert_false(run.blocking, "a tutorial step leaves the player free to act")

	run.notify(SequenceEvent.RoundEnded)
	run.tick(0.1, true)
	assert_eq(run.current.text, "place", "another event does nothing")
	run.notify(SequenceEvent.TowerPlaced)
	run.tick(0.1, false)
	assert_eq(run.current.text, "place", "it waits until playback is idle")
	run.tick(0.1, true)
	assert_true(run.finished)
	assert_null(run.current)
	assert_false(run.blocking)

func test_an_event_during_the_previous_line_counts() -> void:
	var run := SequenceRun.new([_wait("place", SequenceEvent.TowerPlaced), _wait("select", SequenceEvent.UnitSelected)])
	run.notify(SequenceEvent.UnitSelected) # placing selects the tower at once
	run.notify(SequenceEvent.TowerPlaced)
	run.tick(0.1, true)
	assert_eq(run.current.text, "select")
	run.tick(0.1, true)
	assert_true(run.finished, "the selection that came with the placement satisfies the next line")

func test_skip_ends_it_and_raises_the_change() -> void:
	var run := SequenceRun.new([_click("a"), _click("b")])
	var changes := [0]
	run.line_changed.connect(func(): changes[0] += 1)
	run.click()
	run.skip()
	assert_true(run.finished)
	assert_eq(changes[0], 2)
	assert_true(SequenceRun.new(null).finished, "an empty sequence is finished at once")

func test_with_text_copies_the_line() -> void:
	var line := _wait("Hi {player}", SequenceEvent.LevelWon)
	var named := line.with_text("Hi Eren")
	assert_eq(line.text, "Hi {player}")
	assert_eq(named.text, "Hi Eren")
	assert_eq(named.wait_for, SequenceEvent.LevelWon)
