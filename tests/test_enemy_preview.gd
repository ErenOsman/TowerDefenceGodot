extends TestCase
## The enemy card's ability-row preview (EnemyAbilityPreview): only the hovered ability of the enemy's coming turn,
## a walk never shows numbers, the hit is seen from where the walk leaves it.

const LevelTests := preload("res://tests/test_level.gd")

static func _enemy_at(s: LevelSession, p: Vector2i) -> Entity:
	for e in s.enemies:
		if e.pos == p: return e
	return null

## A slime one tile from the base: its turn is walk (to 5,1) then Ram the base.
static func _slime_before_ram(s: LevelSession) -> Entity:
	for guard in 30:
		if _enemy_at(s, Vector2i(4, 1)) != null: break
		s.end_round()
	return _enemy_at(s, Vector2i(4, 1))

func test_hovering_the_walk_shows_its_route_but_no_damage() -> void:
	var s := LevelTests._session()
	var slime := _slime_before_ram(s)
	if slime == null:
		fail("no slime reached (4, 1)")
		return
	var turn := TurnForecast.of(s.state, slime.id)
	assert_eq(turn.size(), 2, "walk, then ram")
	if turn.size() != 2: return
	var walk: AbilityDef = turn[0].ability
	var ram: AbilityDef = turn[1].ability

	var w := EnemyAbilityPreview.only(s.state, slime.id, walk)
	assert_eq(w.steps.get(slime.id, []).size(), 1, "only the walk step")
	assert_true(w.steps[slime.id][0].is_movement)
	assert_eq(w.steps[slime.id][0].aim.tile, Vector2i(5, 1), "the stop tile")
	assert_true(w.loss.is_empty(), "no damage number while the walk is hovered")
	assert_true(w.hp.is_empty())
	assert_true(w.killed.is_empty())

	var r := EnemyAbilityPreview.only(s.state, slime.id, ram)
	assert_eq(r.steps.get(slime.id, []).size(), 1, "only the ram step")
	assert_eq(r.steps[slime.id][0].ability, ram)
	assert_eq(r.loss.get(s.bases[0]), 5, "the ram's own damage, from where the walk left it")
	assert_eq(slime.pos, Vector2i(4, 1), "the real state is untouched")

	assert_eq(EnemyAbilityPreview.cast_from(slime.pos, turn, ram), Vector2i(5, 1), "the hit starts after the walk")
	assert_eq(EnemyAbilityPreview.cast_from(slime.pos, turn, walk), Vector2i(4, 1))

func test_an_ability_not_cast_this_turn_previews_nothing() -> void:
	var s := LevelTests._session()
	var slime := _slime_before_ram(s)
	if slime == null:
		fail("no slime reached (4, 1)")
		return
	var other := AbilityDef.new()
	other.name = "Unused"
	var p := EnemyAbilityPreview.only(s.state, slime.id, other)
	assert_true(p.steps.is_empty())
	assert_true(p.loss.is_empty())
