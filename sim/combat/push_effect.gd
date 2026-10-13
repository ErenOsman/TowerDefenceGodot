class_name PushEffect
extends Effect
## Forced move, one tile at a time; ignores CanMove. A wall or an entity stops it and writes Collision.

var distance: Formula = Formula.new("1")
var pull: bool = false
var origin: Vector2i

func _kind() -> int: return EffectKind.Push
func _name() -> String: return "Pull" if pull else "Push"

func is_valid(s: GameState) -> bool:
	return super.is_valid(s) and s.get_entity(target_id).on_board

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var src: Entity = s.get_entity(source)
	var target: Entity = s.get_entity(target_id)
	var ectx: EvalContext = ctx.eval(self, self_of(s), src, target, ctx.vars(self))
	var dist: int = Effect.floor_int(distance.evaluate(s.vocab, ectx), Round.FloorMin0)

	var dir: Vector2i = Dirs.between(origin, target.pos)
	if pull: dir = Dirs.reverse(dir)
	if Dirs.is_none(dir): return

	for i in dist:
		var next: Vector2i = target.pos + dir
		if pull and next == origin: break
		var blocker: Entity = s.entity_at(next)
		if s.grid.blocks_movement(next) or blocker != null:
			var c := GameEvent.new()
			c.type = GameEventType.Collision
			c.source = source
			c.target = target_id
			c.from = target.pos
			c.to = next
			c.detail = ("with " + blocker.name) if blocker != null else "with wall"
			c.tags = tags.duplicate()
			c.facts["TilesLeft"] = float(dist - i)
			ctx.write(self, c)
			break
		ctx.move(self, target, next, name)
