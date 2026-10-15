extends SceneTree
## Scenario probe: Burn 10 + a poison dealing 50 % of missing HP, both ticking at turn start, in both application orders.
func _initialize() -> void:
	var TC = preload("res://tests/test_combat.gd")
	for order in [["burn", "poison"], ["poison", "burn"]]:
		var f = Fixture.new()
		var mage: Entity = f.unit("Mage", 0, 0, 0, 100, [["Power", 8], ["Potency", 10]])
		var slime: Entity = f.unit("Slime", 1, 3, 0, 100)
		var burn: StatusDef = TC.mk(StatusDef.new(), {name = "Burn", tags = [Tags.Fire, Tags.Debuff], stacking = Stacking.Replace, duration = 2,
			reactions = [TC.mk(ReactionDef.new(), {name = "Burn Tick", trigger = Trigger.OnTurnStart,
				response = [TC.mk(DamageStep.new(), {amount = "StatusStacks", on = StepTarget.Self, tags = [Tags.Fire]})]})]})
		var poison: StatusDef = TC.mk(StatusDef.new(), {name = "Poison", tags = [Tags.Poison, Tags.Debuff], stacking = Stacking.Replace, duration = 3,
			reactions = [TC.mk(ReactionDef.new(), {name = "Poison Tick", trigger = Trigger.OnTurnStart,
				response = [TC.mk(DamageStep.new(), {amount = "(Self.MaxHp - Self.Hp) * 0.5", on = StepTarget.Self, tags = [Tags.Poison]})]})]})
		var defs := {"burn": [burn, "10"], "poison": [poison, "1"]}
		for name in order:
			var ab: AbilityDef = TC.mk(AbilityDef.new(), {name = "Apply " + name, targeting = PatternDef.diamond("5"),
				steps = [TC.mk(ApplyStatusStep.new(), {status = defs[name][0], stacks = defs[name][1]})]})
			f.resolver.cast(mage, ab, Aim.at(mage.pos, slime.pos))
		print("--- applied in order %s: hp %s" % [", ".join(order), slime.hp])
		for turn in 2:
			var before = slime.hp
			f.resolver.start_turn(slime)
			print("turn %d start: hp %s -> %s (lost %s)" % [turn + 1, before, slime.hp, before - slime.hp])
			f.resolver.end_turn(slime)
	quit(0)
