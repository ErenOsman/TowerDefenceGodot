extends TestCase
## Port of StatusTests.cs — status tags per application (Hidden, Permanent), cleanses by tag, PerSource stacking and its summary.

static func mk(obj, props: Dictionary = {}):
	return preload("res://tests/test_combat.gd").mk(obj, props)

static func apply_ability(status: StatusDef, stacks: String = "1", duration: String = "", add_tags: Array = []) -> AbilityDef:
	return mk(AbilityDef.new(), {name = "Apply " + status.name, targeting = PatternDef.diamond("5"),
		steps = [mk(ApplyStatusStep.new(), {status = status, stacks = stacks, duration = duration, add_tags = add_tags})]})

static func cleanse(tag: String, limit: int = 0) -> AbilityDef:
	return mk(AbilityDef.new(), {name = "Cleanse", targeting = PatternDef.diamond("5"),
		steps = [mk(RemoveStatusStep.new(), {by = RemoveBy.Tag, tag = tag, limit = limit})]})

static func poison() -> StatusDef:
	return mk(StatusDef.new(), {name = "Poison", tags = [Tags.Poison, Tags.Debuff], stacking = Stacking.PerSource, duration = 4,
		reactions = [mk(ReactionDef.new(), {name = "Tick", trigger = Trigger.OnTurnStart,
			response = [mk(DamageStep.new(), {amount = "StatusStacks", on = StepTarget.Self, tags = [Tags.Poison]})]})]})

func test_burn_takes_its_stacks_from_the_casters_potency() -> void:
	# the Mage's Firebolt: hits for Power, then burns for Potency each turn (Burn: Replace, 2 turns)
	var f := Fixture.new()
	var mage: Entity = f.unit("Mage", 0, 0, 0, 100, [["Power", 8], ["Potency", 2]])
	var slime: Entity = f.unit("Slime", 1, 3, 0, 100)
	var burn: StatusDef = mk(StatusDef.new(), {name = "Burn", tags = [Tags.Fire, Tags.Debuff], stacking = Stacking.Replace, duration = 2,
		reactions = [mk(ReactionDef.new(), {name = "Burn Tick", trigger = Trigger.OnTurnStart,
			response = [mk(DamageStep.new(), {amount = "StatusStacks", on = StepTarget.Self, tags = [Tags.Fire]})]})]})
	var firebolt: AbilityDef = mk(AbilityDef.new(), {name = "Firebolt", targeting = PatternDef.diamond("3"),
		steps = [mk(AttackStep.new(), {power = "Self.Power", can_miss = false, can_crit = false,
			on_hit = [DamageStep.new(), mk(ApplyStatusStep.new(), {status = burn, stacks = "Self.Potency"})]})]})

	f.resolver.cast(mage, firebolt, Aim.at(mage.pos, slime.pos))
	assert_eq(slime.hp, 92, "the hit: Power 8")
	assert_eq(slime.stacks("Burn"), 2, "burns for the caster's Potency")

	f.resolver.start_turn(slime)
	assert_eq(slime.hp, 90, "first tick")
	f.resolver.end_turn(slime)
	f.resolver.start_turn(slime)
	assert_eq(slime.hp, 88, "second tick")
	f.resolver.end_turn(slime)
	assert_false(slime.has_status("Burn"), "gone after 2 turns")

	f.resolver.cast(mage, firebolt, Aim.at(mage.pos, slime.pos))
	f.resolver.cast(mage, firebolt, Aim.at(mage.pos, slime.pos))
	assert_eq(slime.stacks("Burn"), 2, "a second Firebolt starts it over, it does not add up")

func test_turns_formula_reads_the_casters_duration() -> void:
	# Apply Status duration = Self.Duration: how long it lasts comes from the caster (empty: the status's own)
	var f := Fixture.new()
	var caster: Entity = f.unit("Caster", 0, 0, 0, 100, [["Duration", 3]])
	var t: Entity = f.unit("T", 1, 2, 0, 100)
	var mark: StatusDef = mk(StatusDef.new(), {name = "Mark", tags = [Tags.Debuff], duration = 1})
	var apply: AbilityDef = mk(AbilityDef.new(), {name = "Mark", targeting = PatternDef.diamond("5"),
		steps = [mk(ApplyStatusStep.new(), {status = mark, duration = "Self.Duration"})]})

	f.resolver.cast(caster, apply, Aim.at(caster.pos, t.pos))
	assert_eq(t.statuses.size(), 1)
	if t.statuses.size() == 1: assert_eq(t.statuses[0].turns_left, 3)
	caster.grant(Modifier.new("Duration", ModKind.Flat, "2"))
	f.resolver.cast(caster, apply, Aim.at(caster.pos, t.pos))
	assert_eq(t.statuses.size(), 1)
	if t.statuses.size() == 1: assert_eq(t.statuses[0].turns_left, 5, "a Duration boost makes it last longer")

