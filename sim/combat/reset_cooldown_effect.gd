class_name ResetCooldownEffect
extends Effect
## Frees (or shortens) a unit's cooldowns and writes CooldownChanged with the ability's name (empty = all).

var which: AbilityDef
var turns: Formula = Formula.new()

func _kind() -> int: return EffectKind.Other

func is_valid(s: GameState) -> bool:
	var t: Entity = s.get_entity(target_id)
	return t != null and t.life != LifeState.Removed

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var t: Entity = s.get_entity(target_id)
	var by: int = -1 # -1 = a full reset
	if not turns.is_empty:
		var who: Entity = step_context.self_ if step_context != null and step_context.self_ != null else t
		var ectx: EvalContext = ctx.eval(self, who, s.get_entity(source), t, ctx.vars(self))
		by = maxi(0, Effect.floor_int(turns.evaluate(s.vocab, ectx)))
	var changed := false
	for a in t.cooldowns.keys():
		if which != null and a != which: continue
		var now: int = t.cooldowns[a]
		var next: int = 0 if by < 0 else (now if now == Entity.HeldCooldown else maxi(0, now - by))
		if next == now: continue
		t.cooldowns[a] = next
		changed = true
	if changed:
		var e := GameEvent.new()
		e.type = GameEventType.CooldownChanged
		e.source = source
		e.target = t.id
		e.detail = which.name if which != null else ""
		ctx.write(self, e)
