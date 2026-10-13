extends TestCase
## Port of LevelTests.cs: Game Overview — Design: rounds, waves, energy, hand, placement, enemy turns, base, paths.

# Map (7×3): a path along y = 1 from x = 0 to 5, the base at its end (6, 1); ground above and below.
const BaseTile := Vector2i(6, 1)

static func _walk() -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Walk"
	a.tags = [Tags.Movement]
	a.targeting = PatternDef.path_ahead("Self.Speed")
	a.steps = [WalkStep.new()]
	return a

static func _strike(name: String, range: String, filter: String, power: int, cooldown := 0, dies_doing_it := false) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = name
	a.tags = [Tags.Attack]
	a.targeting = PatternDef.diamond(range)
	a.target_filter = Condition.new(filter)
	a.cooldown = cooldown
	var atk := AttackStep.new()
	atk.can_miss = false
	atk.can_crit = false
	atk.power = Formula.new(str(power))
	var dmg := DamageStep.new()
	dmg.amount = Formula.new("ActionPower")
	atk.on_hit = [dmg]
	a.steps = [atk]
	if dies_doing_it:
		var self_dmg := DamageStep.new()
		self_dmg.amount = Formula.new("Self.Hp")
		self_dmg.on = StepTarget.Self
		a.steps.append(self_dmg)
	return a

static func _slime() -> EntityDef:
	var d := EntityDef.new()
	d.name = "Slime"
	d.footing = Footing.OnPath
	d.abilities = [_walk(), _strike("Ram", "1", "Target.HasTag(Base)", 5, 0, true)]
	return d.stat("MaxHp", 10).stat("Speed", 1)

static func _archer() -> EntityDef:
	var d := EntityDef.new()
	d.name = "Archer"
	d.footing = Footing.OffPath
	d.abilities = [_strike("Shoot", "2", "Target.IsEnemy", 10, 1)]
	return d.stat("MaxHp", 20).stat("Speed", 2)

static func _base_def() -> EntityDef:
	var d := EntityDef.new()
	d.name = "Base"
	d.kind = EntityKind.Object_
	d.tags = [Tags.Base]
	return d.stat("MaxHp", 10)

static func _level() -> LevelDef:
	var slime := _slime()
	var level := LevelDef.new()
	level.name = "Test"
	level.width = 7
	level.height = 3
	level.start_energy = 5
	level.energy_per_round = 1
	level.hand_cap = 4
	var path := []
	for x in 6: path.append(Vector2i(x, 1))
	level.paths = [path]
	var b := BaseDef.new()
	b.tile = BaseTile
	b.entity = _base_def()
	level.bases = [b]
	var first := WaveDef.new()
	first.name = "First"
	first.start_round = 1
	first.spawns.append(_spawn(1, slime))
	first.spawns.append(_spawn(2, slime))
	var msg := LevelEventDef.new()
	msg.round = 2
	msg.kind = LevelEventKind.ShowMessage
	msg.message = "Another slime!"
	first.events.append(msg)
	var second := WaveDef.new()
	second.name = "Second"
	second.start = WaveStart.AfterWave
	second.after_wave = 0
	second.spawns.append(_spawn(1, slime))
	level.waves.append(first)
	level.waves.append(second)
	return level

static func _spawn(round: int, enemy: EntityDef) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.round = round
	s.enemy = enemy
	return s

static func _rules() -> GameRules:
	return GameRules.new(CombatVocabulary.create())

static func _session(hand: Array = []) -> LevelSession:
	var s := LevelSession.new(_level(), _rules(), hand, 7)
	s.start()
	return s

static func _archer_tower(id := "archer-1", cost := 3) -> TowerDef:
	var type := TowerType.new()
	type.id = "archer"
	type.name = "Archer"
	type.entity = _archer()
	type.cost = cost
	var t := TowerDef.new()
	t.id = id
	t.type = type
	return t

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _tiles(aims: Array) -> Array:
	return aims.map(func(a): return a.tile)

static func _count(events: Array, pred: Callable) -> int:
	var n := 0
	for e in events:
		if pred.call(e): n += 1
	return n

