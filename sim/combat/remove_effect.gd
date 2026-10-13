class_name RemoveEffect
extends Effect
## Takes an entity out of the battle without a death: no OnDeath, no OnKill.

var reason: String = "removed"

func _kind() -> int: return EffectKind.Remove

func is_valid(s: GameState) -> bool:
	var t: Entity = s.get_entity(target_id)
	return t != null and t.life != LifeState.Removed and not t.is_environment

func apply(ctx: ResolveContext) -> void:
	var target: Entity = ctx.state.get_entity(target_id)
	target.life = LifeState.Removed
	target.position = null
	var e := GameEvent.new()
	e.type = GameEventType.EntityRemoved
	e.source = source
	e.target = target_id
	e.detail = reason
	ctx.write(self, e)
