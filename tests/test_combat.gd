extends TestCase
## Port of CombatTests.cs — Ability Pipeline — Effect Queue Architecture: the example flows and resolution rules.

# ------------------------------------------------------------------ helpers (C# object initialisers)

## Sets properties on obj; a String given for a Formula / Condition property becomes one.
static func mk(obj, props: Dictionary = {}):
	for k in props:
		var v = props[k]
		var cur = obj.get(k)
		if v is String and cur is Formula: v = Formula.new(v)
		elif v is String and cur is Condition: v = Condition.new(v)
		obj.set(k, v)
	return obj

static func T(name: String) -> int: return GameEventType.NAMES.find(name)

func _ids(events: Array, field: String) -> Array:
	var out := []
	for e in events: out.append(e.get(field))
	return out

# ------------------------------------------------------------------ shared definitions

static func rooted() -> StatusDef:
	return mk(StatusDef.new(), {name = "Rooted", tags = [Tags.Rooted, Tags.Debuff], stacking = Stacking.Refresh, duration = 1})

static func thorns() -> ReactionDef:
	return mk(ReactionDef.new(), {name = "Thorns", trigger = Trigger.OnHitTaken,
		response = [mk(DamageStep.new(), {amount = "FinalDamage * 0.2", on = StepTarget.EventSource, tags = [Tags.Reflected]})]})

# ------------------------------------------------------------------ worked examples

func test_shield_breaker_deals_211() -> void:
	var f := Fixture.new()
	f.rules.mitigation = Formula.new("Damage * 100 / (100 + Target.Armor)")
	var caster: Entity = f.unit("Breaker", 0, 2, 2, 100, [["Str", 20], ["Per", 12]])
	caster.grant(Modifier.new("ActionPower", ModKind.PctAdd, "0.2"))
	var target: Entity = f.unit("Target", 1, 4, 2, 400, [["Armor", 25]])
	target.hp = 100

	var ability: AbilityDef = mk(AbilityDef.new(), {name = "Shield Breaker", tags = [Tags.Attack],
		targeting = PatternDef.diamond("1 + floor(Source.Per / 5)", "1"),
		steps = [mk(AttackStep.new(), {area = PatternDef.plus("1"), power = "100 + Source.Str * 1.5", can_miss = false, can_crit = false,
			on_hit = [mk(DamageStep.new(), {amount = "(ActionPower + Target.MaxHp * 0.05) * if(Target.HpPct < 0.3, 1.5, 1)"})]})]})

	# range 1..3 diamond around (2,2) on a 10×10 grid: 4 + 8 + 12 tiles, minus those off the grid
	var aims: Array = Targeting.valid_aims(f.state, caster.id, ability)
	assert_true(aims.any(func(a): return a.tile == target.pos))
	assert_false(aims.any(func(a): return a.tile == caster.pos))

	f.resolver.cast(caster, ability, Aim.at(caster.pos, target.pos))

	var dealt_all: Array = f.events(GameEventType.DamageDealt)
	assert_eq(dealt_all.size(), 1, f.dump())
	if dealt_all.size() != 1: return
	var dealt: GameEvent = dealt_all[0]
	assert_num(f.events(GameEventType.AttackStarted)[0].facts["ActionPower"], 156)
	assert_num(dealt.facts["Damage"], 264)
	assert_num(dealt.facts["FinalDamage"], 211)
	assert_num(dealt.facts["HpLost"], 100)
	assert_num(dealt.facts["Overkill"], 111)
	assert_false(target.alive)

