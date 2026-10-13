extends TestCase
## Port of EntityTests.cs. Entity System — Design: lifecycle, summons, shields, rounds, hazards, capabilities,
## teams, auras, facing.

static func strike(damage: int = 10) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Strike"
	a.tags = [Tags.Attack]
	a.targeting = PatternDef.diamond("5")
	a.target_filter = Condition.new("Target.IsEnemy")
	var atk := AttackStep.new()
	atk.can_miss = false
	atk.can_crit = false
	atk.power = Formula.new(str(damage))
	var dmg := DamageStep.new()
	dmg.amount = Formula.new("ActionPower")
	atk.on_hit = [dmg]
	a.steps = [atk]
	return a

static func tagged(p_name: String, tags: Array) -> StatusDef:
	var s := StatusDef.new()
	s.name = p_name
	s.tags = tags
	return s

static func status(p_name: String) -> StatusDef:
	var s := StatusDef.new()
	s.name = p_name
	return s

static func give(e: Entity, def: StatusDef, by: Entity, turns: int = -1) -> void:
	var st := StatusInstance.new()
	st.def = def
	st.stacks = 1
	st.turns_left = turns
	st.applied_by = by.id if by != null else 0
	e.statuses.append(st)

static func _single(list: Array) -> Variant:
	return list[0] if list.size() == 1 else null

static func _named(f: Fixture, n: String) -> Entity:
	var found: Entity = null
	for e in f.state.entities:
		if e.name == n:
			if found != null: return null # Single(): more than one
			found = e
	return found

# ------------------------------------------------------------------ lifecycle

func test_death_leaves_a_corpse_with_kill_credit() -> void:
	var f := Fixture.new()
	var a := f.unit("A", 0, 0, 0, 100)
	var b := f.unit("B", 1, 1, 0, 10)
	var mark := status("Mark")
	mark.persists_through_death = true
	give(b, mark, a)
	give(b, status("Burn"), a)

	f.resolver.cast(a, strike(), Aim.at(a.pos, b.pos))

	assert_eq(b.life, LifeState.Dead, f.dump())
	assert_null(b.position)
	assert_not_null(b.death)
	if b.death != null:
		assert_eq(b.death.tile, Vector2i(1, 0))
		assert_eq(b.death.killer, a.id)
	assert_true(f.state.is_free(Vector2i(1, 0)), "a corpse leaves the blocking layer")
	assert_contains(f.state.corpses_at(Vector2i(1, 0)), b)
	assert_true(b.has_status("Mark"), "persistsThroughDeath keeps the status")
	assert_false(b.has_status("Burn"))
	var died = _single(f.events(GameEventType.EntityDied))
	assert_not_null(died)
	if died != null: assert_eq(died.source, a.id)

func test_summon_takes_the_team_and_dies_with_its_summoner() -> void:
	var f := Fixture.new()
	var necro := f.unit("Necro", 0, 0, 0, 10)
	var blocker := f.unit("Blocker", 1, 1, 0, 100)
	var skeleton := EntityDef.new()
	skeleton.name = "Skeleton"
	skeleton.die_with_summoner = true
	skeleton.stat("MaxHp", 20)
	var summon := AbilityDef.new()
	summon.name = "Raise"
	summon.targeting = PatternDef.diamond("3")
	var sp := SpawnStep.new()
	sp.entity = skeleton
	summon.steps = [sp]

	f.resolver.cast(necro, summon, Aim.at(necro.pos, blocker.pos)) # taken: nearest free tile within 1

	var sk := _named(f, "Skeleton")
	assert_not_null(sk, f.dump())
	if sk == null: return
	assert_eq(sk.position, Vector2i(2, 0), f.dump())
	assert_eq(sk.summoner, necro.id)
	assert_eq(f.state.effective_team(sk), 0)
	assert_eq(sk.hp, 20)
	assert_eq(f.events(GameEventType.EntitySpawned).size(), 1)

	f.resolver.cast(blocker, strike(), Aim.at(blocker.pos, necro.pos))

	assert_eq(necro.life, LifeState.Dead, f.dump())
	assert_eq(sk.life, LifeState.Removed)
	var removed = _single(f.events(GameEventType.EntityRemoved))
	assert_eq(removed.detail if removed != null else null, "summoner died")
	assert_eq(f.events(GameEventType.EntityDied).size(), 1, "removal is not a death")

