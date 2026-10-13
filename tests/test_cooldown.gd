extends TestCase
## Port of CooldownTests.cs — cooldowns that start on, cooldowns held until a reset (e.g. on a kill), and bases that cast like towers.

static func mk(obj, props: Dictionary = {}):
	return preload("res://tests/test_combat.gd").mk(obj, props)

static func strike(name: String = "Strike", power: int = 10) -> AbilityDef:
	return mk(AbilityDef.new(), {name = name, tags = [Tags.Attack], targeting = PatternDef.diamond("3"), target_filter = "Target.IsEnemy",
		steps = [mk(AttackStep.new(), {power = str(power), can_miss = false, can_crit = false, on_hit = [DamageStep.new()]})]})

static func create(f: Fixture, name: String, team: int, x: int, y: int, hp: int, abilities: Array) -> Entity:
	var def: EntityDef = mk(EntityDef.new(), {name = name, kind = EntityKind.Unit}).stat("MaxHp", hp)
	def.abilities.append_array(abilities)
	return f.state.create(def, team, Vector2i(x, y))

func test_abilities_can_start_on_cooldown_or_locked() -> void:
	var f := Fixture.new()
	var warm_up := strike("Warm-up"); warm_up.start_cooldown = 2
	var locked := strike("Locked"); locked.start_cooldown = -1
	var u := create(f, "U", 0, 0, 0, 100, [warm_up, locked, strike()])

	assert_eq(u.cooldown(warm_up), 2)
	assert_true(u.cooldown_held(locked))
	var reason := []
	assert_false(Targeting.can_cast(f.state, u.id, locked, reason))
	assert_eq(reason[0] if reason.size() > 0 else null, "On cooldown until reset")
	assert_eq(u.cooldown(u.abilities[2]), 0)

	f.resolver.start_turn(u)
	assert_eq(u.cooldown(warm_up), 1)
	assert_true(u.cooldown_held(locked), "held cooldowns do not count down")

func test_a_held_cooldown_waits_for_a_kill() -> void:
	var f := Fixture.new()
	var execute := strike("Execute", 30)
	execute.cooldown_until_reset = true
	var u := create(f, "U", 0, 0, 0, 100, [execute])
	u.grant(mk(ReactionDef.new(), {name = "Bloodthirst", trigger = Trigger.OnKill, response = [mk(ResetCooldownStep.new(), {ability = execute})]}))
	var tough: Entity = f.unit("Tough", 1, 1, 0, 100)
	var weak: Entity = f.unit("Weak", 1, 2, 0, 20)

	f.resolver.cast(u, execute, Aim.at(u.pos, tough.pos))
	assert_true(u.cooldown_held(execute), "no kill: still waiting")
	f.resolver.start_turn(u)
	assert_true(u.cooldown_held(execute))

	f.resolver.cast(u, strike("Finish", 30), Aim.at(u.pos, weak.pos)) # another ability's kill frees it too
	assert_false(weak.alive)
	assert_eq(u.cooldown(execute), 0, f.dump())
	assert_eq(f.events(GameEventType.CooldownChanged).size(), 1)
	assert_true(Targeting.can_cast(f.state, u.id, execute))

func test_a_reset_with_turns_shortens_but_leaves_held_ones() -> void:
	var f := Fixture.new()
	var slow := strike("Slow"); slow.cooldown = 3
	var held := strike("Held"); held.cooldown_until_reset = true
	var u := create(f, "U", 0, 0, 0, 100, [slow, held])
	var e: Entity = f.unit("E", 1, 1, 0, 500)
	f.resolver.cast(u, slow, Aim.at(u.pos, e.pos))
	f.resolver.cast(u, held, Aim.at(u.pos, e.pos))

	var hasten: AbilityDef = mk(AbilityDef.new(), {name = "Hasten", steps = [mk(ResetCooldownStep.new(), {turns = "2"})]})
	f.resolver.cast(u, hasten, Aim.at(u.pos, u.pos))
	assert_eq(u.cooldown(slow), 1)
	assert_true(u.cooldown_held(held))

	var refresh: AbilityDef = mk(AbilityDef.new(), {name = "Refresh", steps = [ResetCooldownStep.new()]})
	f.resolver.cast(u, refresh, Aim.at(u.pos, u.pos))
	assert_eq(u.cooldown(slow), 0)
	assert_eq(u.cooldown(held), 0)

static func _path_row() -> Array:
	var tiles := []
	for x in 6: tiles.append(Vector2i(x, 1))
	return tiles

