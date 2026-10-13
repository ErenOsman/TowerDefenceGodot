extends TestCase
## Port of InstinctTests.cs. Instinct — Design: how an ability chooses its own aim (defaults, presets, Must, custom, Random, bounce).

static func _attack(power := "10") -> AttackStep:
	var atk := AttackStep.new()
	atk.power = Formula.new(power)
	atk.can_miss = false
	atk.can_crit = false
	atk.on_hit = [DamageStep.new()]
	return atk

static func _shot(instinct: InstinctDef = null, filter := "Target.IsEnemy", range_ := "6") -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Shot"
	a.targeting = PatternDef.diamond(range_)
	a.target_filter = Condition.new(filter)
	a.instinct = instinct if instinct != null else InstinctDef.new()
	a.steps = [_attack()]
	return a

static func _walk_ability(p_name: String, targeting: PatternDef) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = p_name
	a.tags = [Tags.Movement]
	a.targeting = targeting
	a.steps = [WalkStep.new()]
	return a

static func _target(f: Fixture, a: AbilityDef, caster: Entity) -> Entity:
	var aim := Instinct.choose(f.state, caster, a)
	if aim == null: return null
	return Instinct.target_of(f.state, a, aim)

static func _status(def: StatusDef, applied_by: int) -> StatusInstance:
	var st := StatusInstance.new()
	st.def = def
	st.stacks = 1
	st.turns_left = -1
	st.applied_by = applied_by
	return st

static func _ctx(self_e: Entity, source: Entity, target: Entity, rng: IRng) -> EvalContext:
	var ctx := EvalContext.new()
	ctx.self_ = self_e; ctx.source = source; ctx.target = target; ctx.rng = rng
	return ctx

func test_default_takes_the_nearest_enemy_ties_by_id() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 5, 5, 100)
	var far := f.unit("Far", 1, 5, 9, 100)
	var tie_b := f.unit("TieB", 1, 7, 5, 100)
	var tie_a := f.unit("TieA", 1, 5, 3, 100) # same distance as TieB, higher id
	f.unit("Friend", 0, 5, 6, 100)

	assert_eq(Instinct.default(f.state, me, _shot(), Targeting.valid_aims(f.state, me.id, _shot())), InstinctPreset.Nearest)
	assert_true(_target(f, _shot(), me) == tie_b, "nearest, then the lower EntityId")
	assert_true(_target(f, _shot(), me) != far)
	assert_true(tie_a.id > tie_b.id)

func test_presets_pick_by_hp_and_distance() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100)
	var near := f.unit("Near", 1, 1, 0, 100)
	var weak := f.unit("Weak", 1, 2, 0, 100)
	var big := f.unit("Big", 1, 3, 0, 300)
	var hurt := f.unit("Hurt", 1, 4, 0, 300)
	weak.hp = 30
	hurt.hp = 60 # 20%, lower than Weak's 30%
	big.hp = 250

	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Nearest)), me) == near)
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Farthest)), me) == hurt)
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Weakest)), me) == weak)
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Strongest)), me) == big, "max HP 300, ties by id: Big before Hurt")
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.MostHurt)), me) == hurt)

func test_first_and_last_follow_path_progress() -> void:
	var f := Fixture.new()
	f.state.grid.add_path(Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5))
	var tower := f.unit("Tower", 0, 2, 3, 100)
	var back := f.unit("Back", 1, 1, 5, 100); back.path_id = 0
	var front := f.unit("Front", 1, 4, 5, 100); front.path_id = 0
	f.unit("OffPath", 1, 2, 4, 100) # nearest, but on no path: last for both

	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.First)), tower) == front)
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Last)), tower) == back)

func test_must_drops_candidates_and_can_leave_none() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100)
	f.unit("Near", 1, 1, 0, 100)
	var hurt := f.unit("Hurt", 1, 3, 0, 100)
	hurt.hp = 40

	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Nearest, "Target.Hp < Target.MaxHp")), me) == hurt)
	assert_null(Instinct.choose(f.state, me, _shot(InstinctDef.of(InstinctPreset.Nearest, "Target.Hp > 1000"))))

