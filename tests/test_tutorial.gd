extends TestCase
## The guided tutorial (game/level/guided_tutorial.gd, data/tutorial.json) on a real LevelSession of the catalog's
## tutorial level, through a LevelController that is not in the tree (no board, no HUD: the "stub HUD" is the
## refusal counter and the line the HUD would show). Commands go through the controller's gates; the Director has
## no presenters and is drained after each command.

static var _lib: ContentLibrary = null

var c: LevelController
var g: GuidedTutorial

func setup() -> void:
	if _lib == null: _lib = ContentLibrary.load_game() # the short 7×5 tutorial map (data/content/Levels.json)
	c = LevelController.new()
	var level: LevelAsset = _lib.catalog.tutorial if _lib.catalog != null else null
	if level == null:
		for l in _lib.all_of("LevelAsset"):
			if l.get_id() == "tutorial": level = l
	c.level = level
	c.converter = AssetConverter.new()
	var hand := []
	for t in level.fixed_hand: hand.append(c.converter.tower(t, TowerIds.new_id()))
	c.session = LevelSession.new(c.converter.level(level), c.converter.rules(_lib.rules), hand, 1)
	c.recorder = FrameRecorder.of_session(c.session)
	c.director = Director.new(c.session.log, null, c.recorder)
	c.session.start()
	c.director.finish_all()
	assert_true(c.start_guided(), "data/tutorial.json loads")
	g = c.guided

func teardown() -> void:
	if c != null: c.free()
	c = null
	g = null

## Plays what is queued and lets the tutorial look (as a frame of the level would).
func _idle(dt := 0.1) -> void:
	c.director.finish_all()
	c._tick_guided(dt)

func _archer_id() -> String:
	return c.session.hand[0].id

func _ability(n: String) -> AbilityDef:
	return g.ability(n)

## Asserts a command was refused: the refusal count went up, the line stayed and the refusal says what was wrong.
func _refused(before: int, at: int, what: String, says := "") -> void:
	assert_eq(g.refusals, before + 1, what + " is refused")
	assert_eq(g.index, at, what + " leaves the line")
	assert_eq(c.hint, g.last_hint, what + ": the refusal text is the controller's message")
	if says != "": assert_eq(g.last_hint, says, what + ": what was wrong")

func _to_placing() -> void:
	c.continue_sequence()
	c.continue_sequence()
	c.toggle_placing(_archer_id())
	_idle()

func _to_walk(place := Vector2i(5, 1)) -> void:
	_to_placing()
	c.click_tile(place)
	_idle()
	c.end_round()
	_idle()
	c.click_tile(g.archer().pos)
	_idle()

func test_the_lines_load_in_order_with_their_rules() -> void:
	assert_eq(g.steps.size(), 14)
	assert_eq(g.index, 0)
	assert_eq(g.run.current.text, "Slimes come down this road…")
	assert_eq(g.steps[1].line.text, "…to your castle. Keep it safe.")
	assert_eq(g.run.current.speaker, SequenceSpeaker.Princess)
	assert_true(g.talking)
	assert_true(c.sequence == g.run, "the HUD reads the tutorial's run")
	assert_true(c.sequence.blocking, "a talk line pauses play")
	for st in g.steps: assert_true(st.line.text.length() <= 90, "short line: " + st.line.text)
	assert_eq(g.steps[13].line.text, "That's it: place, move, shoot, end turn. Finish the wave.", "the last step is free play (the quick-cast step was removed, Eren 2026-10-15)")

