extends TestCase
## Co-op rules (Multiplayer — Design, co-op; docs/Co-op Protocol.md): CoopSession turns, pass/end turn, energy
## pools, control, protocol commands, leavers, determinism and checksums; CoopList; ContentHash. Godot-only.

const BaseTile := Vector2i(6, 1)
const DrummerTile := Vector2i(3, 0)

static var _lib: ContentLibrary

# ------------------------------------------------------------------ a small level (7×3, road along y = 1)

static func _guard() -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Guard"
	a.targeting = PatternDef.self_()
	a.steps = []
	return a

static func _walk() -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Walk"
	a.tags = [Tags.Movement]
	a.targeting = PatternDef.path_ahead("Self.Speed")
	a.steps = [WalkStep.new()]
	return a

static func _slime() -> EntityDef:
	var d := EntityDef.new()
	d.name = "Slime"
	d.footing = Footing.OnPath
	d.abilities = [_walk()]
	return d.stat("MaxHp", 10).stat("Speed", 1)

static func _level() -> LevelDef:
	var level := LevelDef.new()
	level.name = "Coop"
	level.width = 7
	level.height = 3
	level.start_energy = 10
	level.energy_per_round = 5
	level.hand_cap = 4
	var path := []
	for x in 6: path.append(Vector2i(x, 1))
	level.paths = [path]
	var b := BaseDef.new()
	b.tile = BaseTile
	var base := EntityDef.new()
	base.name = "Base"
	base.kind = EntityKind.Object_
	base.tags = [Tags.Base]
	b.entity = base.stat("MaxHp", 100)
	level.bases = [b]
	var drummer := EntityDef.new()
	drummer.name = "Drummer"
	drummer.abilities = [_guard()]
	drummer.stat("MaxHp", 10)
	var su := StartingUnitDef.new()
	su.entity = drummer
	su.tile = DrummerTile
	su.side = StartingSide.Ally
	level.starting_units = [su]
	var w := WaveDef.new()
	w.name = "First"
	w.start_round = 1
	for r in [1, 2, 3, 6]:
		var s := SpawnEntry.new()
		s.round = r
		s.enemy = _slime()
		w.spawns.append(s)
	level.waves = [w]
	return level

static func _type(id: String, cost: int) -> TowerType:
	var d := EntityDef.new()
	d.name = id.capitalize()
	d.footing = Footing.OffPath
	d.abilities = [_guard()]
	d.stat("MaxHp", 20)
	var t := TowerType.new()
	t.id = id
	t.name = d.name
	t.entity = d
	t.cost = cost
	return t

static func _types() -> Dictionary:
	return {"archer": _type("archer", 3), "mage": _type("mage", 4), "priest": _type("priest", 2)}

static func _coop(ids: Array, shared: bool, hands: Array = [], cap := 3) -> CoopSession:
	var types := _types()
	var players := []
	for i in ids.size():
		var type_ids: Array = hands[i] if i < hands.size() else ["archer", "mage"]
		players.append({"id": ids[i], "hand": CoopSession.build_hand(ids[i], type_ids, func(t): return types.get(t))})
	var c := CoopSession.new(_level(), GameRules.new(CombatVocabulary.create()), players, 7, shared, cap)
	c.start()
	return c

static func _drummer(c: CoopSession) -> Entity:
	return c.state.entity_at(DrummerTile)

# ------------------------------------------------------------------ hands

func test_hands_get_player_prefixed_ids_and_the_coop_cap() -> void:
	var c := _coop(["p1", "p2"], true, [["archer", "archer", "mage", "priest"], ["mage"]])
	assert_eq(c.last_error, "")
	assert_seq(c.hand_of("p1").map(func(t): return t.id), ["p1:archer#1", "p1:archer#2", "p1:mage#1"], "cut to the cap (3)")
	assert_seq(c.hand_of("p2").map(func(t): return t.id), ["p2:mage#1"])
	assert_eq(c.session.hand.size(), 4, "the session holds every player's hand, not cut to the level's hand cap")
	assert_eq(c.owner_of("p1:mage#1"), "p1")
	assert_eq(c.owner_of("p2:mage#1"), "p2")
	assert_ne(CoopSession.new(_level(), GameRules.new(CombatVocabulary.create()), [], 7).last_error, "", "0 players")

