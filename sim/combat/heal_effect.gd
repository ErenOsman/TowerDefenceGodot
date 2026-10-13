class_name HealEffect
extends Effect

var amount: Formula = Formula.new()

func _kind() -> int: return EffectKind.Heal

func is_valid(s: GameState) -> bool:
	return super.is_valid(s) and s.get_entity(target_id).has_hp

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var src: Entity = s.get_entity(source)
	var target: Entity = s.get_entity(target_id)
	var vars: Dictionary = ctx.vars(self)
	var ectx: EvalContext = ctx.eval(self, self_of(s), src, target, vars)

	var a: float = amount.evaluate(s.vocab, ectx)
	a = ModifierPipeline.apply(a, s.value_modifiers("Heal", src, target, tags, ability, vars))
	var value: int = Effect.floor_int(a, Round.FloorMin0)
	var before: int = target.hp
	var healed: int = mini(value, maxi(0, target.max_hp - before))
	target.hp = before + healed

	var facts := { "Amount": float(healed), "Overheal": float(value - healed) }
	ctx.set_results(self, facts)
	var e := GameEvent.new()
	e.type = GameEventType.Healed
	e.source = source
	e.target = target_id
	e.tags = tags.duplicate()
	for k in facts: e.facts[k] = facts[k]
	ctx.write(self, e)