func test_a_change_terrain_level_event_changes_tiles_in_its_round() -> void:
	var level := _level()
	level.terrain[Vector2i(3, 2)] = TerrainDef.Chasm
	var ev := LevelEventDef.new()
	ev.round = 2
	ev.kind = LevelEventKind.ChangeTerrain
	ev.terrain = TerrainDef.Ground
	ev.tiles = [Vector2i(3, 2)]
	ev.build = BuildChange.On
	level.waves[0].events.append(ev)
	var s := LevelSession.new(level, _rules(), [_archer_tower()], 7)
	s.start()
	assert_false(s.can_place("archer-1", Vector2i(3, 2)), "a chasm at first")
	s.end_round()
	assert_true(s.state.grid.terrain_at(Vector2i(3, 2)) == TerrainDef.Chasm, "level events run in the level phase, after the enemies")
	s.end_round()                             # round 2's level phase: the chasm is filled
	assert_true(s.state.grid.terrain_at(Vector2i(3, 2)) == TerrainDef.Ground, s.log.dump(s.state))
	assert_true(s.can_place("archer-1", Vector2i(3, 2)), s.last_reason)
	assert_eq(s.log.of_type(GameEventType.TileChanged).size(), 1)

func test_killing_the_last_enemy_wins_at_once() -> void:
	var level := _level()
	level.waves.remove_at(1)                  # one wave: two slimes, rounds 1 and 2
	level.waves[0].events.clear()
	var s := LevelSession.new(level, _rules(), [_archer_tower()], 7)
	s.start()
	var archer := s.place("archer-1", Vector2i(4, 2))
	var shoot: AbilityDef = archer.abilities[0]

	s.end_round()                             # round 1: the first slime spawns
	s.end_round()                             # round 2: it walks, the second one spawns
	assert_eq(s.outcome, Outcome.Running)
	var won_by_the_shot := false
	for guard in 10:
		if s.is_over: break
		var target: Entity = null
		for e in s.enemies:
			if _manhattan(e.pos, archer.pos) <= 2:
				target = e
				break
		if target != null and s.can_cast(archer, shoot):
			s.cast(archer, shoot, Aim.at(archer.pos, target.pos))
			won_by_the_shot = s.is_over
		if not s.is_over: s.end_round()
	assert_eq(s.outcome, Outcome.Won, s.log.dump(s.state))
	assert_true(won_by_the_shot, "the shot that killed the last slime won, not the End round after it")
	assert_true(s.waves.all(func(w): return w.finished))

# ------------------------------------------------------------------ hopping, flying, teleporting

func test_hoppers_jump_over_units_on_the_road_and_flyers_cross_a_chasm_road() -> void:
	var level := _level()
	var rock := EntityDef.new()
	rock.name = "Rock"; rock.kind = EntityKind.Object_; rock.tags = [Tags.Rock]
	rock.stat("MaxHp", 10)
	var su := StartingUnitDef.new()
	su.entity = rock; su.tile = Vector2i(2, 1); su.side = StartingSide.Neutral
	level.starting_units.append(su)
	level.terrain[Vector2i(3, 1)] = TerrainDef.Chasm # the road crosses a chasm at (3, 1)
	var hop := AbilityDef.new()
	hop.name = "Hop"; hop.tags = [Tags.Movement]
	var pat := PatternDef.new()
	pat.shape = Shape.PathAhead; pat.max_radius = Formula.new("3"); pat.min_radius = Formula.new("1"); pat.include_center = false; pat.jumps_over_units = true
	hop.targeting = pat
	hop.steps = [JumpStep.new()]
	var rabbit := EntityDef.new()
	rabbit.name = "Rabbit"; rabbit.footing = Footing.OnPath; rabbit.abilities = [hop]
	rabbit.stat("MaxHp", 5).stat("Speed", 3)
	var bat := EntityDef.new()
	bat.name = "Bat"; bat.footing = Footing.OnPath; bat.tags = [Tags.Flying]; bat.abilities = [_walk()]
	bat.stat("MaxHp", 5).stat("Speed", 3)
	var su2 := StartingUnitDef.new()
	su2.entity = rabbit; su2.tile = Vector2i(1, 1); su2.side = StartingSide.Enemy
	level.starting_units.append(su2)
	var s := LevelSession.new(level, _rules(), [], 7)
	s.start()

	var rs := s.enemies.filter(func(e): return e.name == "Rabbit")
	assert_eq(rs.size(), 1)
	var r: Entity = rs[0]
	var landings := _tiles(Targeting.valid_aims(s.state, r.id, hop))
	assert_not_contains(landings, Vector2i(2, 1), "it never lands on the rock")
	assert_not_contains(landings, Vector2i(3, 1), "a walker cannot stand over the chasm")
	assert_eq(landings.size(), 0, "the chasm stops it: (2, 1) is a rock, (3, 1) a chasm, nothing beyond is reached")

	var b := s.state.create(bat, Teams.Enemy, Vector2i(4, 1))
	b.path_id = 0
	assert_true(s.state.can_stand(b, Vector2i(3, 1)), "a flyer stands over a chasm")
	assert_false(s.state.can_stand(r, Vector2i(3, 1)))

