class_name AttackEndEffect
extends Effect

func _kind() -> int: return EffectKind.Other
func is_valid(_s: GameState) -> bool: return true

func apply(ctx: ResolveContext) -> void:
	var e := GameEvent.new()
	e.type = GameEventType.AttackEnded
	e.source = attack.caster
	e.tags = tags.duplicate()
	ctx.write(self, e)
