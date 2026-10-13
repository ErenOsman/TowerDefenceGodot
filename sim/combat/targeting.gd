class_name Targeting
extends RefCounted
## Patterns resolved on the board: radii, tiles, routes, rays, line of sight, and the public queries
## (can_cast, valid_aims, is_valid_aim, area_targets, units_in).
## Tuples become Arrays: radii → [min, max]; tiles → Array of [Vector2i tile, int distance];
## routes → Array of [Vector2i tile, Array route]; ray → [Array route, hit (Vector2i or null)].
## C# `out string reason` → an optional `reason_out: Array`, resized to 1 and holding the reason (String or null);
## the reason is also left in the static `Targeting.last_reason` ("" when it passed).

## Resolves a pattern's radii at the Targeting phase, with MaxRadius modifiers filtered by tags. Returns [min, max].
static func radii(s: GameState, caster: Entity, p: PatternDef, tags) -> Array:
	var ctx := EvalContext.new()
	ctx.source = caster; ctx.self_ = caster; ctx.rng = s.rng; ctx.mode = EvalMode.PreviewMin
	var mn := Num.floor_to_int(Rounding.apply(p.min_radius.evaluate(s.vocab, ctx), Round.FloorMin0))
	var mx := p.max_radius.evaluate(s.vocab, ctx)
	mx = ModifierPipeline.apply(mx, s.value_modifiers("MaxRadius", caster, null, tags, null, null))
	return [mn, Num.floor_to_int(Rounding.apply(mx, Round.FloorMin0))]

## A Circle's exact radius (decimals kept, never below 0): a tile is inside when its distance from the
## centre is at most radius + ½, so whole radii give the round shapes of every other pattern
## (1 = the 3×3 block, 2 = 5×5 without corners) and 1.5 lies between. Other shapes use the whole-number radii.
static func circle_radius(s: GameState, caster: Entity, p: PatternDef, tags) -> float:
	var ctx := EvalContext.new()
	ctx.source = caster; ctx.self_ = caster; ctx.rng = s.rng; ctx.mode = EvalMode.PreviewMin
	var mx := p.max_radius.evaluate(s.vocab, ctx)
	mx = ModifierPipeline.apply(mx, s.value_modifiers("MaxRadius", caster, null, tags, null, null))
	return Num.max_of(0.0, mx)

## Whether a pattern reaches past its centre tile (an area of more than one tile).
static func reaches_past_center(s: GameState, caster: Entity, p: PatternDef, tags) -> bool:
	if p.shape == Shape.Custom: return true
	if p.shape == Shape.Circle: return _in_circle(1, 0, circle_radius(s, caster, p, tags))
	return radii(s, caster, p, tags)[1] > 0

## Whether an offset lies in a circle of the given radius: 4(dx² + dy²) ≤ (2r + 1)².
static func _in_circle(dx: int, dy: int, r: float) -> bool:
	var two_r_plus_one := Num.add(Num.mul(r, 2.0), 1.0)
	return float(4 * (dx * dx + dy * dy)) <= Num.mul(two_r_plus_one, two_r_plus_one)

## Tiles of a pattern around a centre, with their distance in the pattern's metric: Array of [Vector2i, int].
static func tiles(s: GameState, caster: Entity, p: PatternDef, center: Vector2i, dir: Vector2i, tags) -> Array:
	var result := []
	if p.shape == Shape.Single:
		if s.grid.in_bounds(center): result.append([center, 0])
		return result
	if p.shape == Shape.Ray:
		var r := ray(s, caster, p, center)
		if r[1] != null: result.append([r[1], r[0].size()])
		return result

	var rr := radii(s, caster, p, tags)
	var mn: int = rr[0]
	var mx: int = rr[1]

	if p.is_movement:
		for tr in routes(s, caster, p, center, mn, mx): result.append([tr[0], tr[1].size()])
		return result

	if p.shape == Shape.Custom:
		for off in p.custom:
			var t := Vector2i(center.x + off.x, center.y + off.y)
			if s.grid.in_bounds(t): result.append([t, absi(off.x) + absi(off.y)])
		return result

	if p.shape == Shape.Line:
		if dir == Vector2i.ZERO: return result
		for k in range(maxi(1, mn), mx + 1):
			var t := Vector2i(center.x + dir.x * k, center.y + dir.y * k)
			if s.grid.blocks_projectiles(t):
				if p.stop_at_first_blocker: break
				continue
			result.append([t, k])
			if p.stop_at_first_blocker and _blocks(s, caster, p, s.entity_at(t)): break
		return result

	var cone: Vector2i = Dirs.cardinal_between(Vector2i.ZERO, dir) if p.shape == Shape.Cone else Vector2i.ZERO
	if p.shape == Shape.Cone and cone == Vector2i.ZERO: return result

	# a circle keeps its exact radius (1.5 lies between 1 and 2); its reach is the radius rounded up
	var circle := p.shape == Shape.Circle
	var c_radius := circle_radius(s, caster, p, tags) if circle else 0.0
	var reach := Num.floor_to_int(Num.add(c_radius, 0.999999)) if circle else mx

	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if (not _in_circle(dx, dy, c_radius)) if circle else (not _in_shape(p.shape, dx, dy, mx, cone)): continue
			var d := p.distance(dx, dy, cone)
			if d == 0 and (not p.include_center or mn > 0): continue
			if d < mn or (not circle and d > mx): continue

			var t := Vector2i(center.x + dx, center.y + dy)
			if not s.grid.in_bounds(t): continue
			if p.requires_line_of_sight and not line_of_sight(s, center, t): continue
			result.append([t, d])
	return result