func test_custom_preferences_sort_in_order() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100)
	var a := f.unit("A", 1, 1, 0, 200)
	var b := f.unit("B", 1, 2, 0, 200)
	f.unit("C", 1, 3, 0, 100)
	a.hp = 150

	# highest max HP (A and B tie), then lowest HP: A
	var custom := InstinctDef.custom(Preference.highest_of("Target.MaxHp"), Preference.lowest_of("Target.Hp"))
	assert_true(_target(f, _shot(custom), me) == a)
	assert_true(_target(f, _shot(custom), me) != b)

static func _pick(seed: int) -> Entity:
	var f := Fixture.new(10, 10, seed)
	var me := f.unit("Me", 0, 0, 0, 100)
	for i in range(1, 6): f.unit("E%d" % i, 1, i, 0, 100)
	return _target(f, _shot(InstinctDef.of(InstinctPreset.Random)), me)

func test_random_is_seeded() -> void:
	assert_eq(_pick(7).name, _pick(7).name, "same seed, same choice")
	var names := {}
	for s in range(1, 21): names[_pick(s).name] = true
	assert_true(names.size() > 1, "different seeds reach different targets")

func test_allies_only_default_to_the_most_hurt() -> void:
	var f := Fixture.new()
	var healer := f.unit("Healer", 0, 0, 0, 100)
	f.unit("Near", 0, 1, 0, 100)
	var hurt := f.unit("Hurt", 0, 3, 0, 100)
	hurt.hp = 10
	var mend := _shot(null, "Target.IsAlly")

	assert_eq(Instinct.effective(f.state, healer, mend, Targeting.valid_aims(f.state, healer.id, mend)), InstinctPreset.MostHurt)
	assert_true(_target(f, mend, healer) == hurt)

func test_movement_goes_farthest_and_no_filter_takes_the_first_aim() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 5, 5, 100, [["Speed", 3]])
	var walk := _walk_ability("Walk", PatternDef.steps("Self.Speed"))
	var aim := Instinct.choose(f.state, me, walk)
	assert_eq(aim.path.size(), 3)

	var blast := AbilityDef.new()
	blast.name = "Ground"
	blast.targeting = PatternDef.diamond("2")
	assert_eq(Instinct.choose(f.state, me, blast).tile, Targeting.valid_aims(f.state, me.id, blast)[0].tile)

static func _chain(bounce: InstinctDef) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Chain"
	a.targeting = PatternDef.diamond("20")
	var atk := _attack()
	atk.bounces = Formula.new("1")
	atk.bounce_area = PatternDef.diamond("3")
	atk.bounce_filter = Condition.new("Target.IsEnemy")
	atk.bounce_instinct = bounce
	a.steps = [atk]
	return a

func test_bounce_instinct_overrides_the_nearest() -> void:
	var f := Fixture.new()
	var mage := f.unit("Mage", 0, 0, 0, 100)
	var t1 := f.unit("T1", 1, 4, 4, 500)
	var near := f.unit("Near", 1, 4, 5, 500)
	var weak := f.unit("Weak", 1, 5, 6, 500)
	weak.hp = 100

	f.resolver.cast(mage, _chain(InstinctDef.new()), Aim.at(mage.pos, t1.pos))
	assert_eq(f.events(GameEventType.DamageDealt).back().target, near.id, "default: the nearest to the last target")

	f.resolver.cast(mage, _chain(InstinctDef.of(InstinctPreset.Weakest)), Aim.at(mage.pos, t1.pos))
	assert_eq(f.events(GameEventType.DamageDealt).back().target, weak.id, f.dump())

static func _blast(instinct: InstinctDef) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Blast"
	a.targeting = PatternDef.diamond("8")
	a.instinct = instinct if instinct != null else InstinctDef.new()
	var atk := _attack()
	atk.area = PatternDef.diamond("1")
	atk.area_filter = Condition.new("Target.IsEnemy")
	a.steps = [atk]
	return a