func test_fireball_area_attack_with_reactions() -> void:
	var f := Fixture.new()
	var mage: Entity = f.unit("Mage", 0, 0, 0, 100)
	mage.resources["Mana"] = 10
	var a: Entity = f.unit("A", 1, 5, 5, 500)
	# B and C are enemies of the Mage but not allies of A, so only A's hit triggers Enrage
	var b: Entity = f.unit("B", 2, 6, 5, 500, [["Evasion", 1]])   # dodges
	var c: Entity = f.unit("C", 2, 5, 6, 500, [["Exposed", 1]])   # crit
	var ally: Entity = f.unit("Ally", 1, 9, 9, 500, [["Str", 5]])

	a.grant(thorns())
	a.grant(Modifier.new("FinalDamage", ModKind.PctAdd, "0.2", ModDirection.Incoming, Tags.Fire)) # Fire Vulnerability
	var enrage: StatusDef = mk(StatusDef.new(), {name = "Enrage", modifiers = [Modifier.new("Str", ModKind.Flat, "10")]})
	ally.grant(mk(ReactionDef.new(), {name = "Enrage", trigger = Trigger.OnAllyHitTaken,
		response = [mk(ApplyStatusStep.new(), {status = enrage, on = StepTarget.Self})]}))
	mage.grant(thorns()) # must ignore the Reflected damage

	var fireball: AbilityDef = mk(AbilityDef.new(), {name = "Fireball", tags = [Tags.Attack, Tags.Spell, Tags.Fire],
		costs = [Cost.new("Mana", 5)], targeting = PatternDef.diamond("20"),
		steps = [mk(AttackStep.new(), {area = PatternDef.circle("1"), power = "100", on_hit = [DamageStep.new()]})]})

	f.resolver.cast(mage, fireball, Aim.at(mage.pos, a.pos))

	assert_eq(mage.resources["Mana"], 5)
	assert_seq(f.types(), [
		GameEventType.ResourceChanged,
		GameEventType.AbilityDeclared,
		GameEventType.AttackStarted,
		# the batch: A hit, B dodge, C crit
		GameEventType.DamageDealt, GameEventType.HitResolved,
		GameEventType.HitResolved,
		GameEventType.DamageDealt, GameEventType.HitResolved,
		# reactions after the batch: Thorns (target side) before Enrage (third party)
		GameEventType.DamageDealt,
		GameEventType.StatusApplied,
		GameEventType.AttackEnded,
		GameEventType.AbilityEnded], f.dump())

	var hits: Array = f.events(GameEventType.HitResolved)
	assert_seq(_ids(hits, "target"), [a.id, b.id, c.id])
	if hits.size() < 3: return
	assert_false(hits[1].fact("Hit"))
	assert_true(hits[2].fact("IsCrit"))

	var dmg: Array = f.events(GameEventType.DamageDealt)
	if dmg.size() < 3: fail("expected 3 DamageDealt"); return
	assert_num(dmg[0].facts["FinalDamage"], 120) # 100 × 1.2 Fire Vulnerability
	assert_num(dmg[1].facts["FinalDamage"], 150) # 100 × 1.5 crit
	assert_eq(dmg[2].target, mage.id)            # Thorns
	assert_num(dmg[2].facts["FinalDamage"], 24)
	assert_true(dmg[2].tags.has(Tags.Reflected))
	assert_eq(mage.hp, 76)
	assert_num(ally.stat("Str"), 15)

static func shield_bash() -> AbilityDef:
	return mk(AbilityDef.new(), {name = "Shield Bash", tags = [Tags.Attack], targeting = PatternDef.diamond("1", "1"),
		steps = [mk(AttackStep.new(), {power = "80", can_miss = false, can_crit = false,
			on_hit = [DamageStep.new(), mk(PushStep.new(), {distance = "2"})]})]})

static func collision_damage() -> ReactionDef:
	return mk(ReactionDef.new(), {name = "Collision damage", trigger = Trigger.OnCollision,
		response = [mk(DamageStep.new(), {amount = "10", on = StepTarget.EventTarget})]})

func test_shield_bash_hit_push_collision() -> void:
	var f := Fixture.new()
	f.rules.reactions.append(collision_damage())
	f.state.grid.set_terrain(Vector2i(4, 1), TerrainDef.Wall)
	var knight: Entity = f.unit("Knight", 0, 1, 1, 100)
	var b: Entity = f.unit("B", 1, 2, 1, 100)

	f.resolver.cast(knight, shield_bash(), Aim.at(knight.pos, b.pos))

	assert_eq(b.pos, Vector2i(3, 1))
	assert_eq(b.hp, 10)
	assert_seq(f.types(), [
		GameEventType.AbilityDeclared, GameEventType.AttackStarted,
		GameEventType.DamageDealt, GameEventType.HitResolved,
		GameEventType.EntityMoved, GameEventType.EntityEnteredTile, GameEventType.Collision,
		GameEventType.DamageDealt,
		GameEventType.AttackEnded, GameEventType.AbilityEnded], f.dump())
	var dmg: Array = f.events(GameEventType.DamageDealt)
	if dmg.size() > 1: assert_eq(dmg[1].source, 0)