func test_resurrection_targets_a_corpse() -> void:
	var f := Fixture.new()
	var priest := f.unit("Priest", 0, 0, 0, 100)
	var ally := f.unit("Ally", 0, 1, 0, 10)
	var enemy := f.unit("Enemy", 1, 3, 0, 100)
	f.resolver.cast(enemy, strike(), Aim.at(enemy.pos, ally.pos))
	assert_eq(ally.life, LifeState.Dead)

	var raise := AbilityDef.new()
	raise.name = "Resurrect"
	raise.targets_dead = true
	raise.targeting = PatternDef.diamond("3")
	raise.target_filter = Condition.new("Target.IsAlly")
	var rs := ResurrectStep.new()
	rs.hp = Formula.new("Target.MaxHp * 0.5")
	raise.steps = [rs]
	var tiles := []
	for aim in Targeting.valid_aims(f.state, priest.id, raise): tiles.append(aim.tile)
	assert_contains(tiles, Vector2i(1, 0))
	assert_not_contains(tiles, enemy.pos, "living entities are not corpses")

	f.resolver.cast(priest, raise, Aim.at(priest.pos, Vector2i(1, 0)))

	assert_true(ally.alive, f.dump())
	assert_eq(ally.hp, 5)
	assert_eq(ally.position, Vector2i(1, 0))
	assert_eq(f.events(GameEventType.EntityResurrected).size(), 1)

func test_shields_drain_newest_first() -> void:
	var f := Fixture.new()
	var u := f.unit("U", 0, 0, 0, 100)
	var enemy := f.unit("Enemy", 1, 1, 0, 100)
	var barrier := status("Barrier")
	barrier.shield_pool = Formula.new("10")
	var ward := status("Ward")
	ward.shield_pool = Formula.new("5")
	var shield_up := AbilityDef.new()
	shield_up.name = "Shield Up"
	var s1 := ApplyStatusStep.new()
	s1.status = barrier
	s1.on = StepTarget.Self
	var s2 := ApplyStatusStep.new()
	s2.status = ward
	s2.on = StepTarget.Self
	shield_up.steps = [s1, s2]

	f.resolver.cast(u, shield_up, Aim.at(u.pos, u.pos))
	assert_eq(u.shield, 15)

	f.resolver.cast(enemy, strike(12), Aim.at(enemy.pos, u.pos))

	assert_eq(u.hp, 100, f.dump())
	assert_eq(u.shield, 3)
	assert_false(u.has_status("Ward"), "an empty pool removes its status")
	assert_true(u.has_status("Barrier"))
	var dealt = _single(f.events(GameEventType.DamageDealt))
	assert_not_null(dealt)
	if dealt != null:
		assert_num(dealt.facts.get("Absorbed"), Fixture.N(12))
		assert_num(dealt.facts.get("HpLost"), 0.0)

# ------------------------------------------------------------------ rounds and hazards