# ------------------------------------------------------------------ turns

func test_two_players_take_turns_pass_moves_to_the_end_and_never_ends_the_turn() -> void:
	var c := _coop(["a", "b"], true)
	assert_eq(c.current_player, "a")
	assert_seq(c.turn_order, ["a", "b"])
	assert_false(c.can_act("b"))
	assert_eq(c.last_reason, "Not your turn")
	assert_true(c.pass_turn("a"))
	assert_seq(c.turn_order, ["b", "a"])
	assert_eq(c.current_player, "b")
	assert_true(c.pass_turn("b"))
	assert_true(c.pass_turn("a"))
	assert_true(c.pass_turn("b"))
	assert_seq(c.turn_order, ["a", "b"], "pass as often as you like")
	assert_eq(c.round, 1)
	assert_true(c.end_turn("a"))
	assert_seq(c.turn_order, ["b"])
	assert_eq(c.round, 1, "the enemy phase waits for everyone")
	assert_eq(c.session.phase, Phase.Player)
	assert_false(c.can_act("a"), "End turn is final for the round")
	assert_true(c.pass_turn("b"))
	assert_eq(c.current_player, "b", "a lone pass keeps the turn: passing never ends it")
	assert_eq(c.round, 1)
	var enemy_phases := c.log.of_type(GameEventType.PhaseStarted).filter(func(e): return e.detail == "Enemy").size()
	assert_eq(enemy_phases, 0)
	assert_true(c.end_turn("b"))
	assert_eq(c.round, 2, "everyone ended: enemy + level phases ran, next round")
	assert_eq(c.log.of_type(GameEventType.PhaseStarted).filter(func(e): return e.detail == "Enemy").size(), 1)
	assert_seq(c.turn_order, ["a", "b"], "the next round starts in slot order again")

func test_three_players_turn_order() -> void:
	var c := _coop(["a", "b", "c"], true)
	assert_seq(c.turn_order, ["a", "b", "c"])
	c.pass_turn("a")
	assert_seq(c.turn_order, ["b", "c", "a"])
	assert_false(c.end_turn("a"), "not a's turn any more")
	assert_true(c.end_turn("b"))
	assert_seq(c.turn_order, ["c", "a"])
	c.pass_turn("c")
	assert_seq(c.turn_order, ["a", "c"])
	assert_true(c.end_turn("a"))
	assert_eq(c.round, 1)
	assert_false(c.can_act("b"))
	assert_true(c.end_turn("c"))
	assert_eq(c.round, 2)
	assert_seq(c.turn_order, ["a", "b", "c"])

# ------------------------------------------------------------------ energy

func test_separate_pools_split_start_energy_and_income_with_the_remainder_to_slot_0() -> void:
	var c := _coop(["a", "b", "c"], false, [["archer"], ["mage", "archer"], ["priest"]])
	assert_eq(c.energy_of("a"), 4, "10 / 3 = 3, remainder 1 to slot 0")
	assert_eq(c.energy_of("b"), 3)
	assert_eq(c.energy_of("c"), 3)
	c.end_turn("a")
	assert_false(c.can_place("b", "b:mage#1", Vector2i(0, 0)), "mage costs 4, b has 3 (a has 4)")
	assert_eq(c.last_reason, "Not enough energy")
	assert_not_null(c.place("b", "b:archer#1", Vector2i(0, 0)))
	assert_eq(c.energy_of("b"), 0)
	assert_eq(c.energy_of("a"), 4, "only the placer's pool pays")
	assert_eq(c.energy_of("c"), 3)
	var last: GameEvent = c.log.of_type(GameEventType.EnergyChanged).back()
	assert_num(last.facts["Pool"], 1)
	assert_num(last.facts["Energy"], 0)
	c.end_turn("b")
	c.end_turn("c")
	assert_eq(c.energy_of("a"), 4 + 3, "income 5 / 3 = 1, remainder 2 to slot 0")
	assert_eq(c.energy_of("b"), 0 + 1)
	assert_eq(c.energy_of("c"), 3 + 1)
	var income := c.log.of_type(GameEventType.EnergyChanged).filter(func(e): return e.detail == "income")
	assert_eq(income.size(), 3, "one income event per pool")
	c.end_turn("a")
	assert_true(c.sell("b", "b:archer#1"), c.last_reason)
	assert_eq(c.energy_of("b"), 1 + 1, "the refund (3 × 0.5) goes to the seller's pool")
	assert_eq(c.energy_of("a"), 7)