func test_bases_cast_and_take_turns_like_towers() -> void:
	var zap := strike("Zap")
	zap.cooldown = 2
	var base_def: EntityDef = mk(EntityDef.new(), {name = "Base", kind = EntityKind.Object_, tags = [Tags.Base]}).stat("MaxHp", 10)
	base_def.abilities.append(zap)
	var slime: EntityDef = mk(EntityDef.new(), {name = "Slime", footing = Footing.OnPath}).stat("MaxHp", 50).stat("Speed", 0)
	var level: LevelDef = mk(LevelDef.new(), {name = "Test", width = 7, height = 3, start_energy = 5, energy_per_round = 1, hand_cap = 4,
		paths = [_path_row()], bases = [mk(BaseDef.new(), {tile = Vector2i(6, 1), entity = base_def})]})
	var wave: WaveDef = mk(WaveDef.new(), {name = "W", start_round = 1})
	wave.spawns.append(mk(SpawnEntry.new(), {round = 9, enemy = slime})) # keeps the level going
	level.waves.append(wave)

	var s := LevelSession.new(level, GameRules.new(CombatVocabulary.create()), [], 7)
	s.start()
	var b: Entity = s.state.get_entity(s.bases[0])
	var enemy: Entity = s.state.create(slime, Teams.Enemy, Vector2i(4, 1)) # within Zap's range

	assert_true(s.can_cast(b, zap), s.last_reason)
	assert_contains(s.player_units, b)
	assert_true(s.anything_to_do(), "Zap is ready")
	s.cast(b, zap, Aim.at(b.pos, enemy.pos))
	assert_false(s.anything_to_do(), "Zap is on cooldown and the hand is empty: only End turn is left")
	assert_eq(enemy.hp, 40)
	assert_eq(b.cooldown(zap), 2)

	s.end_round()
	assert_eq(b.cooldown(zap), 1, "the base's turn started with the towers': its cooldown dropped")

func test_a_wave_spawn_gets_its_shield_from_an_on_spawned_passive() -> void:
	var shield: StatusDef = mk(StatusDef.new(), {name = "Slime Shield", tags = [Tags.Buff], duration = -1, shield_pool = "10"})
	var shielded: PassiveDef = mk(PassiveDef.new(), {name = "Shielded"})
	shielded.reactions.append(mk(ReactionDef.new(), {name = "Shield Up", trigger = Trigger.OnSpawned,
		response = [mk(ApplyStatusStep.new(), {status = shield, on = StepTarget.Self})]}))
	var shield_slime: EntityDef = mk(EntityDef.new(), {name = "Shield Slime", footing = Footing.OnPath}).stat("MaxHp", 10).stat("Speed", 0)
	shield_slime.passives.append(shielded)

	var level: LevelDef = mk(LevelDef.new(), {name = "Test", width = 7, height = 3, start_energy = 5, energy_per_round = 1, hand_cap = 4,
		paths = [_path_row()],
		bases = [mk(BaseDef.new(), {tile = Vector2i(6, 1), entity = mk(EntityDef.new(), {name = "Base", kind = EntityKind.Object_, tags = [Tags.Base]}).stat("MaxHp", 10)})]})
	var wave: WaveDef = mk(WaveDef.new(), {name = "W", start_round = 1})
	wave.spawns.append(mk(SpawnEntry.new(), {round = 1, enemy = shield_slime}))
	wave.spawns.append(mk(SpawnEntry.new(), {round = 9, enemy = shield_slime})) # keeps the level going
	level.waves.append(wave)

	var s := LevelSession.new(level, GameRules.new(CombatVocabulary.create()), [], 7)
	s.start()
	s.end_round() # round 1's level phase spawns it
	var enemies: Array = s.enemies
	assert_eq(enemies.size(), 1, s.log.dump(s.state))
	if enemies.size() == 1: assert_eq(enemies[0].shield, 10, s.log.dump(s.state))

func test_a_damage_spell_can_delay_the_casters_other_abilities_and_hit_bosses_harder() -> void:
	var f := Fixture.new()
	var mend := strike("Mend"); mend.cooldown = 1
	var walk := strike("Walk")
	var smite: AbilityDef = mk(AbilityDef.new(), {name = "Smite", targeting = PatternDef.diamond("3"), target_filter = "Target.IsEnemy", cooldown = 1,
		steps = [
			mk(AttackStep.new(), {power = "5", can_miss = false, can_crit = false,
				on_hit = [mk(DamageStep.new(), {amount = "if(Target.HasTag(Boss), ActionPower * 3, ActionPower)"})]}),
			AddCooldownStep.new()]})
	var priest := create(f, "Priest", 0, 0, 0, 100, [mend, smite, walk])
	var slime: Entity = f.unit("Slime", 1, 1, 0, 100)
	var king_def: EntityDef = mk(EntityDef.new(), {name = "King", kind = EntityKind.Unit, tags = [Tags.Boss]}).stat("MaxHp", 100)
	var king: Entity = f.state.create(king_def, 1, Vector2i(2, 0))

	f.resolver.cast(priest, smite, Aim.at(priest.pos, slime.pos))
	assert_eq(slime.hp, 95)
	assert_eq(priest.cooldown(mend), 1, "the others wait one turn")
	assert_eq(priest.cooldown(walk), 1)
	assert_eq(priest.cooldown(smite), 1, "its own cooldown only, not one more")

	f.resolver.start_turn(priest)
	f.resolver.cast(priest, smite, Aim.at(priest.pos, king.pos))
	assert_eq(king.hp, 85, "15 against a boss")
	assert_eq(f.events(GameEventType.CooldownChanged).filter(func(e): return e.target == priest.id).size(), 2, "one change per cast")