func test_rounds_order_by_initiative_and_a_fire_tile_burns_then_expires() -> void:
	var f := Fixture.new()
	var fast := f.unit("Fast", 0, 0, 0, 100, [["Initiative", 5]])
	var slow := f.unit("Slow", 1, 5, 5, 100, [["Initiative", 1]])
	var mid := f.unit("Mid", 1, 2, 2, 10, [["Initiative", 3]])

	var hazard := EntityDef.new()
	hazard.name = "Fire Tile"
	hazard.kind = EntityKind.Hazard
	var fire := f.state.create(hazard, 0, Vector2i(2, 2))
	var burn := ReactionDef.new()
	burn.name = "Burn"
	burn.trigger = Trigger.OnAnyTurnStart
	burn.condition = Condition.new("Self.DistanceTo(Target) == 0")
	var dmg := DamageStep.new()
	dmg.amount = Formula.new("10")
	dmg.on = StepTarget.EventTarget
	burn.response = [dmg]
	fire.grant(burn)
	var burning := status("Burning")
	burning.duration = 1
	burning.duration_unit = DurationUnit.Rounds
	var burn_out := ReactionDef.new()
	burn_out.name = "Burn out"
	burn_out.trigger = Trigger.OnStatusRemoved
	var rm := RemoveStep.new()
	rm.reason = "burned out"
	burn_out.response = [rm]
	burning.reactions.append(burn_out)
	give(fire, burning, null, 1)
	assert_true(f.state.is_free(Vector2i(2, 2)) == false, "Mid stands on the hazard: hazards overlay, they don't block")

	f.resolver.start_round()
	assert_seq(f.state.turn_order, [fast.id, mid.id, slow.id])

	assert_eq(f.resolver.begin_next_turn(), fast)
	f.resolver.end_turn()
	assert_eq(f.resolver.begin_next_turn(), mid)
	assert_eq(mid.life, LifeState.Dead, f.dump())
	assert_eq(mid.death.killer if mid.death != null else null, -1, "the Environment never gets kill credit")
	f.resolver.end_turn()
	assert_eq(f.resolver.begin_next_turn(), slow)
	f.resolver.end_turn()
	assert_null(f.resolver.begin_next_turn())

	f.resolver.end_round()
	assert_eq(fire.life, LifeState.Removed, f.dump())

	f.resolver.start_round()
	assert_eq(f.state.round, 2)
	assert_seq(f.state.turn_order, [fast.id, slow.id], "the dead take no turns")

func test_spawned_hazard_ignites_on_spawn_and_burns_out_after_two_rounds() -> void:
	var f := Fixture.new()
	var mage := f.unit("Mage", 0, 0, 0, 100)
	var burning := status("Burning")
	burning.duration = 2
	burning.duration_unit = DurationUnit.Rounds
	var burn_out := ReactionDef.new()
	burn_out.name = "Burn Out"
	burn_out.trigger = Trigger.OnStatusRemoved
	var rm := RemoveStep.new()
	rm.reason = "burned out"
	burn_out.response = [rm]
	burning.reactions.append(burn_out)
	var rules := PassiveDef.new()
	rules.name = "Fire Tile Rules"
	var ignite := ReactionDef.new()
	ignite.name = "Ignite"
	ignite.trigger = Trigger.OnSpawned
	var ap := ApplyStatusStep.new()
	ap.status = burning
	ap.on = StepTarget.Self
	ignite.response = [ap]
	rules.reactions.append(ignite)
	var tile := EntityDef.new()
	tile.name = "Fire Tile"
	tile.kind = EntityKind.Hazard
	tile.passives.append(rules)
	var wall := AbilityDef.new()
	wall.name = "Fire Wall"
	wall.targeting = PatternDef.diamond("4")
	var sp := SpawnStep.new()
	sp.entity = tile
	sp.summon = false
	wall.steps = [sp]

	f.resolver.cast(mage, wall, Aim.at(mage.pos, Vector2i(2, 0)))

	var fire := _named(f, "Fire Tile")
	assert_not_null(fire, f.dump())
	if fire == null: return
	assert_eq(fire.created_by, mage.id)
	assert_true(fire.has_status("Burning"), f.dump())
	assert_true(f.state.is_free(Vector2i(2, 0)), "hazards do not block")

	f.resolver.start_round()
	f.resolver.end_round()
	assert_true(fire.alive)
	f.resolver.start_round()
	f.resolver.end_round()
	assert_eq(fire.life, LifeState.Removed, f.dump())

