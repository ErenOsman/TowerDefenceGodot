class_name StepEffect
extends Effect
## Moves an entity one tile. Fizzles if the mover is dead, cannot move, or is no longer on From.

var from: Vector2i
var to: Vector2i

func _kind() -> int: return EffectKind.Step

func is_valid(s: GameState) -> bool:
	var u: Entity = s.get_entity(target_id)
	return u != null and u.on_board and u.can_move and u.pos == from and s.can_enter(u, to)

func apply(ctx: ResolveContext) -> void:
	var mover: Entity = ctx.state.get_entity(target_id)
	ctx.face(self, mover, Dirs.cardinal_between(from, to))
	ctx.move(self, mover, to, "Walk")
