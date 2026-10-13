class_name AimPreview
extends RefCounted
## What an ability would do, for UIs: its range, where it can be cast, and — for one aim — the area it
## would hit and the entities in it. Reads state only. Bounces, If branches and reactions are not
## predicted (they depend on the outcome).
## C# AimPreview.For → `for_aim` (`for` is a keyword). Inside this class the global range() wins over
## a method of the same name, so the static `range` delegates to `_range`.

## Tiles affected by the ability's attacks (or the aimed tile when it has no Attack step). Vector2i.
var area: Array = []

## Entities the attacks would hit (first batch), in hit order. Entity ids.
var targets: Array = []

## For Ray attacks: the tiles the shot crosses up to where it stops.
var line: Array = []

## For movement: the route to the aim.
var route: Array = []

## The tiles the ability's targeting pattern covers around the caster (its range), castable or not.
static func range(s: GameState, caster_id: int, a: AbilityDef) -> Array:
	return _range(s, caster_id, a)

static func _range(s: GameState, caster_id: int, a: AbilityDef) -> Array:
	var caster: Entity = s.get_entity(caster_id)
	if caster == null: return []
	var tags = Tags.set_of(a.tags)
	var result := []
	if a.targeting.is_movement:
		var rr := Targeting.radii(s, caster, a.targeting, tags)
		for tr in Targeting.routes(s, caster, a.targeting, caster.pos, rr[0], rr[1]): result.append(tr[0])
		return result
	var tiles := []
	for td in Targeting.tiles(s, caster, a.targeting, caster.pos, Vector2i.ZERO, tags): tiles.append(td[0])
	# cast on itself (e.g. Rally): what it reaches is the area of its Pick steps around it
	var all_self := true
	for t in tiles:
		if t != caster.pos:
			all_self = false
			break
	if all_self:
		for pick in a.steps:
			if pick is PickStep and pick.center == PickCenter.Self:
				for td in Targeting.tiles(s, caster, pick.area, caster.pos, Vector2i.ZERO, tags): tiles.append(td[0])
	for t in tiles:
		if not result.has(t): result.append(t)
	return result

## The tiles an aura (a passive's or status's filter, e.g. "Target.IsAlly and Self.DistanceTo(Target) <= 2")
## covers around its owner: where a unit of the owner's team or another team would be covered. Probes a copy of the state.
static func aura_range(s: GameState, owner_id: int, aura) -> Array:
	var tiles := []
	var cond := Condition.of(aura)
	var live: Entity = s.get_entity(owner_id)
	if cond.is_empty or live == null or not live.on_board: return tiles
	var copy: GameState = s.clone()
	var owner: Entity = copy.get_entity(owner_id)
	var probes := [copy.add_unit("Aura probe", owner.base_team, owner.pos, 1),
		copy.add_unit("Aura probe", 1 if owner.base_team == 0 else 0, owner.pos, 1)]
	var grid: BattleGrid = copy.grid
	for x in grid.width:
		for y in grid.height:
			var p := Vector2i(x, y)
			if p == owner.pos: continue
			for probe in probes:
				probe.position = p
				var ctx := EvalContext.new()
				ctx.self_ = owner; ctx.source = owner; ctx.target = probe; ctx.rng = copy.rng; ctx.mode = EvalMode.PreviewMin
				if not cond.evaluate(copy.vocab, ctx): continue
				tiles.append(p)
				break
	return tiles

## The tiles a PathAhead walk would reach if nothing stood in the way but cannot now (a unit or an
## occupied tile ahead stops it): the rest of its reach along the mover's path, up to a gap or the
## path's end. Empty for other shapes.
static func blocked(s: GameState, caster_id: int, a: AbilityDef) -> Array:
	var result := []
	var caster: Entity = s.get_entity(caster_id)
	if caster == null or a.targeting.shape != Shape.PathAhead: return result
	var path: PathDef = s.grid.path(caster.path_id)
	var start: int = -1 if path == null else caster.path_progress
	if start < 0: return result
	var rr := Targeting.radii(s, caster, a.targeting, Tags.set_of(a.tags))
	var reachable := {}
	for t in _range(s, caster_id, a): reachable[t] = true
	for k in range(maxi(1, rr[0]), rr[1] + 1):
		var i := start + k
		if i >= path.tiles.size() or not path.is_step(i): break
		if not reachable.has(path.tiles[i]): result.append(path.tiles[i])
	return result

## The area and targets of casting the ability at an aim (which should be one of its valid aims). C# For.
static func for_aim(s: GameState, caster_id: int, a: AbilityDef, aim: Aim) -> AimPreview:
	var preview := AimPreview.new()
	var caster: Entity = s.get_entity(caster_id)
	if caster == null or aim == null: return preview
	var tags = Tags.set_of(a.tags)

	if a.targeting.is_movement:
		if aim.path != null: preview.route.append_array(aim.path)
		preview.area.append(aim.tile)
		return preview

	var attacks := []
	for st in a.steps:
		if st is AttackStep: attacks.append(st)
	if attacks.is_empty():
		preview.area.append(aim.tile)
		var at: Entity = null
		if a.targets_dead:
			var corpses: Array = s.corpses_at(aim.tile)
			if not corpses.is_empty(): at = corpses[0]
		else:
			at = s.entity_at(aim.tile)
		if at != null: preview.targets.append(at.id)
		# Pick steps (e.g. Rally): their area around the caster or the aim, and the units in it their filter accepts
		for pick in a.steps:
			if not (pick is PickStep): continue
			var center: Vector2i = aim.tile if pick.center == PickCenter.Aim else caster.pos
			for td in Targeting.tiles(s, caster, pick.area, center, Vector2i.ZERO, tags):
				if not preview.area.has(td[0]): preview.area.append(td[0])
			for id in Targeting.units_in(s, caster_id, pick.area, pick.filter, center, Vector2i.ZERO, tags, false):
				if not preview.targets.has(id): preview.targets.append(id)
		return preview

	for atk in attacks:
		var attack_tags = Tags.union(tags, null)
		if atk.area.shape == Shape.Ray:
			var r := Targeting.ray(s, caster, atk.area, aim.tile)
			preview.line.append_array(r[0])
			if r[1] != null: preview.area.append(r[1])
		else:
			var dir: Vector2i = caster.facing if atk.area.orientation == PatternOrientation.Facing else aim.dir
			for td in Targeting.tiles(s, caster, atk.area, aim.tile, dir, attack_tags):
				if not preview.area.has(td[0]): preview.area.append(td[0])
		for id in Targeting.area_targets(s, caster_id, atk, aim, attack_tags):
			if not preview.targets.has(id): preview.targets.append(id)
	return preview
