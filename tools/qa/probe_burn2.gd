extends SceneTree
## Burn 2 stacks / 2 turns, on a plain unit and on a Shield-Slime-like unit (shield 10, refilled to 10 at turn start).
func _initialize() -> void:
	var TC = preload("res://tests/test_combat.gd")
	for shielded in [false, true]:
		var f = Fixture.new()
		var mage: Entity = f.unit("Mage", 0, 0, 0, 100, [["Power", 8], ["Potency", 2]])
		var slime: Entity = f.unit("Slime", 1, 3, 0, 20)
		var shield: StatusDef = TC.mk(StatusDef.new(), {name = "shield", tags = [Tags.Buff], stacking = Stacking.Stack, max_stacks = 9999, duration = -1, shield_pool = "Stacks"})
		if shielded:
			# the Shielded passive's two reactions, as in Passives.json / Reactions.json
			slime.grant(TC.mk(ReactionDef.new(), {name = "Shield Refill", trigger = Trigger.OnTurnStart, condition = "Self.Stacks(shield) < 10",
				response = [TC.mk(ApplyStatusStep.new(), {status = shield, stacks = "10 - Self.Stacks(shield)", duration = "-1", on = StepTarget.Self})]}))
			var up: AbilityDef = TC.mk(AbilityDef.new(), {name = "Shield Up", targeting = PatternDef.diamond("5"),
				steps = [TC.mk(ApplyStatusStep.new(), {status = shield, stacks = "10", duration = "-1"})]})
			f.resolver.cast(mage, up, Aim.at(mage.pos, slime.pos))
		var burn: StatusDef = TC.mk(StatusDef.new(), {name = "Burn", tags = [Tags.Fire, Tags.Debuff], stacking = Stacking.Replace, duration = 2,
			reactions = [TC.mk(ReactionDef.new(), {name = "Burn Tick", trigger = Trigger.OnTurnStart,
				response = [TC.mk(DamageStep.new(), {amount = "StatusStacks", on = StepTarget.Self, tags = [Tags.Fire]})]})]})
		var ab: AbilityDef = TC.mk(AbilityDef.new(), {name = "Apply Burn", targeting = PatternDef.diamond("5"),
			steps = [TC.mk(ApplyStatusStep.new(), {status = burn, stacks = "2"})]})
		f.resolver.cast(mage, ab, Aim.at(mage.pos, slime.pos))
		print("=== %s: after applying Burn 2 (2 turns): hp %s shield %s burn %s" % ["SHIELD SLIME" if shielded else "PLAIN UNIT", slime.hp, slime.stacks("shield"), slime.stacks("Burn")])
		for turn in 3:
			var hp0 = slime.hp; var sh0 = slime.stacks("shield")
			f.resolver.start_turn(slime)
			print("turn %d start: hp %s -> %s, shield %s -> %s, burn stacks %s" % [turn + 1, hp0, slime.hp, sh0, slime.stacks("shield"), slime.stacks("Burn")])
			f.resolver.end_turn(slime)
			print("turn %d end:   burn %s" % [turn + 1, "still on" if slime.has_status("Burn") else "gone"])
	quit(0)
