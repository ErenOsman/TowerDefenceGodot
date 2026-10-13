class_name RollHitEffect
extends Effect
## Rolls hit and crit for one chain; a miss ends the chain.

func _kind() -> int: return EffectKind.Other

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var step: AttackStep = attack.step
	var src: Entity = s.get_entity(source)
	var target: Entity = s.get_entity(target_id)
	var ectx: EvalContext = ctx.eval(self, src, src, target, ctx.vars(self))

	# a preview calculates: an uncertain hit lands; an uncertain crit does not (Roll fails uncertain rolls in previews)
	var hit_chance: float = s.rules.hit_chance.evaluate(s.vocab, ectx) if step.can_miss else 1.0
	var hit: bool = ctx.roll(hit_chance) if ctx.resolver.mode == EvalMode.Execute else hit_chance > 0.0
	var crit: bool = hit and step.can_crit and ctx.roll(s.rules.crit_chance.evaluate(s.vocab, ectx))

	chain.vars["Hit"] = Num.bool_num(hit)
	chain.vars["IsCrit"] = Num.bool_num(crit)
	if not hit: chain.stopped = true
