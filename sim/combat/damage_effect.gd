class_name DamageEffect
extends Effect
## OnHit amount, outgoing Damage modifiers, crit, Mitigation, incoming FinalDamage modifiers, shields, HP.

var amount: Formula = Formula.new()

func _kind() -> int: return EffectKind.Damage

## Only entities with HP take damage (hazards and HP-less objects do not).
func is_valid(s: GameState) -> bool:
	return super.is_valid(s) and s.get_entity(target_id).has_hp

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var src: Entity = s.get_entity(source)
	var target: Entity = s.get_entity(target_id)
	var vars: Dictionary = ctx.vars(self)
	var ectx: EvalContext = ctx.eval(self, self_of(s), src, target, vars)

	# OnHit: Damage, with outgoing modifiers; ×crit; floored at the slot output
	var damage: float = amount.evaluate(s.vocab, ectx)
	damage = ModifierPipeline.apply(damage, s.value_modifiers("Damage", src, null, tags, ability, vars), null, null, ectx.trace, "Damage")
	if chain != null and chain.var_("IsCrit"):
		damage = Num.mul(damage, s.rules.crit_multiplier.evaluate(s.vocab, ectx))
	damage = Rounding.apply(damage, Round.FloorMin0)

	# Mitigation: FinalDamage, with incoming modifiers; floored at the slot output
	vars["Damage"] = damage
	var final: float = s.rules.mitigation.evaluate(s.vocab, ectx)
	final = ModifierPipeline.apply(final, s.value_modifiers("FinalDamage", null, target, tags, ability, vars), null, null, ectx.trace, "FinalDamage")
	final = Rounding.apply(final, Round.FloorMin0)
	var remaining: int = Num.floor_to_int(final)

	# Shields: pools drain newest first; an empty pool removes its status
	var absorbed := 0
	var i: int = target.statuses.size() - 1
	while i >= 0 and remaining > 0:
		var st: StatusInstance = target.statuses[i]
		i -= 1
		if not st.active or st.pool <= 0: continue
		var take: int = mini(st.pool, remaining)
		st.pool -= take
		if st.def.stacks_are_shield: st.stacks = st.pool # a Shield's stacks are its points
		remaining -= take
		absorbed += take
		if st.pool == 0: ctx.remove_status(self, target, st)

	# HP: never below 0; whoever brings it to 0 gets the kill (never the Environment)
	var before: int = target.hp
	var hp_lost: int = mini(before, remaining)
	target.hp = before - hp_lost
	if hp_lost > 0: target.last_damaged_round = s.round
	if before > 0 and target.hp == 0: target.hp_zero_by = -1 if src.is_environment else source
	var overkill: int = remaining - hp_lost

	var facts := {
		"Damage": damage,
		"FinalDamage": final,
		"Absorbed": float(absorbed),
		"HpLost": float(hp_lost),
		"Overkill": float(overkill),
	}
	ctx.set_results(self, facts)
	var e := GameEvent.new()
	e.type = GameEventType.DamageDealt
	e.source = source
	e.target = target_id
	e.tags = tags.duplicate()
	for k in facts: e.facts[k] = facts[k]
	ctx.write(self, e)