func test_two_separate_pools_split_evenly() -> void:
	var c := _coop(["a", "b"], false)
	assert_eq(c.energy_of("a"), 5)
	assert_eq(c.energy_of("b"), 5)
	c.end_turn("a")
	c.end_turn("b")
	assert_eq(c.energy_of("a"), 5 + 3, "income 5: 3 + 2")
	assert_eq(c.energy_of("b"), 5 + 2)

func test_shared_pool_is_one_pool_every_player_spends_from() -> void:
	var c := _coop(["a", "b"], true)
	assert_eq(c.energy_of("a"), 10)
	assert_eq(c.energy_of("b"), 10)
	assert_not_null(c.place("a", "a:archer#1", Vector2i(0, 0)))
	c.end_turn("a")
	assert_eq(c.energy_of("b"), 7)
	assert_not_null(c.place("b", "b:mage#1", Vector2i(1, 0)))
	assert_eq(c.energy_of("a"), 3)
	c.end_turn("b")
	assert_eq(c.energy_of("a"), 8, "income once into the shared pool")
	assert_eq(c.log.of_type(GameEventType.EnergyChanged).filter(func(e): return e.facts.has("Pool")).size(), 0)

# ------------------------------------------------------------------ control

func test_players_control_only_their_own_towers_and_anyone_the_starting_allies() -> void:
	var c := _coop(["a", "b"], true)
	var tower := c.place("a", "a:archer#1", Vector2i(0, 0))
	assert_not_null(tower)
	var guard: AbilityDef = tower.abilities[0]
	assert_false(c.place("a", "b:archer#1", Vector2i(1, 0)) != null)
	assert_eq(c.last_reason, "Not in your hand")
	assert_false(c.can_cast("b", tower, guard), "not b's turn")
	assert_eq(c.last_reason, "Not your turn")
	c.end_turn("a")
	assert_false(c.can_cast("b", tower, guard))
	assert_eq(c.last_reason, "Not your tower")
	assert_false(c.can_sell("b", "a:archer#1"))
	assert_eq(c.last_reason, "Not your tower")
	var drummer := _drummer(c)
	assert_not_null(drummer)
	assert_true(c.can_cast("b", drummer, drummer.abilities[0]), c.last_reason)
	assert_true(c.cast("b", drummer, drummer.abilities[0], Aim.at(drummer.pos, drummer.pos)), c.last_reason)
	assert_eq(c.units_of("b").size(), 2, "b: the base and the drummer")
	assert_eq(c.units_of("a").size(), 3, "a: their tower, the base and the drummer")
	c.end_turn("b")
	assert_true(c.can_cast("a", tower, guard), c.last_reason)
	assert_true(c.can_sell("a", "a:archer#1"), c.last_reason)

# ------------------------------------------------------------------ protocol commands

func test_apply_command_runs_protocol_commands_and_refuses_bad_ones() -> void:
	var c := _coop(["a", "b"], true)
	var events := c.log.events.size()
	assert_false(c.apply_command("b", {"k": "place", "tower": "b:archer#1", "x": 0, "y": 0}))
	assert_eq(c.last_reason, "Not your turn")
	assert_false(c.apply_command("a", {"k": "place", "tower": "a:archer#1", "x": 0}))
	assert_eq(c.last_reason, "Bad command")
	assert_false(c.apply_command("a", {"k": "dance"}))
	assert_eq(c.last_reason, "Unknown command")
	assert_false(c.apply_command("a", {"k": "place", "tower": "a:archer#1", "x": 2.0, "y": 1.0}))
	assert_eq(c.last_reason, "On a path")
	assert_false(c.apply_command("z", {"k": "pass"}))
	assert_eq(c.last_reason, "Not in the match")
	assert_eq(c.log.events.size(), events, "refused commands write nothing")
	assert_true(c.apply_command("a", {"k": "place", "tower": "a:archer#1", "x": 0.0, "y": 0.0}), c.last_reason)
	var tower := c.session.placed_tower("a:archer#1")
	assert_false(c.apply_command("a", {"k": "cast", "unit": tower.id, "ability": "Fly", "x": 0, "y": 0}))
	assert_eq(c.last_reason, "Not its ability")
	assert_false(c.apply_command("a", {"k": "cast", "unit": tower.id, "ability": "Guard", "x": 4, "y": 2}))
	assert_eq(c.last_reason, "Not a valid target")
	assert_false(c.apply_command("a", {"k": "cast", "unit": 999, "ability": "Guard", "x": 0, "y": 0}))
	assert_eq(c.last_reason, "No such unit")
	assert_true(c.apply_command("a", {"k": "cast", "unit": tower.id, "ability": "Guard", "x": 0, "y": 0}), c.last_reason)
	assert_true(c.apply_command("a", {"k": "pass"}))
	assert_eq(c.current_player, "b")
	assert_false(c.apply_command("b", {"k": "sell", "tower": "a:archer#1"}))
	assert_eq(c.last_reason, "Not your tower")
	assert_true(c.apply_command("b", {"k": "end_turn"}))
	assert_true(c.apply_command("a", {"k": "sell", "tower": "a:archer#1"}), c.last_reason)
	assert_true(c.apply_command("a", {"k": "end_turn"}))
	assert_eq(c.round, 2)