func test_shield_bash_lethal_hit_still_pushes_and_collision_fizzles() -> void:
	var f := Fixture.new()
	f.rules.reactions.append(collision_damage())
	f.state.grid.set_terrain(Vector2i(4, 1), TerrainDef.Wall)
	var knight: Entity = f.unit("Knight", 0, 1, 1, 100)
	var b: Entity = f.unit("B", 1, 2, 1, 80)

	f.resolver.cast(knight, shield_bash(), Aim.at(knight.pos, b.pos))

	assert_eq(b.pos, Vector2i(3, 1), "deaths are decided at the checkpoint, so B is still pushed")
	assert_false(b.alive)
	var types: Array = f.types()
	assert_true(types.find(GameEventType.Collision) < types.find(GameEventType.EntityDied), f.dump())
	assert_true(types.find(GameEventType.EntityDied) < types.find(GameEventType.Fizzled), f.dump())
	assert_eq(f.events(GameEventType.DamageDealt).size(), 1)

func test_walk_interrupted_by_overwatch() -> void:
	var f := Fixture.new()
	var rogue: Entity = f.unit("Rogue", 0, 2, 1, 100)
	var archer: Entity = f.unit("Archer", 1, 5, 2, 100)

	var pinning_shot: AbilityDef = mk(AbilityDef.new(), {name = "Pinning Shot", tags = [Tags.Attack], targeting = PatternDef.diamond("10"),
		steps = [mk(AttackStep.new(), {power = "10", can_miss = false, can_crit = false,
			on_hit = [DamageStep.new(), mk(ApplyStatusStep.new(), {status = rooted()})]})]})
	archer.grant(mk(ReactionDef.new(), {name = "Overwatch", trigger = Trigger.OnEnterTile,
		condition = "Target.IsEnemy and Self.DistanceTo(Target) <= 3 and Self.CanAct", limit = Limit.OncePerTurn,
		response = [mk(CastAbilityStep.new(), {ability = pinning_shot, aim_at = StepTarget.EventTarget})]}))

	var walk: AbilityDef = mk(AbilityDef.new(), {name = "Walk", steps = [WalkStep.new()]})
	f.resolver.cast(rogue, walk, Aim.walk(Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)))

	assert_eq(rogue.pos, Vector2i(3, 1))
	assert_eq(rogue.hp, 90)
	assert_true(rogue.has_status("Rooted"))
	assert_eq(f.events(GameEventType.Fizzled).size(), 2, f.dump())
	var declared: Array = f.events(GameEventType.AbilityDeclared)
	assert_eq(declared.filter(func(e): return e.detail == "Pinning Shot").size(), 1)
	assert_true(declared[-1].tags.has(Tags.Reaction))
	assert_eq(f.log.events[-1].type, GameEventType.AbilityEnded)
	assert_eq(f.log.events[-1].detail, "Walk")

func test_chain_lightning_bounces_with_frozen_power() -> void:
	var f := Fixture.new()
	var mage: Entity = f.unit("Mage", 0, 0, 0, 100)
	var t1: Entity = f.unit("T1", 1, 4, 4, 500)
	var t2: Entity = f.unit("T2", 1, 5, 5, 500)
	var t3: Entity = f.unit("T3", 1, 6, 6, 500)
	var far: Entity = f.unit("Far", 1, 9, 0, 500)
	var friend: Entity = f.unit("Friend", 0, 4, 5, 500)

	var chain_lightning: AbilityDef = mk(AbilityDef.new(), {name = "Chain Lightning", tags = [Tags.Spell], targeting = PatternDef.diamond("20"),
		steps = [mk(AttackStep.new(), {power = "60", can_miss = false, can_crit = false,
			bounces = "2", bounce_area = PatternDef.diamond("2"), bounce_filter = "Target.IsEnemy",
			on_hit = [DamageStep.new()]})]})

	f.resolver.cast(mage, chain_lightning, Aim.at(mage.pos, t1.pos))

	var dealt: Array = f.events(GameEventType.DamageDealt)
	assert_seq(_ids(dealt, "target"), [t1.id, t2.id, t3.id], f.dump())
	assert_true(dealt.all(func(d): return d.facts["FinalDamage"] == 60.0))
	assert_eq(friend.hp, 500)
	assert_eq(far.hp, 500)
	assert_eq(f.events(GameEventType.AttackStarted).size(), 1)
	assert_eq(f.events(GameEventType.AttackEnded).size(), 1)