func test_the_whole_tutorial_step_by_step() -> void:
	# road, then castle: talk only — every action is refused
	assert_eq(g.display_line().point_at, SequencePointAt.Tile)
	assert_eq(Vector2i(g.display_line().tile_x, g.display_line().tile_y), Vector2i(2, 2))
	assert_eq(g.action_note(), "", "a talk line has no action note (the box says Click or press Space)")
	var r := g.refusals
	c.toggle_placing(_archer_id())
	assert_null(c.placing, "no placing during a talk line")
	_refused(r, 0, "the piece during a talk line", "Finish this step first.")
	r = g.refusals
	c.end_round()
	_refused(r, 0, "End turn during a talk line")
	assert_eq(c.session.round, 1)
	c.continue_sequence()
	assert_eq(g.index, 1)
	assert_eq(g.display_line().point_at, SequencePointAt.Speaker, "then the castle")
	c.continue_sequence()

	# only the Archer's piece
	assert_eq(g.index, 2)
	assert_false(g.talking)
	assert_eq(g.display_line().ui_element, "@piece")
	assert_eq(g.action_note(), "Click the Archer piece", "the box's note names the allowed action")
	r = g.refusals
	c.end_round()
	_refused(r, 2, "End turn while the piece is asked for", "Not now: click the Archer piece first.")
	c.toggle_placing(_archer_id())
	assert_eq(c.placing, _archer_id())
	_idle()

	# only the two lit tiles; the one ring on the far one
	assert_eq(g.index, 3)
	assert_eq(g.display_line().point_at, SequencePointAt.Tile)
	assert_eq(Vector2i(g.display_line().tile_x, g.display_line().tile_y), Vector2i(5, 3))
	assert_true(g.hides_card, "the card stays closed during the guided steps")
	assert_eq(g.action_note(), "Place the Archer on a lit tile")
	assert_true(c.input_allowed("tile", Vector2i(5, 1)) and c.input_allowed("tile", Vector2i(5, 3)))
	assert_false(c.input_allowed("tile", Vector2i(4, 1)), "other build tiles do not light")
	r = g.refusals
	c.click_tile(Vector2i(4, 1))
	_refused(r, 3, "another build tile", "Not now: place the Archer on a lit tile first.")
	assert_eq(c.placing, _archer_id(), "still placing after a refused tile")
	c.click_tile(Vector2i(5, 1))
	_idle()
	var archer := g.archer()
	assert_true(archer != null and archer.pos == Vector2i(5, 1), "placed on a lit tile")

	# only End turn
	assert_eq(g.index, 4)
	assert_eq(g.display_line().ui_element, "EndTurnButton")
	r = g.refusals
	c.toggle_aim(_ability("Shoot"))
	_refused(r, 4, "Shoot while End turn is asked for", "Not now: click End turn first.")
	assert_null(c.aiming)
	c.end_round()
	_idle()

	# select the Archer (the tutorial cleared the selection that placing made)
	assert_eq(g.index, 5)
	assert_eq(c.selected, -1, "nothing selected when asked to select")
	var slime := g.first_enemy()
	assert_true(slime != null, "the slime came")
	assert_eq(g.display_line().point_at, SequencePointAt.FirstTower)
	r = g.refusals
	c.select(slime.id)
	_refused(r, 5, "selecting the slime", "Not now: click your Archer first.")
	assert_eq(c.selected, -1)
	r = g.refusals
	c.click_tile(Vector2i(1, 0))
	_refused(r, 5, "clicking empty ground")
	c.click_tile(archer.pos)
	assert_eq(c.selected, archer.id)
	_idle()

	# "Click Tower Walk." — the button only
	assert_eq(g.index, 6)
	assert_eq(g.display_line().ui_element, "@ability:move")
	r = g.refusals
	c.toggle_aim(_ability("Shoot"))
	_refused(r, 6, "Shoot while Tower Walk is asked for", "Not now: click Tower Walk first.")
	c.toggle_aim(_ability("Tower Walk"))
	assert_eq(c.aiming, _ability("Tower Walk"))
	assert_false(c.input_allowed("aim", Vector2i(3, 1)), "no walking on the click-the-button line")
	_idle()

	# "Now click the lit tile." — exactly the tile two steps toward the slime
	assert_eq(g.index, 7)
	assert_eq(g.walk_tile(), Vector2i(3, 1))
	assert_eq(g.display_line().point_at, SequencePointAt.Tile)
	assert_eq(Vector2i(g.display_line().tile_x, g.display_line().tile_y), Vector2i(3, 1))
	assert_true(c.input_allowed("aim", Vector2i(3, 1)))
	assert_false(c.input_allowed("aim", Vector2i(4, 1)), "only the one walk tile")
	r = g.refusals
	c.click_tile(Vector2i(4, 1))
	_refused(r, 7, "another walk tile", "Not now: click the lit tile first.")
	assert_eq(c.aiming, _ability("Tower Walk"), "still aiming after a refused tile")
	c.click_tile(Vector2i(3, 1))
	_idle()
	assert_eq(archer.pos, Vector2i(3, 1), "the archer walked")

	# End turn until the slime is in range; the line moves on by itself
	assert_eq(g.index, 8)
	r = g.refusals
	c.select(archer.id)
	c.toggle_aim(_ability("Shoot"))
	_refused(r, 8, "Shoot before it is in range")
	var turns := 0
	while g.index == 8 and turns < 20:
		assert_false(g.enemy_in_range(), "the line waits only while out of range")
		c.end_round()
		_idle()
		turns += 1
	assert_eq(g.index, 9, "in range: the line went on by itself")
	assert_true(g.enemy_in_range())

	# "Click Shoot." then "Now click the slime."
	slime = g.first_enemy()
	c.select(archer.id)
	r = g.refusals
	c.quick_cast(_ability("Shoot"))
	_refused(r, 9, "a quick cast where a normal Shoot is asked for", "Not now: click Shoot first.")
	r = g.refusals
	c.toggle_aim(_ability("Tower Walk"))
	_refused(r, 9, "Tower Walk while Shoot is asked for")
	c.toggle_aim(_ability("Shoot"))
	assert_eq(c.aiming, _ability("Shoot"))
	assert_false(c.input_allowed("aim", slime.pos), "no shooting on the click-the-button line")
	_idle()
	assert_eq(g.index, 10)
	assert_eq(g.display_line().point_at, SequencePointAt.FirstEnemy)
	r = g.refusals
	c.click_tile(Vector2i(3, 0))
	_refused(r, 10, "shooting at an empty tile", "Not now: click the slime first.")
	c.click_tile(slime.pos)
	_idle()

	# "Nice shot." for 1.5 s
	assert_eq(g.index, 11)
	assert_true(g.talking)
	r = g.refusals
	c.end_round()
	_refused(r, 11, "End turn during Nice shot", "Finish this step first.")
	_idle(1.0)
	assert_eq(g.index, 11)
	_idle(0.6)

	# End turn refreshes cooldowns
	assert_eq(g.index, 12)
	c.end_round()
	_idle()

	# the quick-cast step was removed (Eren 2026-10-15): End turn goes straight to free play
	assert_eq(g.index, 13, "free play after the cooldown step")

	# free play until the win
	assert_false(g.hides_card)
	assert_true(c.input_allowed("end_turn") and c.input_allowed("sell", "x") and c.input_allowed("tile", Vector2i(0, 0)))
	turns = 0
	while not c.session.is_over and turns < 40:
		c.select(archer.id)
		var shoot := _ability("Shoot")
		if shoot != null and c.session.can_cast(archer, shoot) and g.can_hit(shoot, false): c.quick_cast(shoot)
		else: c.end_round()
		_idle()
		turns += 1
	assert_eq(c.session.outcome, Outcome.Won)
	_idle()
	assert_true(g.finished, "the tutorial ends with the win")
	assert_null(c.sequence)