func test_turn_start_refreshes_points_and_regenerates_mana() -> void:
	var f := Fixture.new()
	f.rules.mana_regen = Formula.new("2")
	var u := f.unit("U", 0, 0, 0, 100, [["MaxMana", 10], ["ActionPoints", 2], ["MovePoints", 3]])
	assert_eq(u.resource("Mana"), 10)
	u.resources["Mana"] = 3
	u.resources["Ap"] = 0
	u.resources["Mp"] = 0

	f.resolver.start_turn(u)

	assert_eq(u.resource("Mana"), 5)
	assert_eq(u.resource("Ap"), 2)
	assert_eq(u.resource("Mp"), 3)

# ------------------------------------------------------------------ capabilities

func test_control_tags_gate_casting() -> void:
	var f := Fixture.new()
	var a := f.unit("A", 0, 0, 0, 100)
	f.unit("B", 1, 1, 0, 100)
	var bolt := AbilityDef.new()
	bolt.name = "Bolt"
	bolt.tags = [Tags.Spell]

	give(a, tagged("Silence", [Tags.Silenced]), null)
	var reason := []
	assert_false(Targeting.can_cast(f.state, a.id, bolt, reason))
	assert_eq(reason[0] if reason.size() > 0 else null, "Silenced")
	assert_true(Targeting.can_cast(f.state, a.id, strike()), "silence only stops spells")

	give(a, tagged("Stun", [Tags.Stunned]), null)
	reason = []
	assert_false(Targeting.can_cast(f.state, a.id, strike(), reason))
	assert_eq(reason[0] if reason.size() > 0 else null, "Cannot act")
	assert_false(a.can_move)

func test_stealth_hides_from_single_target_but_not_areas() -> void:
	var f := Fixture.new()
	var c := f.unit("C", 0, 0, 0, 100)
	var s := f.unit("S", 1, 2, 0, 100)
	give(s, tagged("Stealth", [Tags.Stealthed]), s)

	var tiles := []
	for aim in Targeting.valid_aims(f.state, c.id, strike()): tiles.append(aim.tile)
	assert_not_contains(tiles, s.pos)

	var blast := AttackStep.new()
	blast.area = PatternDef.diamond("1")
	var hit := Targeting.area_targets(f.state, c.id, blast, Aim.at(c.pos, Vector2i(1, 0)), Tags.set_of([]))
	assert_contains(hit, s.id)

func test_redirect_restricts_single_target_aims_to_the_applier() -> void:
	var f := Fixture.new()
	var c := f.unit("C", 0, 0, 0, 100)
	var t1 := f.unit("T1", 1, 1, 0, 100)
	var t2 := f.unit("T2", 1, 0, 1, 100)
	give(c, tagged("Redirect", [Tags.Redirected]), t2)

	var aims := []
	for aim in Targeting.valid_aims(f.state, c.id, strike()): aims.append(aim.tile)
	assert_seq(aims, [t2.pos])
	if aims.size() > 0: assert_ne(aims[0], t1.pos)

# ------------------------------------------------------------------ teams, auras, passives

func test_charm_overrides_the_team_until_it_expires() -> void:
	var f := Fixture.new()
	var a := f.unit("A", 0, 0, 0, 100)
	var b := f.unit("B", 1, 1, 0, 100)
	var charm := status("Charm")
	charm.team_override = TeamOverride.Applier
	charm.duration = 1
	var cast := AbilityDef.new()
	cast.name = "Charm"
	cast.targeting = PatternDef.diamond("3")
	cast.target_filter = Condition.new("Target.IsEnemy")
	var ap := ApplyStatusStep.new()
	ap.status = charm
	cast.steps = [ap]

	f.resolver.cast(a, cast, Aim.at(a.pos, b.pos))

	assert_eq(f.state.effective_team(b), 0, f.dump())
	assert_eq(f.state.relation(a, b), Relation.Ally)
	var is_ally := Condition.new("Target.IsAlly")
	var ctx := EvalContext.new()
	ctx.self_ = a
	ctx.target = b
	ctx.rng = f.state.rng
	assert_true(is_ally.evaluate(f.vocab, ctx))
	assert_eq(f.events(GameEventType.TeamChanged).size(), 1)

	f.resolver.end_turn(b)

	assert_eq(f.state.effective_team(b), 1)
	assert_eq(f.events(GameEventType.TeamChanged).size(), 2)