func test_poison_kill_triggers_on_kill_of_the_applier() -> void:
	var f := Fixture.new()
	var shaman: Entity = f.unit("Shaman", 1, 0, 0, 100)
	var u: Entity = f.unit("U", 0, 3, 3, 10)
	var poison: StatusDef = mk(StatusDef.new(), {name = "Poison",
		reactions = [mk(ReactionDef.new(), {trigger = Trigger.OnTurnStart,
			response = [mk(DamageStep.new(), {amount = "Self.Stacks(Poison) * 5", on = StepTarget.Self})]})]})
	u.statuses.append(mk(StatusInstance.new(), {def = poison, stacks = 3, turns_left = -1, applied_by = shaman.id}))
	shaman.grant(mk(ReactionDef.new(), {name = "Soul harvest", trigger = Trigger.OnKill,
		response = [mk(HealStep.new(), {amount = "5", on = StepTarget.Self})]}))
	shaman.hp = 50

	f.resolver.start_turn(u)

	assert_false(u.alive)
	var died: Array = f.events(GameEventType.EntityDied)
	assert_eq(died.size(), 1, f.dump())
	if died.size() == 1: assert_eq(died[0].source, shaman.id)
	assert_eq(shaman.hp, 55)

# ------------------------------------------------------------------ rules

func test_replacements_cancel_redirect_replace() -> void:
	var f := Fixture.new()
	var attacker: Entity = f.unit("Attacker", 0, 0, 0, 100)
	var immune: Entity = f.unit("Salamander", 1, 2, 0, 100)
	immune.grant(mk(ReplacementRule.new(), {name = "Fire Immunity", matches = EffectKind.Damage, with_tags = [Tags.Fire],
		condition = "Target.IsAlly and Self.DistanceTo(Target) == 0", action = ReplaceAction.Cancel}))

	var ward: Entity = f.unit("Ward", 1, 5, 5, 100)
	var guard: Entity = f.unit("Guard", 1, 5, 6, 200)
	var guard2: Entity = f.unit("Guard2", 1, 6, 6, 200)
	var bodyguard: ReplacementRule = mk(ReplacementRule.new(), {name = "Bodyguard", matches = EffectKind.Damage,
		condition = "Target.IsAlly and Self.DistanceTo(Target) == 1 and Self.CanAct", action = ReplaceAction.Redirect})
	guard.grant(bodyguard)
	guard2.grant(bodyguard)

	var statue: Entity = f.unit("Statue", 1, 8, 0, 100)
	statue.grant(mk(ReplacementRule.new(), {name = "Stone Form", matches = EffectKind.Push,
		condition = "Self.DistanceTo(Target) == 0", action = ReplaceAction.Replace,
		instead = [mk(ApplyStatusStep.new(), {status = rooted(), on = StepTarget.Self})]}))

	var hit := func(name: String, tags: Array) -> AbilityDef:
		return mk(AbilityDef.new(), {name = name, tags = tags, targeting = PatternDef.diamond("20"),
			steps = [mk(AttackStep.new(), {power = "30", can_miss = false, can_crit = false, on_hit = [DamageStep.new(), PushStep.new()]})]})

	f.resolver.cast(attacker, hit.call("Flame", [Tags.Fire]), Aim.at(attacker.pos, immune.pos))
	assert_eq(immune.hp, 100)
	assert_true(f.events(GameEventType.Prevented).any(func(e): return e.detail.contains("Fire Immunity")))

	f.resolver.cast(attacker, hit.call("Strike", []), Aim.at(attacker.pos, ward.pos))
	assert_eq(ward.hp, 100, "damage redirected away from the ward")
	assert_eq(guard.hp + guard2.hp - 200, 170, "exactly one guard takes it, once")

	f.resolver.cast(attacker, hit.call("Shove", []), Aim.at(attacker.pos, statue.pos))
	assert_eq(statue.pos, Vector2i(8, 0))
	assert_true(statue.has_status("Rooted"))

