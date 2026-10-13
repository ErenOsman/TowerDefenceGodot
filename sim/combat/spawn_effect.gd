class_name SpawnEffect
extends Effect
## Creates an entity from a definition with the next EntityId and writes EntitySpawned. A
## blocking entity on a taken tile goes to the nearest free tile within 1, or the effect fizzles.
## Spawning writes no EntityEnteredTile, so hazards on the tile wait for their next trigger.

var def: EntityDef
var tile: Vector2i
var summon: bool = false
var team: int = -1
## EntityId (int).
var owner: int = 0

## Placement: the tile must be free; no nearest-tile fallback (tower placement).
var exact_tile: bool = false

## For OnPath entities: the path to follow; -1 = the owner's path.
var path_id: int = -1

## The level wave the entity joins; -1 = the owner's wave.
var wave: int = -1

## The direction it starts facing; None = along its path where it appears (else the default).
var facing: Vector2i = Dirs.NONE

func _kind() -> int: return EffectKind.Spawn
func _name() -> String: return "Spawn " + (def.name if def != null else "")
func is_valid(_s: GameState) -> bool: return def != null

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var o: Entity = s.get_entity(owner)

	var pid: int = path_id if path_id >= 0 else (o.path_id if o != null else -1)
	var flying: bool = def.tags.has(Tags.Flying) # a flyer may appear over a chasm (a bat on a chasm path)
	var at = null # Vector2i or null
	if exact_tile:
		at = tile if s.is_free(tile) or not def.is_blocking and not s.grid.blocks_movement(tile) else null
	elif def.footing == Footing.OnPath and def.is_blocking:
		# a taken spawn tile: the nearest free tile of the entity's own path
		var path = s.grid.path(pid)
		var i: int = path.index_of(tile) if path != null else -1
		at = s.free_path_tile_near(pid, i, flying) if i >= 0 else null
	else:
		at = s.free_tile_near(tile, flying) if def.is_blocking else (tile if s.grid.can_stand_on(tile, flying) else null)
	if at == null:
		var f := GameEvent.new()
		f.type = GameEventType.Fizzled
		f.source = source
		f.detail = name + " (no free tile)"
		ctx.write(self, f)
		return

	var t: int = team
	if summon or team < 0:
		t = s.effective_team(o) if o != null and not o.is_environment else 0
	var e: Entity = s.create(def, t, at)
	if summon and o != null and not o.is_environment: e.summoner = o.id
	else: e.created_by = owner
	e.path_id = pid
	# its step: the visit nearest where it was meant to appear (a summon: its owner's step)
	var p = s.grid.path(pid)
	var near: int
	if o != null and o.path_id == pid: near = o.path_progress
	else: near = p.index_of(tile) if p != null else -1
	e.path_step = p.visit_near(at, near) if p != null else -1
	e.wave = wave if wave >= 0 else (o.wave if o != null else -1)
	# the starting direction is state, not a turn: it applies even while facing is disabled
	var dir: Vector2i = facing
	if Dirs.is_none(dir): dir = p.direction_at_step(e.path_step) if p != null else Dirs.NONE
	if not Dirs.is_none(dir): e.facing = dir

	var ev := GameEvent.new()
	ev.type = GameEventType.EntitySpawned
	ev.source = owner
	ev.target = e.id
	ev.detail = def.name
	ev.to = at
	ctx.write(self, ev)