func test_a_free_tile_ability_aims_only_where_the_caster_could_stand() -> void:
	var s := _session([_archer_tower()])
	var archer := s.place("archer-1", Vector2i(2, 2))
	var blink := AbilityDef.new()
	blink.name = "Blink"; blink.targeting = PatternDef.diamond("2"); blink.needs_free_tile = true; blink.steps = [TeleportStep.new()]
	var aims := _tiles(Targeting.valid_aims(s.state, archer.id, blink))
	assert_true(aims.size() > 0)
	assert_false(aims.any(func(t): return t.y == 1), "towers never land on the road")
	assert_not_contains(aims, archer.pos, "nor on a taken tile")
	if aims.is_empty(): return
	s.resolver.cast(archer, blink, Aim.at(archer.pos, aims[0])) # not one of its abilities: cast straight through the resolver
	assert_eq(archer.pos, aims[0])

# ------------------------------------------------------------------ starting units

func test_starting_units_ally_neutral_and_enemy() -> void:
	var level := _level()
	var rock := EntityDef.new()
	rock.name = "Rock"; rock.kind = EntityKind.Object_
	rock.stat("MaxHp", 10)
	for spec in [[_archer(), Vector2i(4, 2), StartingSide.Ally], [rock, Vector2i(3, 1), StartingSide.Neutral], [_slime(), Vector2i(4, 1), StartingSide.Enemy]]:
		var u := StartingUnitDef.new()
		u.entity = spec[0]; u.tile = spec[1]; u.side = spec[2]
		level.starting_units.append(u)
	var s := LevelSession.new(level, _rules(), [], 7)
	s.start()

	assert_eq(s.allies.size(), 1)
	var ally := s.state.get_entity(s.allies[0])
	var stone: Entity = s.state.entities.filter(func(e): return e.name == "Rock")[0]
	assert_eq(s.enemies.size(), 1)
	var slime: Entity = s.enemies[0]
	assert_true(s.is_commanded(ally), "the player commands a starting ally")
	assert_true(s.player_units.has(ally), "it takes its turn with the towers")
	assert_eq(stone.base_team, Teams.Neutral)
	assert_eq(s.state.relation(ally, stone), Relation.Enemy, "both sides may attack an obstacle")
	assert_eq(slime.path_id, 0, "a starting enemy walks the road through its tile")
	assert_eq(slime.wave, 0, "and belongs to the first wave")

	var shoot: AbilityDef = ally.abilities[0]
	assert_true(s.can_cast(ally, shoot), s.last_reason)
	s.cast(ally, shoot, Aim.at(ally.pos, slime.pos))
	assert_false(slime.alive, "the ally shoots it for 10")

	s.end_round() # the first wave's slime spawns and walks; the rock stops it at (2, 1)
	assert_true(stone.alive)
	assert_true(s.enemies.all(func(e): return e.pos.x < 3), s.log.dump(s.state))

# ------------------------------------------------------------------ placement and energy