const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

## Reachable tiles of a movement shape with the route to each (excluding the start), nearest
## first: Array of [Vector2i tile, Array route]. The mover is the caster; it may enter only tiles
## its footing allows that are free.
static func routes(s: GameState, mover: Entity, p: PatternDef, center: Vector2i, mn: int, mx: int) -> Array:
	var result := []
	if mover == null: return result

	if p.shape == Shape.PathAhead:
		var path: PathDef = s.grid.path(mover.path_id)
		var start := -1
		if path != null:
			start = mover.path_progress if center == mover.pos else path.visit_near(center, mover.path_progress)
		if start < 0: return result
		var route := []
		for k in range(1, mx + 1):
			var i := start + k
			if i >= path.tiles.size() or not path.is_step(i): break
			if not s.can_enter(mover, path.tiles[i]):
				if not p.jumps_over_units or not s.can_stand(mover, path.tiles[i]): break
				route.append(path.tiles[i]) # hopped over: not a place to land
				continue
			route.append(path.tiles[i])
			if k >= mn: result.append([path.tiles[i], route.duplicate()])
		return result

	# Steps: breadth-first over enterable tiles, neighbours in a fixed order, so routes are deterministic
	var parent := {}
	var dist := {center: 0}
	var queue := [center]
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		var d: int = dist[at]
		if d >= mn and d > 0: result.append([at, _route_to(at, center, parent)])
		if d == mx: continue
		for n in NEIGHBOURS:
			var next: Vector2i = at + n
			if dist.has(next) or not s.can_enter(mover, next): continue
			dist[next] = d + 1
			parent[next] = at
			queue.append(next)
	return result

static func _route_to(tile: Vector2i, start: Vector2i, parent: Dictionary) -> Array:
	var route := []
	var at := tile
	while at != start:
		route.append(at)
		at = parent[at]
	route.reverse()
	return route

static func _in_shape(shape: int, dx: int, dy: int, r: int, cone: Vector2i) -> bool:
	var ax := absi(dx)
	var ay := absi(dy)
	match shape:
		Shape.Diamond: return ax + ay <= r
		Shape.Square: return ax <= r and ay <= r
		Shape.Circle: return 4 * (dx * dx + dy * dy) <= (2 * r + 1) * (2 * r + 1)
		Shape.Plus: return (dx == 0 or dy == 0) and ax + ay <= r
		Shape.Diagonal: return ax == ay and ax <= r
		Shape.Cone:
			var along := dx * cone.x + dy * cone.y
			var lateral := absi(dx * cone.y - dy * cone.x)
			return along >= 1 and along <= r and lateral <= along
		_: return false

static func _blocks_projectiles(e: Entity) -> bool:
	return e != null and (e.def == null or e.def.blocks_projectiles)

## Whether an entity stops a shot: it blocks projectiles, the caster can target it (stealthed and
## untargetable entities are passed through), and it is not an ally the pattern lets through.
static func _blocks(s: GameState, caster: Entity, p: PatternDef, e: Entity) -> bool:
	if not _blocks_projectiles(e) or e == caster: return false
	if caster != null and not e.is_targetable_by(caster): return false
	return not (p.passes_allies and caster != null and s.relation(caster, e) == Relation.Ally)