# ------------------------------------------------------------------ leaving

func test_a_leaver_is_skipped_their_towers_turn_neutral_and_their_pool_closes() -> void:
	var c := _coop(["a", "b", "c"], false)
	var tower := c.place("a", "a:archer#1", Vector2i(0, 0))
	assert_not_null(tower)
	c.end_turn("a")
	assert_eq(c.current_player, "b")
	assert_true(c.remove_player("a"))
	assert_false(c.remove_player("a"), "already left")
	assert_seq(c.players, ["b", "c"])
	assert_eq(c.energy_of("a"), 0, "a's pool is closed")
	assert_false(c.pools.has("a"))
	assert_true(c.can_cast("b", tower, tower.abilities[0]), "a leaver's tower is neutral: anyone may cast with it")
	assert_false(c.can_act("a"))
	assert_eq(c.last_reason, "Left the match")
	var b_before := c.energy_of("b")
	var c_before := c.energy_of("c")
	c.end_turn("b")
	c.end_turn("c")
	assert_eq(c.round, 2)
	assert_seq(c.turn_order, ["b", "c"], "a's turn is skipped from now on")
	assert_eq(c.energy_of("b"), b_before + 1, "the others keep their own income shares")
	assert_eq(c.energy_of("c"), c_before + 1)
	assert_eq(c.log.of_type(GameEventType.EnergyChanged).filter(func(e): return e.detail == "income").size(), 2)
	assert_not_null(c.state.get_entity(tower.id))
	assert_true(c.state.get_entity(tower.id).alive, "the tower stays on the board")
	# the acting player leaves: the next one acts; the last one waiting leaving ends the round
	assert_true(c.remove_player("b"))
	assert_eq(c.current_player, "c")
	c.pass_turn("c")
	assert_eq(c.round, 2)
	var two := _coop(["a", "b"], true)
	two.end_turn("a")
	assert_true(two.remove_player("b"))
	assert_eq(two.round, 2, "everyone left in the round had ended: the enemy phase runs")
	assert_seq(two.turn_order, ["a"])

# ------------------------------------------------------------------ determinism (real content)

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load("res://data/content")
	return _lib

func _real(level_id: String, ids: Array, hands: Array, shared: bool, cap := 3) -> CoopSession:
	var convert := AssetConverter.new()
	var level := convert.level(lib().catalog.find_level(level_id))
	var type_by_id := func(t): return convert.tower_type(lib().catalog.find_tower(t))
	var players := []
	for i in ids.size(): players.append({"id": ids[i], "hand": CoopSession.build_hand(ids[i], hands[i], type_by_id)})
	var c := CoopSession.new(level, convert.rules(lib().rules), players, 12345, shared, cap)
	c.start()
	return c