func test_buildable_tiles_limit_placement_when_a_level_has_any() -> void:
	var level := _level()
	level.buildable[Vector2i(2, 2)] = true
	var s := LevelSession.new(level, _rules(), [_archer_tower("a")], 7)
	s.start()

	assert_false(s.can_place("a", Vector2i(1, 2)))
	assert_eq(s.last_reason, "Not a buildable tile")
	assert_eq(s.state.grid.tile(Vector2i(2, 2)), TileType.Buildable)
	assert_true(s.can_place("a", Vector2i(2, 2)), s.last_reason)

	var open := _session([_archer_tower("b")])
	assert_true(open.can_place("b", Vector2i(1, 2)), "no buildable tiles: anywhere off the path, as before")

func test_placement_needs_energy_a_free_tile_off_the_path() -> void:
	var s := _session([_archer_tower("a"), _archer_tower("b")])
	assert_eq(s.phase, Phase.Player)

	assert_false(s.can_place("a", Vector2i(2, 1)))
	assert_eq(s.last_reason, "On a path")
	assert_false(s.can_place("a", BaseTile))

	var a := s.place("a", Vector2i(2, 2))
	assert_eq(a.position, Vector2i(2, 2))
	assert_eq(s.energy, 2)
	assert_false(s.can_place("a", Vector2i(3, 2)))
	assert_eq(s.last_reason, "Already placed")
	assert_false(s.can_place("b", Vector2i(3, 2)))
	assert_eq(s.last_reason, "Not enough energy")

func test_hand_cap_limits_the_towers_in_the_level() -> void:
	var hand := []
	for i in 8: hand.append(_archer_tower("t" + str(i)))
	var s := _session(hand)
	assert_seq(s.hand.map(func(t): return t.id), ["t0", "t1", "t2", "t3"])

func test_every_tower_in_the_hand_needs_its_own_id() -> void:
	var archer := _archer_tower("archer-1")
	var bad := LevelSession.new(_level(), _rules(), [archer, archer], 7)
	assert_eq(bad.last_error, "Tower ID 'archer-1' is in the hand 2 times; every tower needs its own ID.", "the C# throws ArgumentException")

	var s := _session([_archer_tower("a"), _archer_tower("b")])
	while s.energy < 6: s.end_round()
	s.place("a", Vector2i(1, 2))
	s.place("b", Vector2i(3, 2))
	assert_eq(s.towers.size(), 2, "two archers, two towers")

func test_selling_refunds_half_the_cost_scaled_by_hp() -> void:
	var s := _session([_archer_tower("a", 10), _archer_tower("b")])
	while s.energy < 10: s.end_round() # 5 + 1 per round
	var before := s.energy
	var a := s.place("a", Vector2i(2, 2))
	a.hp = 10 # half health

	assert_eq(s.sell_value("a"), 2) # 10 × 0.5 × 10/20 = 2.5 → 2
	s.sell("a")
	assert_eq(s.energy, before - 10 + 2)
	assert_eq(a.life, LifeState.Removed)
	assert_false(s.placed.has("a"), "a sold tower is back in the hand")
	assert_false(s.can_place("a", Vector2i(3, 2)))
	assert_eq(s.last_reason, "Not enough energy", "re-placing costs the full price")

# ------------------------------------------------------------------ rounds, waves, outcome

func test_waves_spawn_on_schedule_and_towers_win_the_level() -> void:
	var s := _session([_archer_tower()])
	var archer := s.place("archer-1", Vector2i(2, 2))
	var shoot: AbilityDef = archer.abilities[0]

	for guard in 30:
		if s.is_over: break
		var aims := Targeting.valid_aims(s.state, archer.id, shoot)
		var aim: Aim = aims[0] if aims.size() > 0 else null
		if aim != null and s.can_cast(archer, shoot):
			s.cast(archer, shoot, aim)
			assert_false(s.can_cast(archer, shoot), "cooldown")
			if not s.is_over: assert_eq(s.last_reason, "On cooldown (1)")
		if not s.is_over: s.end_round() # the last kill wins at once

	assert_eq(s.outcome, Outcome.Won, s.log.dump(s.state))
	assert_true(s.waves.all(func(w): return w.finished))
	assert_eq(s.log.of_type(GameEventType.WaveStarted).size(), 2)
	assert_eq(_count(s.log.of_type(GameEventType.EntitySpawned), func(e): return s.state.get_entity(e.target).name == "Slime"), 3)
	assert_seq(s.messages, ["Another slime!"])
	assert_true(s.state.get_entity(s.bases[0]).alive)
	assert_eq(_count(s.log.of_type(GameEventType.EntityDied), func(e): return e.source == archer.id), 3, "the archer killed all three slimes")
	assert_eq(_count(s.log.of_type(GameEventType.DamageDealt), func(e): return e.target == s.bases[0]), 0)