func test_every_second_turn_reads_turns_taken() -> void:
	# the Rabbit's Quicken: on its own second, fourth… turn it gains Haste (+1 Speed, at most 2)
	var f := Fixture.new()
	var rabbit: Entity = f.unit("Rabbit", 1, 0, 0, 30, [["Speed", 2]])
	var haste: StatusDef = mk(StatusDef.new(), {name = "haste", stacking = Stacking.Stack, max_stacks = 2,
		modifiers = [Modifier.new("Speed", ModKind.Flat, "Self.Stacks(haste)")]})
	rabbit.grant(mk(ReactionDef.new(), {name = "Quicken", trigger = Trigger.OnTurnStart, condition = "Self.TurnsTaken % 2 == 0",
		response = [mk(ApplyStatusStep.new(), {status = haste, on = StepTarget.Self})]}))

	var speeds := []
	for turn in range(1, 7):
		f.resolver.start_turn(rabbit)
		assert_eq(rabbit.turns_taken, turn)
		speeds.append(Num.floor_to_int(f.state.final_stat(rabbit, "Speed")))
		f.resolver.end_turn(rabbit)
	assert_seq(speeds, [2, 3, 3, 4, 4, 4], "faster on every second turn, capped at +2")

func test_per_source_keeps_one_instance_per_applier() -> void:
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var b: Entity = f.unit("B", 0, 1, 0, 100)
	var t: Entity = f.unit("T", 1, 3, 0, 100)
	var p: StatusDef = poison()

	f.resolver.cast(a, apply_ability(p, "5"), Aim.at(a.pos, t.pos))
	f.resolver.cast(b, apply_ability(p, "5", "6"), Aim.at(b.pos, t.pos))
	f.resolver.cast(a, apply_ability(p, "2"), Aim.at(a.pos, t.pos)) # A stacks into its own

	assert_eq(t.statuses.size(), 2)
	assert_eq(t.stacks("Poison"), 12)
	var sums: Array = t.status_summaries()
	assert_eq(sums.size(), 1)
	if sums.size() == 1:
		var sum: StatusSummary = sums[0]
		assert_eq(sum.stacks, 12, "the card: total stacks")
		assert_eq(sum.turns_left, 6, "the card: longest duration")
		assert_seq(sum.instances.map(func(i): return i.applied_by), [a.id, b.id], "the details: each applier")

	# each instance ticks its own stacks for its own applier
	f.resolver.start_turn(t)
	var ticks: Array = f.events(GameEventType.DamageDealt)
	assert_set(ticks.map(func(e): return [e.source, Num.floor_to_int(e.facts["FinalDamage"])]), [[a.id, 7], [b.id, 5]], f.dump())
	assert_eq(t.hp, 88)

	for i in 4: f.resolver.end_turn(t)
	assert_eq(t.statuses.size(), 1)
	if t.statuses.size() == 1: assert_eq(t.statuses[0].applied_by, b.id, "A's expired after 4 turns, B's lasts 6")

func test_hidden_is_per_application_and_shown_wins() -> void:
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var t: Entity = f.unit("T", 1, 2, 0, 100)
	var fire: StatusDef = mk(StatusDef.new(), {name = "Fire", tags = [Tags.Fire, Tags.Debuff]})

	f.resolver.cast(a, apply_ability(fire, "1", "", [Tags.Hidden]), Aim.at(a.pos, t.pos))
	assert_true(t.has_status("Fire"), "rules see a hidden status")
	assert_true(t.status_summaries().is_empty(), "the UI does not")
	assert_eq(t.status_summaries(true).size(), 1)

	f.resolver.cast(a, apply_ability(fire, "1", "", [Tags.Hidden]), Aim.at(a.pos, t.pos))
	assert_eq(t.statuses.size(), 1)
	assert_true(t.statuses[0].is_hidden, "hidden + hidden stays hidden")

	f.resolver.cast(a, apply_ability(fire), Aim.at(a.pos, t.pos))
	assert_false(t.statuses[0].is_hidden, "once shown, it stays shown")
	var sums: Array = t.status_summaries()
	assert_eq(sums.size(), 1)
	if sums.size() == 1: assert_eq(sums[0].stacks, 3)

	f.resolver.cast(a, apply_ability(fire, "1", "", [Tags.Hidden]), Aim.at(a.pos, t.pos))
	assert_false(t.statuses[0].is_hidden, "a hidden application does not hide a shown status")