func test_scoped_modifier_lasts_for_one_ability() -> void:
	var f := Fixture.new()
	var caster: Entity = f.unit("Caster", 0, 0, 0, 100, [["Str", 10]])
	var target: Entity = f.unit("Target", 1, 1, 0, 500)
	caster.grant(mk(ReactionDef.new(), {name = "Battle cry", trigger = Trigger.OnCast,
		response = [mk(AddScopedModifierStep.new(), {modifier = Modifier.new("Str", ModKind.Flat, "10")})]}))
	var strike: AbilityDef = mk(AbilityDef.new(), {name = "Strike", targeting = PatternDef.diamond("1"),
		steps = [mk(AttackStep.new(), {power = "Source.Str * 2", can_miss = false, can_crit = false, on_hit = [DamageStep.new()]})]})

	f.resolver.cast(caster, strike, Aim.at(caster.pos, target.pos))

	assert_num(f.events(GameEventType.AttackStarted)[0].facts["ActionPower"], 40, "reaction to AbilityDeclared runs before the first step")
	assert_num(caster.stat("Str"), 10, "EndAbility removed the scoped modifier")

func test_passive_turns_on_at_the_checkpoint() -> void:
	var f := Fixture.new()
	var attacker: Entity = f.unit("Attacker", 0, 0, 0, 100)
	var berserker: Entity = f.unit("Berserker", 1, 1, 0, 100, [["Str", 10]])
	berserker.passives.append(mk(PassiveInstance.new(), {def = mk(PassiveDef.new(), {name = "Berserker", condition = "Self.HpPct < 0.5",
		modifiers = [Modifier.new("Str", ModKind.Flat, "20")]})}))
	var strike: AbilityDef = mk(AbilityDef.new(), {name = "Strike", targeting = PatternDef.diamond("1"),
		steps = [mk(AttackStep.new(), {power = "60", can_miss = false, can_crit = false, on_hit = [DamageStep.new()]})]})

	f.resolver.cast(attacker, strike, Aim.at(attacker.pos, berserker.pos))

	assert_eq(berserker.hp, 40)
	assert_true(berserker.passives[0].active)
	assert_num(berserker.stat("Str"), 30)

func test_depth_limit_stops_a_heal_loop() -> void:
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var b: Entity = f.unit("B", 0, 1, 0, 100)
	var echo: ReactionDef = mk(ReactionDef.new(), {name = "Echo heal", trigger = Trigger.OnHealed, condition = "Target.IsAlly", ignore_tags = [],
		response = [mk(HealStep.new(), {amount = "1", on = StepTarget.EventSource})]})
	a.grant(echo)
	b.grant(echo)
	var heal: AbilityDef = mk(AbilityDef.new(), {name = "Heal", targeting = PatternDef.diamond("1"),
		steps = [mk(HealStep.new(), {amount = "1", on = StepTarget.Target})]})

	f.resolver.cast(a, heal, Aim.at(a.pos, b.pos))

	assert_true(f.log.warnings.any(func(w): return w.contains("exceeds 16")), str(f.log.warnings))
	assert_true(f.events(GameEventType.Healed).size() < 40)

func test_reaction_limits_and_chance_roll_once_per_attack() -> void:
	var f := Fixture.new()
	var attacker: Entity = f.unit("Attacker", 0, 0, 0, 100)
	var target: Entity = f.unit("Target", 1, 1, 0, 1000)
	target.grant(mk(ReactionDef.new(), {name = "Brace", trigger = Trigger.OnHitTaken, limit = Limit.OncePerAbility,
		response = [mk(HealStep.new(), {amount = "1", on = StepTarget.Self})]}))
	var flurry: AbilityDef = mk(AbilityDef.new(), {name = "Flurry", targeting = PatternDef.diamond("1"),
		steps = [mk(AttackStep.new(), {power = "10", can_miss = false, can_crit = false, hits = "3", on_hit = [DamageStep.new()]})]})

	f.resolver.cast(attacker, flurry, Aim.at(attacker.pos, target.pos))

	assert_eq(f.events(GameEventType.DamageDealt).size(), 3)
	assert_eq(f.events(GameEventType.Healed).size(), 1, "OncePerAbility")
	assert_true(f.events(GameEventType.DamageDealt).all(func(d): return d.facts["Damage"] == 10.0), "every hit reads the frozen ActionPower")