func test_enemies_walk_their_path_and_ram_the_base_until_it_falls() -> void:
	var s := _session()
	for guard in 30:
		if s.is_over: break
		s.end_round()

	assert_eq(s.outcome, Outcome.Lost, s.log.dump(s.state))
	assert_eq(s.phase, Phase.Over)
	var rams := s.log.of_type(GameEventType.DamageDealt).filter(func(e): return e.target == s.bases[0])
	assert_eq(rams.size(), 2, "two slimes, 5 damage each, base HP 10")
	assert_true(s.log.of_type(GameEventType.EntityMoved).all(func(e): return e.to.y == 1), "enemies never leave the path")

func _enemy_at(s: LevelSession, p: Vector2i) -> Entity:
	for e in s.enemies:
		if e.pos == p: return e
	return null

func test_turn_forecast_shows_the_walk_and_the_ram_the_enemy_then_makes() -> void:
	var s := _session()
	for guard in 30:
		if _enemy_at(s, Vector2i(4, 1)) != null: break
		s.end_round()
	var slime := _enemy_at(s, Vector2i(4, 1))
	if slime == null:
		fail("no slime reached (4, 1)")
		return
	var base_hp: int = s.state.get_entity(s.bases[0]).hp
	var events: int = s.log.events.size()
	var rng: int = s.state.rng.clone().next_uint()

	var steps := TurnForecast.of(s.state, slime.id)

	assert_eq(steps.size(), 2, "walks one tile, then rams the base")
	if steps.size() == 2:
		assert_true(steps[0].is_movement)
		assert_eq(steps[0].aim.tile, Vector2i(5, 1))
		assert_eq(steps[1].ability.name, "Ram")
		assert_contains(steps[1].preview.targets, s.bases[0])
	assert_eq(slime.pos, Vector2i(4, 1), "the real state is untouched")
	assert_eq(s.log.events.size(), events)
	assert_eq(s.state.rng.clone().next_uint(), rng, "the real RNG is untouched")

	# the slime behind it: alone it is blocked, but after the front one's turn the road is free
	var behind := _enemy_at(s, Vector2i(3, 1))
	assert_false(TurnForecast.of(s.state, behind.id).any(func(st): return st.is_movement), "blocked by the unit ahead")
	var before_ids := []
	for e in s.enemy_order():
		if e.id == behind.id: break
		before_ids.append(e.id)
	var after := TurnForecast.of(s.state, behind.id, before_ids).filter(func(st): return st.is_movement)
	assert_eq(after.size(), 1)
	if after.size() == 1: assert_eq(after[0].aim.tile, Vector2i(4, 1), "the front slime walked on first")

	s.end_round()
	assert_eq(s.state.get_entity(s.bases[0]).hp, base_hp - 5, "the forecast was what happened")
	assert_false(slime.alive, "it died ramming")
	assert_eq(behind.pos, Vector2i(4, 1))

func test_wave_is_not_finished_while_its_schedule_remains() -> void:
	var s := _session()
	s.end_round() # round 1: first slime spawns
	assert_true(s.waves[0].started)
	for e in s.enemies: e.hp = 0 # not through the resolver: killed below
	var heal := HealEffect.new()
	heal.target_id = s.bases[0]; heal.amount = Formula.new("0"); heal.source = 0
	s.resolver.run(heal) # a checkpoint
	s.end_round() # round 2: second spawn and the message are still scheduled
	assert_false(s.waves[0].finished)