func test_taunted_prefers_its_applier_and_falls_back() -> void:
	var f := Fixture.new()
	var enemy := f.unit("Enemy", 1, 0, 0, 100)
	var near := f.unit("Near", 0, 1, 0, 100)
	var lure := f.unit("Lure", 0, 4, 0, 100)
	var taunt := StatusDef.new()
	taunt.name = "Taunt"
	taunt.tags = [Tags.Taunted]
	taunt.duration = -1
	enemy.statuses.append(_status(taunt, lure.id))

	assert_eq(Instinct.taunted_by(f.state, enemy), lure.id)
	assert_true(_target(f, _shot(), enemy) == lure, "taunted: goes for the applier although Near is nearer")
	assert_true(_target(f, _shot(null, "Target.IsEnemy", "2"), enemy) == near, "the applier is out of range: the normal instinct")
	assert_true(Targeting.valid_aims(f.state, enemy.id, _shot()).size() > 1, "unlike Redirected, every aim stays valid for hand aiming")

func test_area_preferences_count_and_sum_what_the_aim_hits() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100)
	f.unit("Lone", 1, 2, 0, 400)                 # alone: one unit, 400 HP
	f.unit("PairA", 1, 6, 0, 100)                # a pair: two units, 200 HP
	f.unit("PairB", 1, 6, 1, 100)

	var most := Instinct.choose(f.state, me, _blast(InstinctDef.custom(Preference.most_in_area("Target.IsEnemy"))))
	assert_eq(Targeting.area_targets(f.state, me.id, _blast(null).steps[0], most, {}).size(), 2)

	var heavy := Instinct.choose(f.state, me, _blast(InstinctDef.custom(Preference.highest_sum("Target.Hp"))))
	var hit := Targeting.area_targets(f.state, me.id, _blast(null).steps[0], heavy, {})
	var sum := 0
	for id in hit: sum += f.state.get_entity(id).hp
	assert_eq(sum, 400, "the lone 400 HP unit outweighs the pair")

	assert_eq(Instinct.default(f.state, me, _blast(null), Targeting.valid_aims(f.state, me.id, _blast(null))), InstinctPreset.MostHit)

func test_path_progress_and_damaged_this_round_queries() -> void:
	var f := Fixture.new()
	f.state.grid.add_path(Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5))
	var tower := f.unit("Tower", 0, 1, 3, 100)
	var walker := f.unit("Walker", 1, 2, 5, 100); walker.path_id = 0
	var hit := f.unit("Hit", 1, 1, 4, 100)
	var fresh := f.unit("Fresh", 1, 2, 4, 100)

	var ctx := _ctx(tower, tower, walker, f.state.rng.clone())
	assert_num(Formula.new("Target.PathProgress").evaluate(f.vocab, ctx), Fixture.N(2))
	ctx.target = hit
	assert_num(Formula.new("Target.PathProgress").evaluate(f.vocab, ctx), Fixture.N(-1), "off a path")

	f.resolver.cast(tower, _shot(), Aim.at(tower.pos, hit.pos))
	assert_true(Condition.new("Target.DamagedThisRound").evaluate(f.vocab, ctx))
	ctx.target = fresh
	assert_false(Condition.new("Target.DamagedThisRound").evaluate(f.vocab, ctx))

	# focus fire: prefer what was already hurt this round, then the nearest
	var focus := InstinctDef.custom(Preference.highest_of("Target.DamagedThisRound"), Preference.lowest_of("Self.DistanceTo(Target)"))
	assert_true(_target(f, _shot(focus), tower) == hit)
	f.state.round += 1
	assert_false(Condition.new("Target.DamagedThisRound").evaluate(f.vocab, _ctx(tower, null, hit, f.state.rng.clone())), "a new round")

