class_name TurnEndEffect
extends Effect
## Writes TurnEnded, then counts down the owner's turn-based statuses; a status at 0 is removed.

func _kind() -> int: return EffectKind.Other

func is_valid(s: GameState) -> bool:
	var t: Entity = s.get_entity(target_id)
	return t != null and t.life != LifeState.Removed

func apply(ctx: ResolveContext) -> void:
	var u: Entity = ctx.state.get_entity(target_id)
	var e := GameEvent.new()
	e.type = GameEventType.TurnEnded
	e.source = target_id
	e.target = target_id
	ctx.write(self, e)
	ctx.count_down(self, u, DurationUnit.Turns)