## A Ray from the caster to a tile (Bresenham, like line of sight): [the tiles it crosses, the tile
## it stops on — the first blocker, else the aimed tile; null when a wall stops it first].
static func ray(s: GameState, caster: Entity, p: PatternDef, to: Vector2i) -> Array:
	var route := []
	if caster == null or caster.pos == to: return [route, null]
	var from: Vector2i = caster.pos
	var x0 := from.x; var y0 := from.y; var x1 := to.x; var y1 := to.y
	var dx := absi(x1 - x0); var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1; var sy := 1 if y0 < y1 else -1; var err := dx + dy
	while x0 != x1 or y0 != y1:
		var e2 := 2 * err
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy
		var t := Vector2i(x0, y0)
		if s.grid.blocks_projectiles(t): return [route, null]
		route.append(t)
		if t != to and _blocks(s, caster, p, s.entity_at(t)): return [route, t]
	return [route, to]

## Bresenham line; terrain that blocks sight (walls) strictly between the two tiles blocks it.
static func line_of_sight(s: GameState, a: Vector2i, b: Vector2i) -> bool:
	var x0 := a.x; var y0 := a.y; var x1 := b.x; var y1 := b.y
	var dx := absi(x1 - x0); var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1; var sy := 1 if y0 < y1 else -1; var err := dx + dy
	while true:
		if (x0 != a.x or y0 != a.y) and (x0 != b.x or y0 != b.y) and s.grid.blocks_sight(Vector2i(x0, y0)): return false
		if x0 == x1 and y0 == y1: return true
		var e2 := 2 * err
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy
	return true

# ------------------------------------------------------------------ public queries

## The reason of the last can_cast / is_valid_aim call ("" when it passed), for callers that skip reason_out.
static var last_reason: String = ""

static func _set_reason(reason_out, reason) -> void:
	last_reason = "" if reason == null else reason
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = reason

## Cast gate and costs. reason_out[0] = the gate's failure text (null when castable).
static func can_cast(s: GameState, caster_id: int, a: AbilityDef, reason_out = null) -> bool:
	var reason = _can_cast(s, caster_id, a)
	_set_reason(reason_out, reason)
	return reason == null

static func _can_cast(s: GameState, caster_id: int, a: AbilityDef) -> Variant:
	var caster: Entity = s.get_entity(caster_id)
	if caster == null or not caster.alive: return "Caster is dead"
	if not caster.can_act: return "Cannot act"
	var cooldown: int = caster.cooldown(a)
	if cooldown == Entity.HeldCooldown: return "On cooldown until reset"
	if cooldown > 0: return "On cooldown (%d)" % cooldown
	if a.targeting.is_movement and not caster.can_move: return "Cannot move"
	if a.tags.has(Tags.Spell) and caster.has_tag(Tags.Silenced): return "Silenced"
	if a.tags.has(Tags.Attack) and caster.has_tag(Tags.Disarmed): return "Disarmed"
	for cost in a.costs:
		var have: int = caster.resource(cost.resource)
		if have < cost.amount: return "Not enough %s" % cost.resource
	var ctx := EvalContext.new()
	ctx.source = caster; ctx.self_ = caster; ctx.rng = s.rng
	return Condition.of(a.cast_gate).failure_reason(s.vocab, ctx)

## Targeting pattern around the caster, then the target filter. An ability with a target
## filter is single-target: the entity must be targetable by the caster (stealth, Untargetable)
## and, while the caster is Redirected, must be that status's applier. targetsDead aims at corpses.
## Returns an Array of Aim.
static func valid_aims(s: GameState, caster_id: int, a: AbilityDef) -> Array:
	var result := []
	var caster: Entity = s.get_entity(caster_id)
	var tags = Tags.set_of(a.tags)
	var redirector := redirected_to(s, caster)
	if a.targeting.is_movement:
		var rr := radii(s, caster, a.targeting, tags)
		for tr in routes(s, caster, a.targeting, caster.pos, rr[0], rr[1]):
			var aim := Aim.new(tr[0], Dirs.between(caster.pos, tr[0]))
			aim.path = tr[1]
			result.append(aim)
		return result
	var filter := Condition.of(a.target_filter)
	for td in tiles(s, caster, a.targeting, caster.pos, Vector2i.ZERO, tags):
		var tile: Vector2i = td[0]
		if a.needs_free_tile and (tile == caster.pos or not s.can_enter(caster, tile)): continue
		if a.targets_dead:
			var corpse: Entity = null
			for c in s.corpses_at(tile):
				if filter.is_empty or _passes(s, filter, caster, c):
					corpse = c
					break
			if corpse == null: continue
		elif not filter.is_empty:
			var u: Entity = s.entity_at(tile)
			if u == null or not u.is_targetable_by(caster): continue
			if redirector >= 0 and u.id != redirector: continue
			if not _passes(s, filter, caster, u): continue
		result.append(Aim.at(caster.pos, tile))
	return result