func test_quick_cast_takes_the_only_aim_else_the_instinct() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100, [["Speed", 2]])
	var reason := []
	assert_null(Instinct.quick_cast(f.state, me, _shot(), reason))
	assert_eq(reason[0], "No target")

	var only := f.unit("Only", 1, 4, 0, 100)
	assert_eq(Instinct.quick_cast(f.state, me, _shot(InstinctDef.of(InstinctPreset.Nearest, "Target.Hp > 1000"))).tile, only.pos,
		"one valid aim: taken whatever the instinct says")

	var near := f.unit("Near", 1, 1, 0, 100)
	assert_eq(Instinct.quick_cast(f.state, me, _shot()).tile, near.pos, "several: the instinct (Nearest)")
	assert_null(Instinct.quick_cast(f.state, me, _shot(InstinctDef.of(InstinctPreset.Nearest, "Target.Hp > 1000")), reason))
	assert_eq(reason[0], "No target")

	var walk := _walk_ability("Walk", PatternDef.steps("Self.Speed"))
	assert_null(Instinct.quick_cast(f.state, me, walk, reason))
	assert_eq(reason[0], "No target: aim it yourself")

	var before := f.state.rng.clone().next_uint()
	var first := Instinct.quick_cast(f.state, me, _shot(InstinctDef.of(InstinctPreset.Random)))
	assert_eq(Instinct.quick_cast(f.state, me, _shot(InstinctDef.of(InstinctPreset.Random))).tile, first.tile, "a preview and the cast agree")
	assert_eq(f.state.rng.clone().next_uint(), before, "the state's RNG is not consumed")

static func _volley(instinct: InstinctDef, count: String) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Volley"
	var pick := PickStep.new()
	pick.area = PatternDef.diamond("3")
	pick.filter = Condition.new("Target.IsEnemy")
	pick.count = Formula.new(count)
	pick.instinct = instinct
	var dmg := DamageStep.new()
	dmg.amount = Formula.new("5")
	pick.steps = [dmg]
	a.steps = [pick]
	return a

func test_pick_runs_its_steps_on_the_chosen_units() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100)
	var a := f.unit("A", 1, 1, 0, 100)
	var b := f.unit("B", 1, 0, 2, 100)
	var c := f.unit("C", 1, 3, 0, 100)
	var far := f.unit("Far", 1, 9, 9, 100)
	f.unit("Friend", 0, 0, 1, 100)
	c.hp = 20

	f.resolver.cast(me, _volley(InstinctDef.new(), "2"), Aim.at(me.pos, me.pos))
	var ids := []
	for e in f.events(GameEventType.DamageDealt): ids.append(e.target)
	assert_seq(ids, [a.id, b.id], "default: the two nearest, in order")

	f.resolver.cast(me, _volley(InstinctDef.of(InstinctPreset.Weakest), "1"), Aim.at(me.pos, me.pos))
	assert_eq(f.events(GameEventType.DamageDealt).back().target, c.id, "Weakest picks C")

	f.resolver.cast(me, _volley(InstinctDef.new(), "10"), Aim.at(me.pos, me.pos))
	assert_eq(f.events(GameEventType.DamageDealt).size(), 2 + 1 + 3, "a count above the units there takes them all, never Far or allies")
	assert_eq(far.hp, 100)

func test_cast_ability_can_leave_the_aim_to_the_instinct() -> void:
	var f := Fixture.new()
	var tower := f.unit("Tower", 0, 0, 0, 100)
	f.unit("Near", 1, 1, 0, 100)
	var weak := f.unit("Weak", 1, 3, 0, 100)
	weak.hp = 15
	var snipe := _shot(InstinctDef.of(InstinctPreset.Weakest))
	var passive := AbilityDef.new()
	passive.name = "Trigger"
	var step := CastAbilityStep.new()
	step.ability = snipe
	step.aim_by_instinct = true
	passive.steps = [step]

	f.resolver.cast(tower, passive, Aim.at(tower.pos, tower.pos))
	var dealt := f.events(GameEventType.DamageDealt)
	assert_eq(dealt.size(), 1, f.dump())
	if dealt.size() == 1: assert_eq(dealt[0].target, weak.id, f.dump())

