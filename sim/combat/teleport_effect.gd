class_name TeleportEffect
extends Effect

var to: Vector2i

func _kind() -> int: return EffectKind.Teleport

func is_valid(s: GameState) -> bool:
	var u: Entity = s.get_entity(target_id)
	return u != null and u.on_board and s.can_enter(u, to)

## Skipped tiles see nothing: only the landing tile writes EntityMoved and EntityEnteredTile.
func apply(ctx: ResolveContext) -> void:
	ctx.move(self, ctx.state.get_entity(target_id), to, "Jump" if tags.has("Jump") else "Teleport")