## The short tutorial map (Guided Tutorial — Design § The level; Eren 2026-10-14 "the slime took too long"): playing
## only what each step allows, in order, the slime is in Shoot range at step 9 within 2 End turns and the level is
## won in about 8 rounds (the sim is deterministic).
func test_the_short_map_puts_the_slime_in_range_within_two_end_turns() -> void:
	var grid: BattleGrid = c.session.state.grid
	assert_eq(Vector2i(grid.width, grid.height), Vector2i(7, 5), "the 7×5 tutorial map")
	var ends := 0
	c.continue_sequence()
	c.continue_sequence()
	c.toggle_placing(_archer_id())
	_idle()
	assert_true(c.input_allowed("tile", Vector2i(5, 1)), "the lit tile")
	c.click_tile(Vector2i(5, 1))
	_idle()
	assert_eq(g.index, 4)
	c.end_round()
	ends += 1
	_idle()
	c.click_tile(g.archer().pos)
	_idle()
	c.toggle_aim(_ability("Tower Walk"))
	_idle()
	assert_eq(g.aim_tiles(), [Vector2i(3, 1)], "2 tiles toward the slime")
	c.click_tile(Vector2i(3, 1))
	_idle()
	assert_eq(g.index, 8)
	var waited := 0
	while g.index == 8 and waited < 5:
		c.end_round()
		ends += 1
		waited += 1
		_idle()
	assert_eq(g.index, 9, "step 9 went on")
	assert_true(waited <= 2, "the slime is in Shoot range after at most 2 End turns (took %d)" % waited)
	assert_true(g.enemy_in_range())
	c.select(g.archer().id)
	c.toggle_aim(_ability("Shoot"))
	_idle()
	c.click_tile(g.first_enemy().pos)
	_idle()
	_idle(1.6)
	assert_eq(g.index, 12)
	c.end_round()
	ends += 1
	_idle()
	var guard := 0
	while not c.session.is_over and guard < 40:
		guard += 1
		var archer := g.archer()
		assert_true(archer != null, "the archer stands")
		if archer == null: return
		c.select(archer.id)
		var shoot := _ability("Shoot")
		if c.input_allowed("quick_cast", shoot) and c.session.can_cast(archer, shoot) and g.can_hit(shoot, false):
			c.quick_cast(shoot)
		else:
			assert_true(c.input_allowed("end_turn"), "End turn is allowed when nothing can be shot")
			c.end_round()
			ends += 1
		_idle()
	assert_eq(c.session.outcome, Outcome.Won, "the tutorial level is won")
	assert_true(ends <= 9, "about 8 rounds in all (took %d End turns)" % ends)
	_idle()
	assert_true(g.finished)

