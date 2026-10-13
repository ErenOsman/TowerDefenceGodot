class_name ChangeTerrainEffect
extends Effect
## Sets the terrain (and maybe the build flag) of tiles (Tiles — Design), writing TileChanged for each tile that
## changes. A unit on a changed tile that can no longer stand there (a walker over a new chasm, anyone in a new
## wall) is pushed to the nearest tile it can enter when the new terrain says Push, else falls: it dies with
## the tag Fell (an object without HP is removed). Flyers stay over a chasm.

## Array of Vector2i.
var tiles: Array = []
var terrain: TerrainDef
var only_on: Array = []
var build: int = BuildChange.Keep

func _kind() -> int: return EffectKind.Other
func _name() -> String: return "ChangeTerrain " + (terrain.name if terrain != null else "")
func is_valid(_s: GameState) -> bool: return terrain != null

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var seen: Array = []
	for tile in tiles:
		if seen.has(tile): continue
		seen.append(tile)
		if not s.grid.in_bounds(tile): continue
		var old: TerrainDef = s.grid.terrain_at(tile)
		if only_on.size() > 0 and not only_on.has(old.name): continue
		var build_before: bool = s.grid.buildable.has(tile)
		var build_after: bool = build == BuildChange.On or build == BuildChange.Keep and build_before
		if old == terrain and build_before == build_after: continue

		s.grid.set_terrain(tile, terrain)
		if build_after: Effect.set_add(s.grid.buildable, tile)
		else: s.grid.buildable.erase(tile)
		var e := GameEvent.new()
		e.type = GameEventType.TileChanged
		e.source = source
		e.to = tile
		e.detail = "%s>%s" % [old.name, terrain.name]
		e.tags = tags.duplicate()
		e.facts["X"] = float(tile.x)
		e.facts["Y"] = float(tile.y)
		ctx.write(self, e)

		var on_tile: Array = []
		for u in s.entities:
			if u.on_board and u.pos == tile and not u.is_environment: on_tile.append(u)
		for u in on_tile:
			if s.grid.can_stand_on(tile, u.has_tag(Tags.Flying)): continue
			var to = ChangeTerrainEffect._nearest_enterable(s, u, tile) if terrain.when_unstandable == WhenUnstandable.Push else null
			if to != null:
				ctx.move(self, u, to, "Pushed")
				continue
			if u.has_hp:
				u.hp_zero_by = source
				u.death_tag = Tags.Fell
				u.hp = 0 # dies at the next checkpoint
			else:
				var r := RemoveEffect.new()
				r.target_id = u.id
				r.source = source
				r.reason = "fell"
				ctx.push(r)

## The nearest tile the unit may enter (by steps, then a fixed order), or null.
static func _nearest_enterable(s: GameState, u: Entity, from: Vector2i):
	var lim: int = s.grid.width + s.grid.height
	for d in range(1, lim + 1):
		for dy in range(-d, d + 1):
			var r: int = d - absi(dy)
			var dxs: Array = [-r] if r == 0 else [-r, r]
			for dx in dxs:
				var p := Vector2i(from.x + dx, from.y + dy)
				if s.grid.in_bounds(p) and s.can_enter(u, p): return p
	return null