func _storm_run() -> String:
	var f := Fixture.new(10, 10, 777)
	f.rules.hit_chance = Formula.new("0.5")
	f.rules.crit_chance = Formula.new("0.3")
	var mage: Entity = f.unit("Mage", 0, 0, 0, 100)
	for i in 5: f.unit("T%d" % i, 1, 5 + i % 2, 5 + i / 2, 300)
	var storm: AbilityDef = mk(AbilityDef.new(), {name = "Storm", targeting = PatternDef.diamond("20"),
		steps = [mk(AttackStep.new(), {area = PatternDef.square("2"), power = "rand(40, 60)", hits = "3", on_hit = [DamageStep.new()]})]})
	f.resolver.cast(mage, storm, Aim.at(mage.pos, Vector2i(5, 6)))
	return f.dump()

func test_same_seed_writes_the_same_log() -> void:
	var first := _storm_run()
	assert_eq(_storm_run(), first)
	assert_true(first.contains("HitResolved"))

func test_pattern_sizes_match_the_design() -> void:
	var f := Fixture.new(21, 21)
	var caster: Entity = f.unit("Caster", 0, 10, 10, 100)
	var count := func(p: PatternDef) -> int: return Targeting.tiles(f.state, caster, p, caster.pos, Dirs.NONE, null).size()

	assert_eq(count.call(PatternDef.diamond("3")), 25)
	assert_eq(count.call(PatternDef.circle("3")), 37)
	assert_eq(count.call(PatternDef.square("3")), 49)
	assert_eq(count.call(PatternDef.circle("2")), 21, "the +0.5 rule tells small circles apart from Diamond (13)")
	assert_eq(count.call(PatternDef.plus("1")), 5)
	assert_eq(count.call(PatternDef.diamond("3", "1")), 24, "minRadius > 0 makes a ring")
	assert_eq(count.call(PatternDef.single()), 1)

	caster.grant(Modifier.new("MaxRadius", ModKind.Flat, "1")) # an area buff
	assert_eq(count.call(PatternDef.diamond("0")), 5, "radius 0 grows into an area")
	assert_eq(count.call(PatternDef.single()), 1, "Single never does")

func test_circles_take_decimal_radii_between_the_whole_ones() -> void:
	var f := Fixture.new(21, 21)
	var caster: Entity = f.unit("Caster", 0, 10, 10, 100)
	var count := func(p: PatternDef) -> int: return Targeting.tiles(f.state, caster, p, caster.pos, Dirs.NONE, null).size()

	assert_eq(count.call(PatternDef.circle("1")), 9, "whole radii unchanged")
	assert_eq(count.call(PatternDef.circle("2")), 21)
	assert_eq(count.call(PatternDef.circle("3")), 37)
	assert_eq(count.call(PatternDef.circle("1.5")), 13, "the 3×3 block and the four tiles two steps away")
	assert_eq(count.call(PatternDef.circle("1.9")), 21, "1.9 reaches (2, 1) like radius 2")
	assert_eq(count.call(PatternDef.circle("0.5")), 5, "0.5: the centre and its four neighbours")
	assert_eq(count.call(PatternDef.circle("0.4")), 1)
	assert_eq(count.call(PatternDef.circle("3 / 2")), 13, "a formula may give a decimal radius")

func test_cast_gate_explains_why() -> void:
	var f := Fixture.new()
	var u: Entity = f.unit("U", 0, 0, 0, 100)
	var rage: AbilityDef = mk(AbilityDef.new(), {name = "Rage", cast_gate = "Self.HpPct < 0.3"})

	var reason := []
	assert_false(Targeting.can_cast(f.state, u.id, rage, reason))
	assert_eq(reason[0] if reason.size() > 0 else null, "Requires Self.HpPct < 0.3")
	u.hp = 20
	assert_true(Targeting.can_cast(f.state, u.id, rage, reason))

func test_clone_is_independent() -> void:
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var b: Entity = f.unit("B", 1, 1, 0, 100)
	var copy: GameState = f.state.clone()
	var strike: AbilityDef = mk(AbilityDef.new(), {name = "Strike", targeting = PatternDef.diamond("1"),
		steps = [mk(AttackStep.new(), {power = "30", can_miss = false, can_crit = false, on_hit = [DamageStep.new()]})]})

	Resolver.new(copy).cast(copy.get_entity(a.id), strike, Aim.at(a.pos, b.pos))

	assert_eq(copy.get_entity(b.id).hp, 70)
	assert_eq(b.hp, 100, "the original state is untouched")