func test_the_walk_tile_follows_the_archers_row() -> void:
	_to_walk(Vector2i(5, 3))
	assert_eq(g.index, 6)
	c.toggle_aim(_ability("Tower Walk"))
	_idle()
	assert_eq(g.index, 7)
	assert_eq(g.walk_tile(), Vector2i(3, 3))
	assert_eq(g.aim_tiles(), [Vector2i(3, 3)])

func test_a_cancelled_step_points_back_and_allows_its_first_click() -> void:
	_to_placing()
	assert_eq(g.index, 3)
	c.toggle_placing(_archer_id()) # cancel (the piece again)
	assert_null(c.placing)
	assert_eq(g.display_line().ui_element, "@piece", "back to the piece")
	assert_true(c.input_allowed("piece", _archer_id()))
	c.toggle_placing(_archer_id())
	c.click_tile(Vector2i(5, 1))
	_idle()
	c.end_round()
	_idle()
	c.click_tile(g.archer().pos)
	_idle()
	assert_eq(g.index, 6)
	c.toggle_aim(_ability("Tower Walk"))
	_idle()
	assert_eq(g.index, 7)
	c.select(-1) # right-click deselect always works
	assert_eq(g.display_line().point_at, SequencePointAt.FirstTower, "the archer again")
	assert_true(c.input_allowed("select", g.archer().id))
	c.select(g.archer().id)
	assert_eq(g.display_line().ui_element, "@ability:move")

func test_skip_ends_the_guidance_for_free_play() -> void:
	c.skip_sequence()
	assert_true(g.finished)
	assert_null(c.sequence, "no line after Skip")
	assert_true(c.can_act)
	c.toggle_placing(_archer_id())
	c.click_tile(Vector2i(4, 0))
	_idle()
	assert_true(g.archer() != null and g.archer().pos == Vector2i(4, 0), "any tile after Skip")
	var round := c.session.round
	c.end_round()
	_idle()
	assert_eq(c.session.round, round + 1)
	assert_eq(g.refusals, 0)

func test_skip_in_the_middle_keeps_the_game_as_it_is() -> void:
	_to_placing()
	c.skip_sequence()
	assert_true(g.finished)
	assert_eq(c.placing, _archer_id(), "a mode in progress stays")
	c.click_tile(Vector2i(6, 4))
	_idle()
	assert_true(g.archer() != null)