## Whether an aim is one the ability may take. Movement aims may carry any route (see RouteBuilder):
## for Steps it must start next to the caster, move one tile at a time through tiles the caster
## may enter, never revisit a tile and fit the reach; PathAhead routes must be the path itself.
## A movement aim without a route gets the shortest one (filled in here).
static func is_valid_aim(s: GameState, caster_id: int, a: AbilityDef, aim: Aim, reason_out = null) -> bool:
	var reason = _is_valid_aim(s, caster_id, a, aim)
	_set_reason(reason_out, reason)
	return reason == null

static func _is_valid_aim(s: GameState, caster_id: int, a: AbilityDef, aim: Aim) -> Variant:
	var caster: Entity = s.get_entity(caster_id)
	if caster == null or aim == null: return "No aim"
	var standard: Aim = null
	for v in valid_aims(s, caster_id, a):
		if v.tile == aim.tile:
			standard = v
			break
	if standard == null: return "Not a valid target"
	if not a.targeting.is_movement: return null
	if aim.path == null or aim.path.is_empty():
		aim.path = standard.path
		return null
	if a.targeting.shape == Shape.PathAhead:
		return null if aim.path == standard.path else "Enemies follow their path"

	var rr := radii(s, caster, a.targeting, Tags.set_of(a.tags))
	var lo := maxi(1, rr[0])
	if aim.path.size() < lo or aim.path.size() > rr[1]:
		return "Route length %d is outside %d–%d" % [aim.path.size(), lo, rr[1]]
	if aim.path[aim.path.size() - 1] != aim.tile: return "The route does not end on the aim"
	var seen := {caster.pos: true}
	var at: Vector2i = caster.pos
	for next in aim.path:
		if absi(at.x - next.x) + absi(at.y - next.y) != 1: return "%s is not next to %s" % [_pos_str(next), _pos_str(at)]
		if seen.has(next): return "The route crosses %s twice" % _pos_str(next)
		seen[next] = true
		if not s.can_enter(caster, next): return "%s cannot be entered" % _pos_str(next)
		at = next
	return null

## C# Pos.ToString(): "(x,y)".
static func _pos_str(p: Vector2i) -> String:
	return "(%d,%d)" % [p.x, p.y]

## The applier of the caster's newest active Redirected status, if still alive; otherwise -1 (None).
static func redirected_to(s: GameState, caster: Entity) -> int:
	for i in range(caster.statuses.size() - 1, -1, -1):
		var st = caster.statuses[i]
		if not st.active or not st.def.has_tag(Tags.Redirected): continue
		var applier: Entity = s.get_entity(st.applied_by)
		if applier != null and applier.alive and not applier.is_environment: return applier.id
	return -1

static func _passes(s: GameState, filter: Condition, caster: Entity, target: Entity) -> bool:
	if filter.is_empty: return true
	var ctx := EvalContext.new()
	ctx.source = caster; ctx.self_ = caster; ctx.target = target; ctx.rng = s.rng
	return filter.evaluate(s.vocab, ctx)

## Area pattern around the aim, then the area filter, in canonical order. A single-tile area
## is single-target (stealth applies); larger areas still hit stealthed entities. Array of entity ids.
static func area_targets(s: GameState, caster_id: int, atk: AttackStep, aim: Aim, tags) -> Array:
	var caster: Entity = s.get_entity(caster_id)
	var dir: Vector2i = caster.facing if atk.area.orientation == PatternOrientation.Facing else aim.dir
	var single: bool = atk.area.shape == Shape.Single or atk.area.shape == Shape.Ray \
		or not reaches_past_center(s, caster, atk.area, tags)
	return units_in(s, caster_id, atk.area, atk.area_filter, aim.tile, dir, tags, single)

## Targetable entities on a pattern's tiles that pass the filter, in canonical order:
## distance from the centre in the pattern's metric, then EntityId. Array of entity ids.
static func units_in(s: GameState, caster_id: int, pattern: PatternDef, filter, center: Vector2i, dir: Vector2i, tags, single_target := false) -> Array:
	var caster: Entity = s.get_entity(caster_id)
	var cond := Condition.of(filter)
	var found := []
	for td in tiles(s, caster, pattern, center, dir, tags):
		var u: Entity = s.entity_at(td[0])
		if u == null or not u.is_targetable_by(caster, single_target): continue
		if not _passes(s, cond, caster, u): continue
		found.append([u.id, td[1]])
	found.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	var ids := []
	for f in found: ids.append(f[0])
	return ids