func test_cleanse_by_tag_skips_permanent_and_respects_the_limit() -> void:
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var t: Entity = f.unit("T", 1, 2, 0, 100)
	var weak: StatusDef = mk(StatusDef.new(), {name = "Weak", tags = [Tags.Debuff]})
	var slow: StatusDef = mk(StatusDef.new(), {name = "Slow", tags = [Tags.Debuff]})
	var curse: StatusDef = mk(StatusDef.new(), {name = "Curse", tags = [Tags.Debuff, Tags.Permanent]})
	var mark: StatusDef = mk(StatusDef.new(), {name = "Mark", tags = [Tags.Debuff]})
	var haste: StatusDef = mk(StatusDef.new(), {name = "Haste", tags = [Tags.Buff]})

	for st in [weak, curse, haste, slow]:
		f.resolver.cast(a, apply_ability(st), Aim.at(a.pos, t.pos))
	f.resolver.cast(a, apply_ability(mark, "1", "", [Tags.Permanent]), Aim.at(a.pos, t.pos)) # permanent for this application only

	f.resolver.cast(a, cleanse(Tags.Debuff, 1), Aim.at(a.pos, t.pos))
	assert_false(t.has_status("Slow"), "newest debuff first")
	assert_true(t.has_status("Weak"))

	f.resolver.cast(a, cleanse(Tags.Debuff), Aim.at(a.pos, t.pos))
	assert_set(t.statuses.map(func(s): return s.def.name), ["Curse", "Haste", "Mark"])

	var remove_curse: AbilityDef = mk(AbilityDef.new(), {name = "Lift Curse", targeting = PatternDef.diamond("5"),
		steps = [mk(RemoveStatusStep.new(), {by = RemoveBy.Name, status_name = "Curse"})]})
	f.resolver.cast(a, remove_curse, Aim.at(a.pos, t.pos))
	assert_false(t.has_status("Curse"), "removal by name still works on Permanent")

func test_the_shield_status_is_its_stacks() -> void:
	# the common Shield: one point per stack. A Slime arrives with 10 and refills to 10; a Rockjaw gains 100 per eaten rock
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var t: Entity = f.unit("T", 1, 2, 0, 100)
	var shield: StatusDef = mk(StatusDef.new(), {name = "shield", tags = [Tags.Buff], stacking = Stacking.Stack, max_stacks = 9999, duration = -1, shield_pool = "Stacks"})
	var give := func(stacks: String) -> AbilityDef:
		return mk(AbilityDef.new(), {name = "Give", targeting = PatternDef.diamond("5"), steps = [mk(ApplyStatusStep.new(), {status = shield, stacks = stacks})]})

	f.resolver.cast(a, give.call("100"), Aim.at(a.pos, t.pos))
	f.resolver.cast(a, give.call("100"), Aim.at(a.pos, t.pos))
	assert_eq(t.shield, 200, "applications add up")
	assert_eq(t.stacks("shield"), 200)

	var hit: AbilityDef = mk(AbilityDef.new(), {name = "Hit", targeting = PatternDef.diamond("5"), steps = [mk(DamageStep.new(), {amount = "195"})]})
	f.resolver.cast(a, hit, Aim.at(a.pos, t.pos))
	assert_eq(t.shield, 5)
	assert_eq(t.stacks("shield"), 5, "absorbed damage removes stacks")
	assert_eq(t.hp, 100)

	f.resolver.cast(a, give.call("10 - Target.Stacks(shield)"), Aim.at(a.pos, t.pos))
	assert_eq(t.stacks("shield"), 10, "refilled to 10")
	assert_eq(t.shield, 10)

func test_remove_by_name_can_take_off_some_stacks() -> void:
	# a Marked target: each triple shot uses one stack (Marked 2 → two triple shots)
	var f := Fixture.new()
	var a: Entity = f.unit("A", 0, 0, 0, 100)
	var t: Entity = f.unit("T", 1, 2, 0, 100)
	var marked: StatusDef = mk(StatusDef.new(), {name = "Marked", stacking = Stacking.Stack, max_stacks = 9})
	f.resolver.cast(a, apply_ability(marked, "3"), Aim.at(a.pos, t.pos))
	var use := func(stacks: String) -> AbilityDef:
		return mk(AbilityDef.new(), {name = "Use", targeting = PatternDef.diamond("5"), steps = [mk(RemoveStatusStep.new(), {status_name = "Marked", stacks = stacks})]})

	f.resolver.cast(a, use.call("1"), Aim.at(a.pos, t.pos))
	assert_eq(t.stacks("Marked"), 2)
	var removed: Array = f.events(GameEventType.StatusRemoved)
	assert_false(removed.is_empty(), f.dump())
	if removed.is_empty(): return
	assert_eq(int(removed[-1].facts["Stacks"]), 2, "the event says what is left")

	f.resolver.cast(a, use.call("Target.Stacks(Marked) + 5"), Aim.at(a.pos, t.pos))
	assert_false(t.has_status("Marked"), "more than it has removes it")
	assert_eq(int(f.events(GameEventType.StatusRemoved)[-1].facts["Stacks"]), 0)