func test_aura_applies_to_allies_in_range() -> void:
	var f := Fixture.new()
	var owner := f.unit("Banner", 0, 0, 0, 100)
	var near := f.unit("Near", 0, 1, 0, 100, [["Str", 10]])
	var far := f.unit("Far", 0, 5, 5, 100, [["Str", 10]])
	var foe := f.unit("Foe", 1, 0, 1, 100, [["Str", 10]])
	var banner := PassiveDef.new()
	banner.name = "War Banner"
	banner.aura = Condition.new("Target.IsAlly and Self.DistanceTo(Target) <= 2")
	banner.modifiers.append(Modifier.new("Str", ModKind.Flat, "5"))
	owner.grant(banner)

	assert_num(f.state.final_stat(near, "Str"), Fixture.N(15))
	assert_num(f.state.final_stat(far, "Str"), Fixture.N(10))
	assert_num(f.state.final_stat(foe, "Str"), Fixture.N(10))
	assert_num(f.state.final_stat(owner, "Str"), Fixture.N(5), "an entity is its own ally")

	near.position = Vector2i(4, 4) # auras follow positions with no tracking
	assert_num(f.state.final_stat(near, "Str"), Fixture.N(10))

func test_passive_switches_write_events() -> void:
	var f := Fixture.new()
	var u := f.unit("U", 0, 0, 0, 100)
	var enemy := f.unit("Enemy", 1, 1, 0, 100)
	var last_stand := PassiveDef.new()
	last_stand.name = "Last Stand"
	last_stand.condition = Condition.new("Self.HpPct < 0.5")
	last_stand.modifiers.append(Modifier.new("Str", ModKind.Flat, "10"))
	u.grant(last_stand)

	f.resolver.cast(enemy, strike(60), Aim.at(enemy.pos, u.pos))

	var act = _single(f.events(GameEventType.PassiveActivated))
	assert_eq(act.detail if act != null else null, "Last Stand", f.dump())
	assert_eq(f.events(GameEventType.PassiveDeactivated).size(), 0, "the silent start-of-command check writes nothing")
	assert_num(f.state.final_stat(u, "Str"), Fixture.N(10))

## The example Counter-attack: hits an adjacent attacker back for 5, once per turn, while at half HP or more.
static func counter_attack() -> PassiveDef:
	var p := PassiveDef.new()
	p.name = "Counter-attack"
	p.display_name = "Counter-attack"
	p.condition = Condition.new("Self.Hp * 2 >= Self.MaxHp")
	var r := ReactionDef.new()
	r.name = "Counter Strike"
	r.trigger = Trigger.OnHitTaken
	r.condition = Condition.new("Self.DistanceTo(Source) <= 1")
	r.limit = Limit.OncePerTurn
	var d := DamageStep.new()
	d.amount = Formula.new("5")
	d.on = StepTarget.EventSource
	d.tags = [Tags.Reflected]
	r.response = [d]
	p.reactions = [r]
	return p