## A path along y = 0 from x = 0 to 7; the walker starts on its first tile.
static func _walker(f: Fixture, speed: int) -> Entity:
	var tiles := []
	for i in 8: tiles.append(Vector2i(i, 0))
	f.state.grid.add_path(tiles)
	var brute := f.unit("Brute", 1, 0, 0, 100, [["Speed", speed]])
	brute.path_id = 0
	brute.def.footing = Footing.OnPath
	var walk := _walk_ability("Brute Walk", PatternDef.path_ahead("Self.Speed"))
	walk.instinct = InstinctDef.of(InstinctPreset.Engage)
	brute.abilities.append(walk)
	brute.abilities.append(_shot(InstinctDef.of(InstinctPreset.Ahead), "Target.IsEnemy", "1"))
	return brute

func test_ahead_goes_for_the_unit_furthest_along_the_path_nearer_on_ties() -> void:
	var f := Fixture.new()
	var tiles := []
	for i in 8: tiles.append(Vector2i(i, 5))
	f.state.grid.add_path(tiles)
	var me := f.unit("Me", 1, 0, 5, 100); me.path_id = 0
	f.unit("Behind", 0, 1, 4, 100)
	var near := f.unit("Near", 0, 3, 4, 100)   # beside tile 3, 4 away
	f.unit("Far", 0, 3, 7, 100)                # beside tile 3 too (2 off the path), 5 away

	var ctx := _ctx(me, me, near, f.state.rng.clone())
	assert_num(Formula.new("Target.AheadOnPath").evaluate(f.vocab, ctx), Fixture.N(3))
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Ahead), "Target.IsEnemy", "8"), me) == near, "both are 3 ahead: the nearer")

func test_engage_walks_to_where_it_can_hit_the_unit_furthest_ahead() -> void:
	var f := Fixture.new()
	var brute := _walker(f, 4)
	f.unit("Early", 0, 1, 1, 100)                # beside tile 1
	f.unit("Ahead", 0, 3, 1, 100)                # beside tile 3: the one to go for
	f.unit("OutOfReach", 0, 6, 1, 100)           # beside tile 6, beyond Speed 4

	var walk := Instinct.choose(f.state, brute, brute.abilities[0])
	assert_eq(walk.tile, Vector2i(3, 0), "stops beside Ahead, not at the end of its reach (4, 0)")
	assert_eq(brute.pos, Vector2i(0, 0), "planning never moves it")

	assert_eq(Instinct.effective(f.state, brute, brute.abilities[0], [walk]), InstinctPreset.Engage)
	assert_true(Instinct.follow_up(brute, brute.abilities[0]) == brute.abilities[1])

func test_engage_walks_as_far_as_it_can_when_nothing_is_in_reach() -> void:
	var f := Fixture.new()
	var brute := _walker(f, 2)
	f.unit("Far", 0, 6, 1, 100)
	assert_eq(Instinct.choose(f.state, brute, brute.abilities[0]).tile, Vector2i(2, 0))

func test_an_engaging_enemy_turn_walks_then_hits_the_same_unit() -> void:
	var f := Fixture.new()
	var brute := _walker(f, 4)
	f.unit("Early", 0, 1, 1, 100)
	var ahead := f.unit("Ahead", 0, 3, 1, 100)

	# the turn as EnemyBrain runs it: each ability where its instinct says
	for a in brute.abilities.duplicate():
		var aim := Instinct.choose(f.state, brute, a)
		if aim != null: f.resolver.cast(brute, a, aim)

	assert_eq(brute.pos, Vector2i(3, 0))
	var dealt := f.events(GameEventType.DamageDealt)
	assert_eq(dealt.size(), 1, f.dump())
	if dealt.size() == 1: assert_eq(dealt[0].target, ahead.id, f.dump())