func test_a_dead_tower_goes_back_to_the_hand() -> void:
	var level := _level()
	var biter := EntityDef.new()
	biter.name = "Biter"
	biter.footing = Footing.OnPath
	biter.abilities = [_strike("Bite", "1", "Target.IsEnemy and not Target.HasTag(Base)", 50)]
	biter.stat("MaxHp", 100).stat("Speed", 0)
	level.waves.clear()
	var wave := WaveDef.new()
	wave.spawns.append(_spawn(1, biter))
	level.waves.append(wave)
	var s := LevelSession.new(level, _rules(), [_archer_tower()], 7)
	s.start()
	s.end_round()                                # the biter spawns at (0, 1)
	var archer := s.place("archer-1", Vector2i(0, 2))
	s.end_round()                                # the biter bites the archer

	assert_eq(archer.life, LifeState.Removed, s.log.dump(s.state))
	assert_false(s.placed.has("archer-1"))
	assert_true(s.can_place("archer-1", Vector2i(3, 2)), "placeable again, at full price")

# ------------------------------------------------------------------ movement

func test_a_looping_road_is_walked_step_by_step_through_its_own_crossing() -> void:
	# R R R U L D D R: the road passes (2, 1) twice (steps 2 and 6)
	var grid := BattleGrid.new(5, 3)
	grid.add_path(Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0), Vector2i(3, 0))
	var state := GameState.new(_rules(), grid, 1)
	var def := _slime().stat("Speed", 1)
	var walk: AbilityDef = def.abilities[0]
	var slime := state.create(def, Teams.Enemy, Vector2i(0, 1))
	slime.path_id = 0
	slime.path_step = 0
	var resolver := Resolver.new(state)

	var progress := []
	for i in 8:
		var aims := Targeting.valid_aims(state, slime.id, walk)
		assert_eq(aims.size(), 1)
		if aims.size() != 1: return
		resolver.cast(slime, walk, aims[0])
		progress.append(slime.path_progress)
	assert_seq(progress, [1, 2, 3, 4, 5, 6, 7, 8], "the second pass over (2, 1) is step 6, not 2")
	assert_eq(slime.position, Vector2i(3, 0))

	# a unit on the crossing blocks the road's other pass too
	var state2 := GameState.new(_rules(), grid, 1)
	var first := state2.create(def, Teams.Enemy, Vector2i(2, 1)); first.path_id = 0; first.path_step = 2
	var second := state2.create(def, Teams.Enemy, Vector2i(2, 2)); second.path_id = 0; second.path_step = 5
	assert_eq(second.path_progress, 5)
	assert_eq(Targeting.valid_aims(state2, second.id, walk).size(), 0, "the crossing is taken by the unit on its first pass")
	assert_eq(grid.path(0).direction_at_step(6), Dirs.cardinal_between(Vector2i(2, 1), Vector2i(2, 0)))

func test_path_ahead_stops_at_the_unit_ahead_and_at_gaps() -> void:
	var rules := _rules()
	var grid := BattleGrid.new(8, 3)
	grid.add_path(Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(6, 1)) # gap between 3 and 5
	var state := GameState.new(rules, grid, 1)
	var def := _slime().stat("Speed", 5)
	var back := state.create(def, Teams.Enemy, Vector2i(0, 1)); back.path_id = 0
	var front := state.create(def, Teams.Enemy, Vector2i(2, 1)); front.path_id = 0
	var walk: AbilityDef = def.abilities[0]

	assert_seq(_tiles(Targeting.valid_aims(state, back.id, walk)), [Vector2i(1, 1)], "blocked by the unit ahead")
	assert_seq(_tiles(Targeting.valid_aims(state, front.id, walk)), [Vector2i(3, 1)], "a gap cannot be walked")

func test_towers_walk_around_walls_and_never_onto_a_path() -> void:
	var grid := BattleGrid.new(5, 5)
	grid.add_path(Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2))
	grid.set_terrain(Vector2i(1, 0), TerrainDef.Wall)
	var state := GameState.new(_rules(), grid, 1)
	var def := _archer()
	var walk := AbilityDef.new()
	walk.name = "Walk"; walk.tags = [Tags.Movement]; walk.targeting = PatternDef.steps("Self.Speed"); walk.steps = [WalkStep.new()]
	def.abilities.append(walk)
	var tower := state.create(def, Teams.Player, Vector2i(0, 0))

	var aims := Targeting.valid_aims(state, tower.id, walk)
	assert_set(_tiles(aims), [Vector2i(0, 1), Vector2i(1, 1)])
	var to11 := aims.filter(func(a): return a.tile == Vector2i(1, 1))
	assert_eq(to11.size(), 1)
	if to11.size() != 1: return
	assert_eq(to11[0].path.size(), 2, "around the wall: (0,1) then (1,1)")

	Resolver.new(state).cast(tower, walk, to11[0])
	assert_eq(tower.position, Vector2i(1, 1))

