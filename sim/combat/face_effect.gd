class_name FaceEffect
extends Effect
## Turns an entity explicitly: in a set direction, along its own path, or towards a tile. Does
## nothing while facing is disabled in GameRules.

var toward: Vector2i

## When set, this direction instead of towards a tile.
var direction: Vector2i = Dirs.NONE

## The way the entity's path goes at its tile instead of towards a tile.
var along_path: bool = false

func _kind() -> int: return EffectKind.Other

func apply(ctx: ResolveContext) -> void:
	var e: Entity = ctx.state.get_entity(target_id)
	var dir: Vector2i
	if along_path:
		var path = ctx.state.grid.path(e.path_id)
		dir = path.direction_at_step(e.path_progress) if path != null else Dirs.NONE
	elif not Dirs.is_none(direction):
		dir = direction
	else:
		dir = Dirs.cardinal_between(e.pos, toward)
	ctx.face(self, e, dir)