## A simple policy in turns (like tools/golden.gd): each player places their unplaced towers on the first free
## tile, quick-casts every non-movement ability of the units they command, then ends their turn; the first
## player passes once every even round. Returns the [player, command] list it applied.
func _play(c: CoopSession, max_rounds: int, checksums: Array = []) -> Array:
	var record := []
	var passed := -1
	var guard := 0
	while not c.is_over and c.round <= max_rounds and guard < 2000:
		guard += 1
		var p := c.current_player
		if p == "": break
		if c.round % 2 == 0 and p == c.slots[0] and passed != c.round and c.turn_order.size() > 1:
			passed = c.round
			_apply(c, p, {"k": "pass"}, record)
			continue
		for t in c.hand_of(p):
			if c.session.placed.has(t.id) or c.is_over: continue
			var tile = null
			for y in c.state.grid.height:
				if tile != null: break
				for x in c.state.grid.width:
					if c.can_place(p, t.id, Vector2i(x, y)):
						tile = Vector2i(x, y)
						break
			if tile != null: _apply(c, p, CoopSession.place_command(t.id, tile), record)
		for unit in c.units_of(p):
			if c.is_over: break
			if not unit.alive: continue
			for ability in unit.abilities.duplicate():
				if c.is_over or ability.targeting.is_movement or not c.can_cast(p, unit, ability): continue
				var aim = Instinct.quick_cast(c.state, unit, ability)
				if aim != null: _apply(c, p, CoopSession.cast_command(unit, ability, aim), record)
		if c.is_over: break
		var r := c.round
		_apply(c, p, {"k": "end_turn"}, record)
		if c.round != r or c.is_over: checksums.append(c.checksum())
	return record

func _apply(c: CoopSession, p: String, cmd: Dictionary, record: Array) -> void:
	var ok := c.apply_command(p, cmd)
	assert_true(ok, "%s %s: %s" % [p, cmd, c.last_reason])
	record.append([p, JSON.parse_string(JSON.stringify(cmd))]) # as it arrives from the relay (numbers as floats)

func _replay(c: CoopSession, record: Array, checksums: Array = []) -> void:
	for pc in record:
		var r := c.round
		var ok := c.apply_command(pc[0], pc[1])
		assert_true(ok, "replay %s %s: %s" % [pc[0], pc[1], c.last_reason])
		if pc[1].k == "end_turn" and (c.round != r or c.is_over): checksums.append(c.checksum())

func test_the_same_commands_give_the_same_log_and_checksums() -> void:
	var hands := [["archer", "mage"], ["priest", "archer", "guardian"]]
	var a := _real("chapter2-3", ["p1", "p2"], hands, false)
	var sums_a := []
	var record := _play(a, 12, sums_a)
	assert_true(record.size() > 20, "the policy played: %d commands" % record.size())
	assert_true(sums_a.size() >= 5, "rounds played: %d" % sums_a.size())
	var b := _real("chapter2-3", ["p1", "p2"], hands, false)
	var sums_b := []
	_replay(b, record, sums_b)
	assert_eq(b.log.dump(b.state), a.log.dump(a.state))
	assert_seq(sums_b, sums_a)
	assert_eq(b.checksum(), a.checksum())
	assert_eq(b.state_digest(), a.state_digest())
	assert_eq(a.checksum().length(), 16)
	# one command different: the checksum differs from then on
	var at := -1
	for i in record.size():
		if record[i][1].k == "place":
			at = i
			break
	assert_true(at >= 0)
	var changed := _real("chapter2-3", ["p1", "p2"], hands, false)
	var same := _real("chapter2-3", ["p1", "p2"], hands, false)
	for i in at:
		changed.apply_command(record[i][0], record[i][1])
		same.apply_command(record[i][0], record[i][1])
	var cmd: Dictionary = record[at][1].duplicate()
	same.apply_command(record[at][0], cmd)
	var moved := false
	for y in changed.state.grid.height:
		for x in changed.state.grid.width:
			if moved or (x == int(cmd.x) and y == int(cmd.y)): continue
			if changed.can_place(record[at][0], cmd.tower, Vector2i(x, y)):
				changed.apply_command(record[at][0], {"k": "place", "tower": cmd.tower, "x": x, "y": y})
				moved = true
	assert_true(moved)
	assert_ne(changed.checksum(), same.checksum())

func test_three_players_replay_identically() -> void:
	var hands := [["archer"], ["mage"], ["priest", "guardian"]]
	var a := _real("chapter1-3", ["x", "y", "z"], hands, false)
	var sums_a := []
	var record := _play(a, 10, sums_a)
	var b := _real("chapter1-3", ["x", "y", "z"], hands, false)
	var sums_b := []
	_replay(b, record, sums_b)
	assert_eq(b.log.dump(b.state), a.log.dump(a.state))
	assert_seq(sums_b, sums_a)