func test_terrain_is_part_of_the_state_and_decides_who_stands() -> void:
	var grid := BattleGrid.new(4, 1)
	grid.set_terrain(Vector2i(1, 0), TerrainDef.Chasm)
	var state := GameState.new(_rules(), grid, 1)
	var copy := state.clone()

	state.grid.set_terrain(Vector2i(1, 0), TerrainDef.Ground) # the chasm is filled
	assert_true(state.grid.can_stand_on(Vector2i(1, 0), false))
	assert_false(copy.grid.can_stand_on(Vector2i(1, 0), false), "a copy keeps its own terrain")
	assert_true(copy.grid.can_stand_on(Vector2i(1, 0), true), "flyers stand over a chasm")

	var bridge := TerrainDef.new()
	bridge.name = "bridge"; bridge.stand = Standing.Everyone
	var wallish := TerrainDef.new()
	wallish.name = "glass"; wallish.stand = Standing.Nobody; wallish.blocks_projectiles = false; wallish.blocks_sight = false
	state.grid.set_terrain(Vector2i(2, 0), bridge)
	state.grid.set_terrain(Vector2i(3, 0), wallish)
	assert_eq(state.grid.tile(Vector2i(2, 0)), TileType.Ground)
	assert_true(state.grid.blocks_movement(Vector2i(3, 0)))
	assert_false(state.grid.blocks_projectiles(Vector2i(3, 0)), "a terrain nobody stands on may still let shots through")
	assert_true(state.grid.blocks_projectiles(Vector2i(4, 0)), "outside the map counts as wall")

func test_spawn_on_a_taken_tile_uses_the_nearest_free_tile_of_the_path() -> void:
	var s := _session()
	s.spawn_enemy(_slime(), 0, null, -1)
	s.spawn_enemy(_slime(), 0, null, -1)
	var slimes := s.enemies
	assert_seq(slimes.map(func(e): return e.position), [Vector2i(0, 1), Vector2i(1, 1)])
	assert_true(slimes.all(func(e): return e.path_id == 0))

func test_walk_preview_shows_the_reach_blocked_by_the_unit_ahead() -> void:
	var s := _session()
	s.spawn_enemy(_slime().stat("Speed", 3), 0, null, -1) # (0,1)
	s.spawn_enemy(_slime(), 0, null, -1)                  # (1,1): in the way
	var back := _enemy_at(s, Vector2i(0, 1))
	var walk: AbilityDef = back.abilities.filter(func(a): return a.name == "Walk")[0]

	assert_eq(AimPreview.range(s.state, back.id, walk).size(), 0)
	assert_seq(AimPreview.blocked(s.state, back.id, walk), [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)])

func test_enemy_cooldowns_drop_at_the_player_phase_with_the_towers() -> void:
	var s := _session()
	s.spawn_enemy(_slime(), 0, null, -1)
	var slime: Entity = s.enemies[0]
	var ram: AbilityDef = slime.abilities.filter(func(a): return a.name == "Ram")[0]
	slime.cooldowns[ram] = 3

	s.end_round() # its own turn start skips the drop; the next player phase drops it once
	assert_eq(s.phase, Phase.Player)
	assert_eq(slime.cooldowns[ram], 2)

# ------------------------------------------------------------------ actions and beats (presentation grouping)

