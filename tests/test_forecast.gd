extends TestCase
## Port of ForecastTests.cs: the enemy phase played ahead (TurnForecast.phase): casts, losses and kills, the real state untouched.

static func _strike(power: int) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Strike"
	a.tags = [Tags.Attack]
	a.targeting = PatternDef.diamond("3")
	a.target_filter = Condition.new("Target.IsEnemy")
	var atk := AttackStep.new()
	atk.power = Formula.new(str(power))
	atk.can_miss = false
	atk.can_crit = false
	atk.on_hit = [DamageStep.new()]
	a.steps = [atk]
	return a

static func _create(f: Fixture, p_name: String, team: int, x: int, hp: int, abilities: Array = []) -> Entity:
	var def := EntityDef.new()
	def.name = p_name
	def.kind = EntityKind.Unit
	def.stat("MaxHp", hp)
	def.abilities.append_array(abilities)
	return f.state.create(def, team, Vector2i(x, 0))

func test_the_enemy_phase_forecast_lists_casts_and_losses() -> void:
	var f := Fixture.new()
	var tower := _create(f, "Tower", Teams.Player, 0, 30)
	var a := _create(f, "A", Teams.Enemy, 2, 50, [_strike(8)])
	var b := _create(f, "B", Teams.Enemy, 3, 50, [_strike(8)])

	var forecast := TurnForecast.phase(f.state, [a.id, b.id])

	assert_eq(forecast.steps[a.id].size(), 1, "A strikes once")
	assert_eq(forecast.steps[b.id].size(), 1, "B strikes once")
	assert_eq(forecast.loss.get(tower.id), 16, "both strikes land")
	assert_false(forecast.killed.has(tower.id))
	assert_eq(tower.hp, 30, "the real state is untouched")

func test_the_enemy_phase_forecast_knows_who_would_die() -> void:
	var f := Fixture.new()
	var tower := _create(f, "Tower", Teams.Player, 0, 10)
	var a := _create(f, "A", Teams.Enemy, 2, 50, [_strike(8)])
	var b := _create(f, "B", Teams.Enemy, 3, 50, [_strike(8)])

	var forecast := TurnForecast.phase(f.state, [a.id, b.id])

	assert_contains(forecast.killed.keys(), tower.id)
	assert_eq(forecast.loss.get(tower.id), 10, "it can lose only what it has")
	assert_true(tower.alive)

func test_one_cast_played_ahead_gives_loss_hp_and_kills() -> void:
	var f := Fixture.new()
	var strike := _strike(8)
	var tower := _create(f, "Tower", Teams.Player, 0, 30, [strike])
	var enemy := _create(f, "Enemy", Teams.Enemy, 2, 20)
	var weak := _create(f, "Weak", Teams.Enemy, 1, 5)

	var hit := TurnForecast.cast(f.state, tower.id, strike, Aim.at(tower.pos, enemy.pos))
	var kill := TurnForecast.cast(f.state, tower.id, strike, Aim.at(tower.pos, weak.pos))

	assert_eq(hit.loss.get(enemy.id), 8)
	assert_eq(hit.hp.get(enemy.id), 12, "the HP it would leave")
	assert_false(hit.hp.has(tower.id), "only those whose HP changes")
	assert_contains(kill.killed.keys(), weak.id)
	assert_eq(kill.hp.get(weak.id), 0, "the dead have 0")
	assert_eq([enemy.hp, weak.hp], [20, 5], "the real state is untouched")

func test_previews_calculate_instead_of_rolling() -> void:
	var f := Fixture.new(10, 10, 5)
	f.rules.hit_chance = Formula.new("0.5")
	f.rules.crit_chance = Formula.new("0.5")
	var gamble := AbilityDef.new()
	gamble.name = "Gamble"
	gamble.tags = [Tags.Attack]
	gamble.targeting = PatternDef.diamond("3")
	gamble.target_filter = Condition.new("Target.IsEnemy")
	var atk := AttackStep.new()
	atk.power = Formula.new("rand(6, 10)")
	atk.on_hit = [DamageStep.new()]
	gamble.steps = [atk]
	var tower := _create(f, "Tower", Teams.Player, 0, 30, [gamble])
	var enemy := _create(f, "Enemy", Teams.Enemy, 2, 50)

	for i in 5:
		assert_eq(TurnForecast.cast(f.state, tower.id, gamble, Aim.at(tower.pos, enemy.pos)).loss.get(enemy.id), 6,
			"an uncertain hit lands, an uncertain crit does not, rand() gives its lowest: the same number every time")