func test_most_hit_counts_enemies_and_spares_allies_when_the_area_has_no_filter() -> void:
	var f := Fixture.new()
	var me := f.unit("Me", 0, 0, 0, 100)
	f.unit("AllyA", 0, 3, 0, 100)
	f.unit("AllyB", 0, 3, 1, 100)
	var foe := f.unit("Foe", 1, 7, 0, 100) # out of range (6), but inside the radius of tile (6, 0)
	var fireball := AbilityDef.new()
	fireball.name = "Fireball"
	fireball.targeting = PatternDef.diamond("6")
	var atk := _attack()
	atk.area = PatternDef.circle("1")
	fireball.steps = [atk]

	var aim := Instinct.choose(f.state, me, fireball)
	assert_not_null(aim)
	if aim != null:
		var hit := Targeting.area_targets(f.state, me.id, fireball.steps[0], aim, {})
		assert_seq(hit, [foe.id], "the edge tile reaching the foe, not the allies' cluster")

	f.state.get_entity(foe.id).position = Vector2i(9, 9) # now nothing worth hitting is in reach
	assert_null(Instinct.choose(f.state, me, fireball), "no enemy in reach: no aim, rather than burning allies or empty ground")

func test_taunters_form_a_pool_the_instinct_chooses_from() -> void:
	var f := Fixture.new()
	var enemy := f.unit("Enemy", 1, 0, 0, 100)
	f.unit("Near", 0, 1, 0, 100)
	var older := f.unit("Older", 0, 2, 0, 100)
	var newer := f.unit("Newer", 0, 6, 0, 100)
	var taunt := StatusDef.new()
	taunt.name = "Taunt"
	taunt.tags = [Tags.Taunted]
	taunt.duration = -1
	taunt.stacking = Stacking.PerSource
	enemy.statuses.append(_status(taunt, older.id))
	enemy.statuses.append(_status(taunt, newer.id))

	assert_seq(Instinct.taunters(f.state, enemy), [newer.id, older.id])
	assert_true(_target(f, _shot(null, "Target.IsEnemy", "8"), enemy) == older, "both in reach: the instinct (Nearest) picks among the taunters, not the newest")
	assert_true(_target(f, _shot(InstinctDef.of(InstinctPreset.Farthest), "Target.IsEnemy", "8"), enemy) == newer, "Farthest picks the other taunter")
	assert_true(_target(f, _shot(null, "Target.IsEnemy", "3"), enemy) == older, "only one taunter in reach: that one, not the nearest unit")
	assert_true(_target(f, _shot(null, "Target.IsEnemy", "1"), enemy) == f.state.get_entity(f.state.entity_at(Vector2i(1, 0)).id), "no taunter in reach: everyone")

func test_a_self_cast_pick_shows_its_area_as_the_range() -> void:
	var f := Fixture.new()
	var drummer := f.unit("Drummer", 0, 5, 5, 25)
	var rally := AbilityDef.new()
	rally.name = "Rally"
	rally.targeting = PatternDef.self_()
	var pick := PickStep.new()
	pick.area = PatternDef.diamond("2")
	pick.center = PickCenter.Self
	pick.filter = Condition.new("Target.IsAlly")
	pick.count = Formula.new("99")
	rally.steps = [pick]

	var range_tiles := AimPreview.range(f.state, drummer.id, rally)
	assert_eq(range_tiles.size(), 13, "a diamond of radius 2: 1 + 4 + 8 tiles")
	assert_contains(range_tiles, Vector2i(5, 7))

	var aimed := AimPreview.for_aim(f.state, drummer.id, rally, Aim.at(drummer.pos, drummer.pos))
	assert_eq(aimed.area.size(), 13, "aimed on itself, the area is the Pick's diamond")

func test_an_aura_shows_the_tiles_it_covers() -> void:
	var f := Fixture.new()
	var drummer := f.unit("Drummer", 0, 5, 5, 25)
	var enemy := f.unit("Enemy", 1, 5, 6, 10)
	var entities := f.state.entities.size()

	var tiles := AimPreview.aura_range(f.state, drummer.id, "Target.IsAlly and Self.DistanceTo(Target) <= 2")
	assert_eq(tiles.size(), 12, "a diamond of radius 2 without the owner's tile, the enemy's tile included")
	assert_contains(tiles, Vector2i(5, 6))
	assert_not_contains(tiles, Vector2i(5, 8))
	assert_eq(enemy.pos, Vector2i(5, 6), "the live state is untouched")
	assert_eq(f.state.entities.size(), entities, "the probes live in a copy")
