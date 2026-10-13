class_name EndAbilityEffect
extends Effect

var instance: AbilityInstance
## EntityId (int).
var caster: int = -1

func _kind() -> int: return EffectKind.Other
func is_valid(_s: GameState) -> bool: return true

func apply(ctx: ResolveContext) -> void:
	instance.scoped.clear()
	ctx.state.open_abilities.erase(instance)
	var e := GameEvent.new()
	e.type = GameEventType.AbilityEnded
	e.source = caster
	e.detail = instance.def.name
	e.tags = instance.tags.duplicate()
	var ended: GameEvent = ctx.write(self, e)

	# AfterAbility reactions start now, as new roots
	for p in instance.deferred:
		ctx.push_all(ctx.resolver.expand_response(p, ended.id))
	instance.deferred.clear()
