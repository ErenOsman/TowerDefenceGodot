extends TestCase
## Port of AbilityTagTests.cs — an ability's result tags (AbilityText.tags): what its formulas give for a caster, named by what they are.

static func mk(obj, props: Dictionary = {}):
	return preload("res://tests/test_combat.gd").mk(obj, props)

func test_tags_name_the_results_of_the_formulas() -> void:
	var f := Fixture.new()
	var def: EntityDef = mk(EntityDef.new(), {name = "Archer", kind = EntityKind.Unit}).stat("MaxHp", 20).stat("Power", 10).stat("Range", 2).stat("Duration", 2)
	var archer: Entity = f.state.create(def, 0, Vector2i(0, 0))
	var volley: AbilityDef = mk(AbilityDef.new(), {name = "Volley", targeting = PatternDef.diamond("Self.Range"),
		steps = [mk(AttackStep.new(), {power = "Self.Power", hits = "3", area = PatternDef.diamond("1"),
			on_hit = [DamageStep.new(), mk(ApplyStatusStep.new(), {status = mk(StatusDef.new(), {name = "Burn"}), duration = "Self.Duration"})]})]})

	var tags: Array = AbilityText.tags(volley, archer, f.state.vocab)

	assert_seq(tags, [["10", "Damage"], ["2", "Range"], ["1", "Area"], ["3", "Hits"], ["2", "Duration"]])

func test_a_fixed_duration_is_no_tag_and_a_healing_hit_is_heal() -> void:
	var f := Fixture.new()
	var priest: Entity = f.state.create(mk(EntityDef.new(), {name = "Priest", kind = EntityKind.Unit}).stat("MaxHp", 20).stat("Potency", 8), 0, Vector2i(0, 0))
	var mend: AbilityDef = mk(AbilityDef.new(), {name = "Mend", targeting = PatternDef.diamond("2"),
		steps = [mk(AttackStep.new(), {power = "Self.Potency",
			on_hit = [HealStep.new(), mk(ApplyStatusStep.new(), {status = mk(StatusDef.new(), {name = "Haste"}), duration = "1"})]})]})

	var tags: Array = AbilityText.tags(mend, priest, f.state.vocab)

	assert_seq(tags, [["8", "Heal"], ["2", "Range"]])