func test_counter_attack_hits_an_adjacent_attacker_once_per_turn() -> void:
	var f := Fixture.new()
	var archer := f.unit("Archer", 0, 2, 2, 100)
	var enemy := f.unit("Enemy", 1, 3, 2, 100)
	archer.grant(counter_attack())

	f.resolver.cast(enemy, strike(10), Aim.at(enemy.pos, archer.pos))
	assert_eq(enemy.hp, 95, f.dump())
	f.resolver.cast(enemy, strike(10), Aim.at(enemy.pos, archer.pos))
	assert_eq(enemy.hp, 95, "once per turn")
	assert_eq(archer.hp, 80)

func test_counter_attack_ignores_attackers_from_range() -> void:
	var f := Fixture.new()
	var archer := f.unit("Archer", 0, 2, 2, 100)
	var enemy := f.unit("Enemy", 1, 5, 2, 100)
	archer.grant(counter_attack())

	f.resolver.cast(enemy, strike(10), Aim.at(enemy.pos, archer.pos))
	assert_eq(enemy.hp, 100, f.dump())

static func _passive_views(f: Fixture, e: Entity) -> Array:
	var frame := ViewFrame.capture(f.state, null, 0).get_frame(e.id)
	return frame.passives if frame != null else []

func test_counter_attack_turns_off_below_half_hp_and_the_frame_shows_it() -> void:
	var f := Fixture.new()
	var archer := f.unit("Archer", 0, 2, 2, 100)
	var enemy := f.unit("Enemy", 1, 3, 2, 100)
	archer.grant(counter_attack())
	var views := _passive_views(f, archer)
	assert_true(views.size() == 1 and views[0].active)

	# reactions are gathered when the hit is written, so the hit that wounds it is still answered
	f.resolver.cast(enemy, strike(60), Aim.at(enemy.pos, archer.pos)) # 40 HP left: the passive switches off
	assert_eq(enemy.hp, 95, f.dump())

	f.resolver.start_turn(archer) # a new turn: the once-per-turn limit no longer blocks it
	f.resolver.cast(enemy, strike(10), Aim.at(enemy.pos, archer.pos))
	assert_eq(enemy.hp, 95, "off below half HP: no counter")
	views = _passive_views(f, archer)
	assert_eq(views.size(), 1)
	if views.size() == 1:
		assert_eq(views[0].name, "Counter-attack")
		assert_false(views[0].active)

func test_hidden_passives_are_not_in_the_frame() -> void:
	var f := Fixture.new()
	var u := f.unit("U", 0, 0, 0, 100)
	var mech := PassiveDef.new()
	mech.name = "Mechanics"
	mech.hidden = true
	u.grant(mech)
	var shown := PassiveDef.new()
	shown.name = "Shown"
	u.grant(shown)

	var views := _passive_views(f, u)
	assert_eq(views.size(), 1)
	if views.size() == 1: assert_eq(views[0].name, "Shown")

# ------------------------------------------------------------------ facing

func test_casting_turns_the_caster_and_is_behind_reads_facing() -> void:
	var f := Fixture.new()
	f.rules.facing_enabled = true
	var a := f.unit("A", 0, 2, 2, 100)
	var b := f.unit("B", 1, 0, 2, 100)
	var c := f.unit("C", 1, 2, 1, 100)

	f.resolver.cast(b, strike(1), Aim.at(b.pos, a.pos))
	assert_eq(b.facing, Vector2i(1, 0))
	assert_eq(f.events(GameEventType.FacingChanged).size(), 1)

	# A faces +y (the default); C stands at -y from A
	var behind := Condition.new("Target.IsBehind")
	assert_true(behind.evaluate(f.vocab, _ctx(c, a, f)))
	assert_false(behind.evaluate(f.vocab, _ctx(b, a, f)), "beside is not behind")

	f.rules.facing_enabled = false
	assert_false(behind.evaluate(f.vocab, _ctx(c, a, f)), "facing off: never behind")

static func _ctx(self_e: Entity, target: Entity, f: Fixture) -> EvalContext:
	var ctx := EvalContext.new()
	ctx.self_ = self_e
	ctx.target = target
	ctx.rng = f.state.rng
	return ctx
