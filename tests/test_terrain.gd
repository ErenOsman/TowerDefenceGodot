extends TestCase
## Port of TerrainTests.cs: changing tiles during a battle (Tiles — Design, step 3): the Change Terrain step,
## falling, pushing, queries, the trigger.

static var Bridge: TerrainDef = _bridge()

static func _bridge() -> TerrainDef:
	var t := TerrainDef.new()
	t.name = "bridge"
	t.stand = Standing.Everyone
	t.tags = ["Solid"]
	return t

static func change(to: TerrainDef, area: PatternDef = null, build: int = BuildChange.Keep, only_on: Array = []) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Change to " + to.name
	a.targeting = PatternDef.diamond("9")
	var step := ChangeTerrainStep.new()
	step.terrain = to
	step.area = area if area != null else PatternDef.single()
	step.only_on = only_on
	step.build = build
	a.steps = [step]
	return a

func test_filling_a_chasm_changes_only_the_chasm_tiles_and_lets_walkers_stand() -> void:
	var f := Fixture.new(6, 3)
	for x in range(1, 4): f.state.grid.set_terrain(Vector2i(x, 1), TerrainDef.Chasm)
	var mage := f.unit("Mage", 0, 0, 0, 10)

	f.resolver.cast(mage, change(TerrainDef.Ground, PatternDef.diamond("1"), BuildChange.On, ["chasm"]), Aim.at(mage.pos, Vector2i(2, 1)))

	assert_true(f.state.grid.terrain_at(Vector2i(1, 1)) == TerrainDef.Ground)
	assert_true(f.state.grid.terrain_at(Vector2i(3, 1)) == TerrainDef.Ground)
	assert_true(f.state.grid.can_stand_on(Vector2i(2, 1), false))
	var changed := f.events(GameEventType.TileChanged)
	assert_eq(changed.size(), 3, "only the three chasm tiles of the diamond (ground tiles are left alone)")
	if changed.size() > 0: assert_eq(changed[0].detail, "chasm>ground")
	assert_true(f.state.grid.buildable.has(Vector2i(2, 1)), "build switched on where it changed")
	assert_false(f.state.grid.buildable.has(Vector2i(2, 2)), "not on the ground tiles it skipped")

func test_a_walker_on_a_tile_that_becomes_a_chasm_falls_and_a_flyer_stays() -> void:
	var f := Fixture.new(5, 3)
	var mage := f.unit("Mage", 0, 0, 0, 10)
	var slime := f.unit("Slime", 1, 2, 1, 20)
	var bat := f.unit("Bat", 1, 3, 1, 20)
	bat.def.tags = [Tags.Flying]

	f.resolver.cast(mage, change(TerrainDef.Chasm), Aim.at(mage.pos, Vector2i(2, 1)))
	f.resolver.cast(mage, change(TerrainDef.Chasm), Aim.at(mage.pos, Vector2i(3, 1)))

	assert_eq(slime.life, LifeState.Dead, f.dump())
	var died_list := f.events(GameEventType.EntityDied)
	assert_eq(died_list.size(), 1)
	if died_list.size() == 1:
		var died: GameEvent = died_list[0]
		assert_eq(died.target, slime.id)
		assert_true(died.tags.has(Tags.Fell))
		assert_eq(died.source, mage.id, "the caster made it fall (OnKill counts)")
	assert_true(bat.alive, "flyers stay over a chasm")

func test_a_flyer_spawns_on_a_path_over_a_chasm_and_a_walker_does_not() -> void:
	# The Drummer's bats: their path runs along the chasm, so only a flyer can appear on it
	var f := Fixture.new(5, 3)
	for x in 5: f.state.grid.set_terrain(Vector2i(x, 0), TerrainDef.Chasm)
	var tiles := []
	for x in 5: tiles.append(Vector2i(x, 0))
	f.state.grid.add_path(tiles)
	var bat := EntityDef.new()
	bat.name = "Bat"
	bat.footing = Footing.OnPath
	bat.tags = [Tags.Flying]
	bat.stat("MaxHp", 10)
	var slime := EntityDef.new()
	slime.name = "Slime"
	slime.footing = Footing.OnPath
	slime.stat("MaxHp", 10)

	for def in [bat, slime]:
		var e := SpawnEffect.new()
		e.def = def
		e.tile = Vector2i(0, 0)
		e.team = 1
		e.path_id = 0
		e.owner = 0
		e.source = 0
		f.resolver.run(e)

	var spawned_list := f.events(GameEventType.EntitySpawned)
	assert_eq(spawned_list.size(), 1, f.dump())
	if spawned_list.size() == 1:
		assert_eq(spawned_list[0].detail, "Bat", f.dump())
		assert_eq(spawned_list[0].to, Vector2i(0, 0))
	var any_fizzle := false
	for e in f.events(GameEventType.Fizzled):
		if e.detail != null and e.detail.contains("Slime"): any_fizzle = true
	assert_true(any_fizzle, "a walker finds no tile it can stand on")

func test_a_unit_caught_in_a_new_wall_is_pushed_to_the_nearest_free_tile_or_dies() -> void:
	var f := Fixture.new(3, 1)
	var mage := f.unit("Mage", 0, 0, 0, 10)
	var slime := f.unit("Slime", 1, 1, 0, 20)

	f.resolver.cast(mage, change(TerrainDef.Wall), Aim.at(mage.pos, Vector2i(1, 0)))
	assert_eq(slime.position, Vector2i(2, 0), "pushed (the wall pushes): the nearest tile it can enter")
	assert_true(slime.alive)
	var moved := f.events(GameEventType.EntityMoved)
	assert_true(moved.size() > 0 and moved[moved.size() - 1].detail == "Pushed")

	f.resolver.cast(mage, change(TerrainDef.Wall), Aim.at(mage.pos, Vector2i(2, 0)))
	assert_eq(slime.life, LifeState.Dead, "no free tile left: it dies")

func test_terrain_queries_and_the_tile_changed_trigger() -> void:
	var f := Fixture.new(5, 3)
	var mage := f.unit("Mage", 0, 0, 0, 10)
	var guard := f.unit("Guard", 0, 4, 2, 10)
	var keen := StatusDef.new()
	keen.name = "Keen"
	var r := ReactionDef.new()
	r.name = "Watch the bridge"
	r.trigger = Trigger.OnTileChanged
	r.condition = Condition.new("X == 2 and Y == 1")
	var apply := ApplyStatusStep.new()
	apply.status = keen
	apply.on = StepTarget.Self
	r.response = [apply]
	guard.grant(r)

	f.resolver.cast(mage, change(Bridge), Aim.at(mage.pos, Vector2i(1, 1)))
	assert_false(guard.has_status("Keen"), "another tile")
	f.resolver.cast(mage, change(Bridge), Aim.at(mage.pos, Vector2i(2, 1)))
	assert_true(guard.has_status("Keen"), "the condition reads the tile's X and Y")

	f.resolver.cast(mage, change(Bridge), Aim.at(mage.pos, Vector2i(0, 0)))
	var ctx := EvalContext.new()
	ctx.self_ = mage
	ctx.rng = f.state.rng
	assert_true(Condition.new("Self.OnTerrain(bridge)").evaluate(f.state.vocab, ctx))
	assert_true(Condition.new("Self.OnTerrainTag(Solid)").evaluate(f.state.vocab, ctx))
	assert_false(Condition.new("Self.OnTerrain(chasm)").evaluate(f.state.vocab, ctx))
