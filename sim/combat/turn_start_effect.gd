class_name TurnStartEffect
extends Effect
## Refreshes action and movement points, restores mana per GameRules, then writes TurnStarted.

## Whether the turn start drops the unit's cooldowns (enemies' drop with the towers', at the player phase).
var tick_cooldowns: bool = true

func _kind() -> int: return EffectKind.Other

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var u: Entity = s.get_entity(target_id)
	u.turns_taken += 1          # before the TurnStarted reactions, which may read it ("every second turn")
	u.fired_this_turn.clear()   # OncePerTurn resets at the owner's own TurnStarted
	if tick_cooldowns: CooldownTickEffect.tick(u)

	for r in ["Ap", "Mp"]:
		var max_stat: String = Entity.max_stat_of(r)
		if u.base_stats.has(max_stat): u.resources[r] = Num.floor_to_int(s.final_stat(u, max_stat))
	if u.base_stats.has("MaxMana"):
		var ectx := EvalContext.new()
		ectx.self_ = u
		ectx.source = u
		ectx.target = u
		ectx.rng = s.rng
		ectx.mode = ctx.resolver.mode
		var regen: int = Effect.floor_int(s.rules.mana_regen.evaluate(s.vocab, ectx), Round.FloorMin0)
		u.resources["Mana"] = mini(u.resource("Mana") + regen, Num.floor_to_int(s.final_stat(u, "MaxMana")))

	var e := GameEvent.new()
	e.type = GameEventType.TurnStarted
	e.source = target_id
	e.target = target_id
	ctx.write(self, e)
