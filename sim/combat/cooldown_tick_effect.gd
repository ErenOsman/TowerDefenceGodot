class_name CooldownTickEffect
extends Effect
## Drops a unit's cooldowns by one (held ones wait for a reset); writes CooldownChanged when any changed.

func _kind() -> int: return EffectKind.Other

func is_valid(s: GameState) -> bool:
	var t: Entity = s.get_entity(target_id)
	return t != null and t.alive

func apply(ctx: ResolveContext) -> void:
	var u: Entity = ctx.state.get_entity(target_id)
	if CooldownTickEffect.tick(u):
		var e := GameEvent.new()
		e.type = GameEventType.CooldownChanged
		e.source = target_id
		e.target = target_id
		e.detail = ""
		ctx.write(self, e)

## Drops every running cooldown by one; whether any changed.
static func tick(u: Entity) -> bool:
	var changed := false
	for a in u.cooldowns.keys():
		if u.cooldowns[a] > 0 and u.cooldowns[a] != Entity.HeldCooldown:
			u.cooldowns[a] -= 1
			changed = true
	return changed