func test_every_event_belongs_to_an_action() -> void:
	var s := _session([_archer_tower()])
	var archer := s.place("archer-1", Vector2i(2, 2))
	for guard in 30:
		if s.is_over: break
		var aims := Targeting.valid_aims(s.state, archer.id, archer.abilities[0])
		if aims.size() > 0 and s.can_cast(archer, archer.abilities[0]): s.cast(archer, archer.abilities[0], aims[0])
		if not s.is_over: s.end_round()
	assert_true(s.log.events.all(func(e): return e.action >= 0), "no event outside an action")
	var ordered := true
	for i in range(1, s.log.events.size()):
		if s.log.events[i - 1].action > s.log.events[i].action: ordered = false
	assert_true(ordered, "actions never interleave")

func test_end_round_splits_into_the_expected_actions() -> void:
	var s := _session([_archer_tower()])
	s.place("archer-1", Vector2i(2, 2))
	s.end_round()                       # round 1: no enemies yet; the first slime spawns
	var from := s.log.actions.size()
	s.end_round()                       # round 2: the slime walks; the second spawns

	var kinds := s.log.actions.slice(from).map(func(a): return a.kind)
	assert_seq(kinds, [
		ActionKind.TowersTurnEnd, ActionKind.Phase, ActionKind.EnemyTurn, ActionKind.Phase,
		ActionKind.Spawn, ActionKind.LevelEvent, ActionKind.Income, ActionKind.RoundEnd,
		ActionKind.Phase, ActionKind.TowersTurnStart])
	assert_eq(s.log.actions[from + 2].detail, "Slime")

func test_hits_of_one_batch_share_a_beat_and_deaths_come_after() -> void:
	var f := Fixture.new()
	var caster := f.unit("Caster", 0, 0, 0, 100)
	f.unit("A", 1, 4, 4, 10)
	f.unit("B", 1, 5, 4, 10)
	var blast := AbilityDef.new()
	blast.name = "Blast"
	blast.targeting = PatternDef.diamond("9")
	var atk := AttackStep.new()
	atk.area = PatternDef.diamond("1"); atk.power = Formula.new("10"); atk.can_miss = false; atk.can_crit = false
	var dmg := DamageStep.new(); dmg.amount = Formula.new("ActionPower")
	atk.on_hit = [dmg]
	blast.steps = [atk]

	f.resolver.cast(caster, blast, Aim.at(caster.pos, Vector2i(4, 4)))

	var hits := f.events(GameEventType.DamageDealt)
	var deaths := f.events(GameEventType.EntityDied)
	assert_eq(hits.size(), 2)
	if hits.size() != 2: return
	var hit_beats := {}
	for h in hits: hit_beats[h.beat] = true
	assert_eq(hit_beats.size(), 1, "the two hits play together")
	assert_true(deaths.all(func(d): return d.beat > hits[0].beat), "deaths play after the hits")
	var death_beats := {}
	for d in deaths: death_beats[d.beat] = true
	assert_eq(death_beats.size(), 1)
	assert_true(f.log.events.all(func(e): return e.action == 0), "a command run alone is one action")

# ------------------------------------------------------------------ facing

func test_spawns_face_along_their_path_or_a_set_direction() -> void:
	var s := _session()
	s.end_round() # round 1's level phase spawns the first slime on the path start
	var first: Entity = s.enemies[0]
	assert_eq(first.facing, Vector2i(1, 0), "the path goes +x")

	s.spawn_enemy(_slime(), 0, Vector2i(3, 1), 0, SpawnFacing.Up)
	var up := s.state.entity_at(Vector2i(3, 1))
	assert_eq(up.facing, Vector2i(0, 1))

static func _face(mode: int, dir := CardinalDirection.Down) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Face"
	var st := FaceStep.new()
	st.mode = mode
	st.direction = dir
	a.steps = [st]
	return a

func test_face_step_turns_in_a_set_direction_or_along_the_path() -> void:
	var rules := _rules()
	rules.facing_enabled = true
	var s := LevelSession.new(_level(), rules, [], 7)
	s.start()
	s.end_round()
	var slime: Entity = s.enemies[0]

	s.resolver.cast(slime, _face(FaceMode.Direction), Aim.at(slime.pos, slime.pos))
	assert_eq(slime.facing, Vector2i(0, -1), "Down is -y")

	s.resolver.cast(slime, _face(FaceMode.AlongPath), Aim.at(slime.pos, slime.pos))
	assert_eq(slime.facing, Vector2i(1, 0), "back along its path")