func test_one_player_shared_pool_matches_a_plain_level_session() -> void:
	var convert := AssetConverter.new()
	var level_asset := lib().catalog.find_level("chapter1-1")
	var c := _real("chapter1-1", ["solo"], [["archer", "mage", "priest"]], true)
	var record := _play(c, 40)
	assert_true(c.is_over, "played to the end")
	var hand := []
	for t in c.hand_of("solo"):
		var d := TowerDef.new()
		d.id = t.id
		d.type = convert.tower_type(lib().catalog.find_tower(t.type.id))
		hand.append(d)
	var s := LevelSession.new(convert.level(level_asset), convert.rules(lib().rules), hand, 12345)
	s.start()
	for pc in record:
		var cmd: Dictionary = pc[1]
		match cmd.k:
			"place": s.place(cmd.tower, Vector2i(int(cmd.x), int(cmd.y)))
			"sell": s.sell(cmd.tower)
			"end_turn": s.end_round()
			"cast":
				var unit: Entity = s.state.get_entity(int(cmd.unit))
				var ability: AbilityDef = null
				for a in unit.abilities:
					if a.name == cmd.ability: ability = a
				var aim: Aim = null
				for v in Targeting.valid_aims(s.state, unit.id, ability):
					if v.tile == Vector2i(int(cmd.x), int(cmd.y)):
						aim = v
						break
				s.cast(unit, ability, aim)
	assert_eq(c.log.dump(c.state), s.log.dump(s.state))
	assert_eq(c.session.energy, s.energy)
	assert_eq(c.session.outcome, s.outcome)

# ------------------------------------------------------------------ checksum, co-op list, content hash

func test_fnv1a64_vectors() -> void:
	assert_eq(CoopSession.fnv1a64("".to_utf8_buffer()), "cbf29ce484222325")
	assert_eq(CoopSession.fnv1a64("a".to_utf8_buffer()), "af63dc4c8601ec8c")
	assert_eq(CoopSession.fnv1a64("foobar".to_utf8_buffer()), "85944171f73967e8")

func test_the_coop_list_holds_the_coop_missions() -> void:
	# Missions & Guild — Design: every multiplayer level is a mission; data/coop.json mirrors them for the relay
	var list := CoopList.load()
	assert_eq(list.last_error, "")
	assert_seq(list.level_ids(), ["chapter1-3", "chapter2-1", "chapter2-2", "chapter2-3", "chapter2-4"])
	assert_false(list.shared_pool("chapter1-3"))
	assert_false(list.shared_pool("chapter2-1"))
	assert_false(list.shared_pool("chapter2-4"))
	for id in list.level_ids():
		assert_eq(list.hand_cap(id), 3)
		assert_true(list.is_unlocked(id))
	assert_eq(list.level_assets(lib().catalog).size(), 5, "every entry is a catalog level")
	assert_false(list.is_unlocked("tutorial"))
	var parsed := CoopList.parse('{"levels": [{"level": "x"}]}')
	assert_eq(parsed.hand_cap("x"), 3, "coopHandCap defaults to 3")
	assert_false(parsed.shared_pool("x"))
	assert_ne(CoopList.parse("nope").last_error, "")

func test_content_hash_is_stable_and_changes_with_the_content() -> void:
	var h := ContentHash.compute()
	assert_eq(h.length(), 16)
	assert_eq(ContentHash.compute(), h)
	var files := [["B.json", "{\"b\":1}".to_utf8_buffer()], ["A.json", "{\"a\":1}".to_utf8_buffer()]]
	var reversed := [files[1], files[0]]
	assert_eq(ContentHash.of_files(files), ContentHash.of_files(reversed), "sorted by file name")
	var other := [["A.json", "{\"a\":2}".to_utf8_buffer()], files[0]]
	assert_ne(ContentHash.of_files(other), ContentHash.of_files(files))
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("{\"a\":1}{\"b\":1}coop-1".to_utf8_buffer())
	assert_eq(ContentHash.of_files(files), ctx.finish().hex_encode().substr(0, 16))
