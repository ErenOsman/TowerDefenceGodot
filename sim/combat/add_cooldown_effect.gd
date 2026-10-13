class_name AddCooldownEffect
extends Effect
## Adds turns to a unit's cooldowns (one ability, or all but the one being cast) and writes CooldownChanged.

var which: AbilityDef
var casting: AbilityDef
var turns: Formula = Formula.new()

func _kind() -> int: return EffectKind.Other

func is_valid(s: GameState) -> bool:
	var t: Entity = s.get_entity(target_id)
	return t != null and t.life != LifeState.Removed

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var t: Entity = s.get_entity(target_id)
	var who: Entity = step_context.self_ if step_context != null and step_context.self_ != null else t
	var ectx: EvalContext = ctx.eval(self, who, s.get_entity(source), t, ctx.vars(self))
	var by: int = 1 if turns.is_empty else maxi(0, Effect.floor_int(turns.evaluate(s.vocab, ectx)))
	if by == 0: return
	var changed := false
	for a in t.abilities:
		if (a != which) if which != null else (a == casting): continue
		var now: int = t.cooldown(a)
		if now == Entity.HeldCooldown: continue
		t.cooldowns[a] = now + by
		changed = true
	if changed:
		var e := GameEvent.new()
		e.type = GameEventType.CooldownChanged
		e.source = source
		e.target = t.id
		e.detail = which.name if which != null else ""
		ctx.write(self, e)
