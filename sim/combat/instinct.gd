class_name Instinct
extends RefCounted
## How an ability chooses its own aim (Instinct — Design). Static functions only.

## The aim an ability takes when nobody aims it: its instinct over its valid aims (or the given
## ones), or null when none is left. Random draws from rng (the state's by default).
static func choose(s: GameState, caster: Entity, a: AbilityDef, aims = null, rng: IRng = null) -> Aim:
	var list: Array = (Targeting.valid_aims(s, caster.id, a) if aims == null else aims).duplicate()
	if list.is_empty(): return null
	var preset := effective(s, caster, a, list)
	if preset == InstinctPreset.Engage and a.targeting.is_movement: return _engage(s, caster, a, list, rng)
	var candidates := []
	for aim in list: candidates.append(InstinctCandidate.new(aim, target_of(s, a, aim)))
	var ranked := rank(s, caster, a.instinct, preset, candidates, caster.pos, rng, a)
	if ranked.is_empty(): return null
	# Most hit: an aim that hits nothing worth hitting is no aim (the enemy skips it, quick cast says No target)
	if preset == InstinctPreset.MostHit and _hit_keys(s, caster, a, ranked[0].aim, 0.0)[0] == 0.0: return null
	return ranked[0].aim

## The reason of the last quick_cast ("" when it found an aim).
static var last_reason: String = ""

## The aim a quick cast (shift-click) takes, or null with the reason in reason_out[0] (and Instinct.last_reason) (Instinct — Design,
## Quick cast): no valid aim → "No target"; exactly one → that one; a movement ability with no
## instinct of its own → the player aims it; otherwise the instinct's choice. Draws from a copy
## of the state's RNG, so a preview and the cast agree and nothing is consumed. Casting itself
## (cooldown, energy, phase) is checked by the caller.
static func quick_cast(s: GameState, caster: Entity, a: AbilityDef, reason_out = null) -> Aim:
	var reason = null
	var result: Aim = null
	var aims := Targeting.valid_aims(s, caster.id, a)
	if aims.is_empty():
		reason = "No target"
	elif aims.size() == 1:
		result = aims[0]
	elif a.targeting.is_movement and (a.instinct == null or a.instinct.preset == InstinctPreset.Default):
		reason = "No target: aim it yourself"
	else:
		result = choose(s, caster, a, aims, s.rng.clone())
		if result == null: reason = "No target"
	last_reason = "" if reason == null else reason
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = reason
	return result

## Candidates in the instinct's order, after its Must; the tie-break keeps the candidates' own
## order. origin = where distances are measured from (the caster; a bounce's last target).
## ability = for MostHit's attack area (optional). candidates: Array of InstinctCandidate.
static func rank(s: GameState, caster: Entity, def: InstinctDef, preset: int, candidates: Array, origin: Vector2i, rng: IRng = null, ability: AbilityDef = null) -> Array:
	var kept := []
	for c in candidates:
		if _passes_must(s, caster, def, c): kept.append(c)
	# Taunted, per ability: the aims hitting any taunter form the pool the instinct chooses from; none: everyone
	var taunter_ids := taunters(s, caster)
	if not taunter_ids.is_empty():
		var hitting := []
		for c in kept:
			for t in taunter_ids:
				if _hits_unit(s, caster, ability, c, t):
					hitting.append(c)
					break
		if not hitting.is_empty(): kept = hitting
	if kept.size() <= 1 or preset == InstinctPreset.FirstValid: return kept # FirstValid: the given order as it is

	# keys: lower is better; the sort is made total (target id, then index) so it keeps the given order on full ties
	if rng == null: rng = s.rng
	var keys := []
	for i in kept.size(): keys.append(_keys(s, caster, def, preset, kept[i], origin, rng, ability))
	var order := range(kept.size())
	order.sort_custom(func(i, j):
		var c := _compare_keys(keys[i], keys[j])
		if c != 0: return c < 0
		var ti: int = kept[i].target.id if kept[i].target != null else 0x7FFFFFFF
		var tj: int = kept[j].target.id if kept[j].target != null else 0x7FFFFFFF
		if ti != tj: return ti < tj
		return i < j)
	var result := []
	for i in order: result.append(kept[i])
	return result

## The preset an ability uses: its own, else the default from its targeting (Instinct — Design, Defaults).
static func effective(s: GameState, caster: Entity, a: AbilityDef, aims: Array) -> int:
	var own: int = a.instinct.preset if a.instinct != null else InstinctPreset.Default
	return own if own != InstinctPreset.Default else default(s, caster, a, aims)

## The default: movement takes the longest route; an attack with an area larger than one tile
## the most hits; a target filter whose candidates are all allies the most hurt, any other
## filter the nearest; no filter the first valid aim.
static func default(s: GameState, caster: Entity, a: AbilityDef, aims: Array) -> int:
	if a.targeting.is_movement: return InstinctPreset.FarthestStep
	if _area_attack(s, caster, a) != null: return InstinctPreset.MostHit
	if Condition.of(a.target_filter).is_empty and not a.targets_dead: return InstinctPreset.FirstValid
	var targets := []
	for aim in aims:
		var t := target_of(s, a, aim)
		if t != null: targets.append(t)
	var allies := not targets.is_empty()
	for t in targets:
		if not (t.id == caster.id or s.relation(caster, t) == Relation.Ally):
			allies = false
			break
	return InstinctPreset.MostHurt if allies else InstinctPreset.Nearest

static func _path_count(m: Aim) -> int:
	return m.path.size() if m.path != null else 0

## The first of the aims with the longest route (C# OrderByDescending(...).First(): stable).
static func _longest(aims: Array) -> Aim:
	var best: Aim = null
	for m in aims:
		if best == null or _path_count(m) > _path_count(best): best = m
	return best

## Engage (movement): stands the mover on each reachable tile in turn and asks what its follow-up
## attack could hit from there; ranks every such unit by the attack's instinct (distances from
## where the mover stands now); then walks to the reachable tile furthest along that can hit
## the best one. Nothing to hit, or no castable follow-up: the longest route.
static func _engage(s: GameState, mover: Entity, move: AbilityDef, aims: Array, rng: IRng) -> Aim:
	var farthest := _longest(aims)
	var attack := follow_up(mover, move)
	if attack == null or not Targeting.can_cast(s, mover.id, attack): return farthest

	var options := [] # [move Aim, InstinctCandidate]
	var home = mover.position
	for m in aims:
		mover.position = m.tile # only to ask the attack's targeting; restored below
		for hit in Targeting.valid_aims(s, mover.id, attack):
			var t := target_of(s, attack, hit)
			if t != null and t != mover: options.append([m, InstinctCandidate.new(hit, t)])
	mover.position = home
	if options.is_empty(): return farthest

	var units := []
	var seen := {}
	for o in options:
		var id: int = o[1].target.id
		if seen.has(id): continue
		seen[id] = true
		units.append(o[1])
	var unit_aims := []
	for u in units: unit_aims.append(u.aim)
	var preset := effective(s, mover, attack, unit_aims)
	var ranked := rank(s, mover, attack.instinct, preset, units, mover.pos, rng.clone() if rng != null else s.rng.clone(), attack)
	if ranked.is_empty(): return farthest
	var best: Entity = ranked[0].target
	var moves := []
	for o in options:
		if o[1].target == best: moves.append(o[0])
	return _longest(moves)

## The ability a movement is planned for: the owner's next non-movement ability in its list, else the first one before it.
static func follow_up(owner: Entity, move: AbilityDef) -> AbilityDef:
	var i: int = owner.abilities.find(move)
	for k in range(i + 1, owner.abilities.size()):
		if not owner.abilities[k].targeting.is_movement: return owner.abilities[k]
	for k in range(0, i):
		if not owner.abilities[k].targeting.is_movement: return owner.abilities[k]
	return null

## The applier of the chooser's newest active Taunted status, if alive; otherwise -1 (None).
static func taunted_by(s: GameState, chooser: Entity) -> int:
	var list := taunters(s, chooser)
	return list[0] if not list.is_empty() else -1

## The living appliers of the chooser's active Taunted statuses, newest first, each once (entity ids).
static func taunters(s: GameState, chooser: Entity) -> Array:
	var list := []
	if chooser == null: return list
	for i in range(chooser.statuses.size() - 1, -1, -1):
		var st = chooser.statuses[i]
		if not st.active or not st.def.has_tag(Tags.Taunted): continue
		var applier: Entity = s.get_entity(st.applied_by)
		if applier != null and applier.alive and not applier.is_environment and not list.has(applier.id): list.append(applier.id)
	return list

## The unit an aim targets: the corpse for targetsDead abilities, else the entity on the tile (null for routes and empty tiles).
static func target_of(s: GameState, a: AbilityDef, aim: Aim) -> Entity:
	if a.targeting.is_movement: return null
	if a.targets_dead:
		var corpses: Array = s.corpses_at(aim.tile)
		return corpses[0] if not corpses.is_empty() else null
	return s.entity_at(aim.tile)

# ------------------------------------------------------------------ internal

static func _passes_must(s: GameState, caster: Entity, def: InstinctDef, c: InstinctCandidate) -> bool:
	if def == null or def.must.is_empty: return true
	if c.target == null: return false
	return def.must.evaluate(s.vocab, _context(s, caster, c.target))

static func _keys(s: GameState, caster: Entity, def: InstinctDef, preset: int, c: InstinctCandidate, origin: Vector2i, rng: IRng, ability: AbilityDef) -> Array:
	var t: Entity = c.target
	var at: Vector2i = t.pos if t != null and t.on_board else c.aim.tile
	var distance := float(absi(origin.x - at.x) + absi(origin.y - at.y))
	match preset:
		InstinctPreset.Nearest: return [distance]
		InstinctPreset.Farthest: return [-distance]
		InstinctPreset.First: return [0.0, -float(t.path_progress)] if t != null and t.path_progress >= 0 else [1.0, 0.0]
		InstinctPreset.Last: return [0.0, float(t.path_progress)] if t != null and t.path_progress >= 0 else [1.0, 0.0]
		InstinctPreset.Weakest: return [0.0, float(t.hp)] if t != null else [1.0, 0.0]
		InstinctPreset.Strongest: return [0.0, -float(t.max_hp)] if t != null else [1.0, 0.0]
		# exact ratio for ordering (no Num.fix: decimal division keeps 28 digits)
		InstinctPreset.MostHurt: return [0.0, float(t.hp) / float(t.max_hp)] if t != null and t.max_hp > 0 else [1.0, 0.0]
		InstinctPreset.MostHit: return _hit_keys(s, caster, ability, c.aim, distance)
		InstinctPreset.Random: return [float(rng.next_uint())]
		InstinctPreset.FarthestStep: return [-float(_path_count(c.aim))]
		InstinctPreset.Ahead:
			var ahead: int = caster.ahead_on_path(t) if t != null else -1
			return [0.0, -float(ahead), distance] if ahead >= 0 else [1.0, 0.0, distance]
		InstinctPreset.Custom: return _custom_keys(s, caster, def, c, ability)
		_: return [] # FirstValid: only the tie-break

static func _custom_keys(s: GameState, caster: Entity, def: InstinctDef, c: InstinctCandidate, ability: AbilityDef) -> Array:
	if def == null or def.prefer.is_empty(): return []
	var keys := []
	for p in def.prefer:
		var v := 0.0
		if p.over == PreferOver.Target:
			v = _score(s, caster, p.value, c.target)
		else:
			for u in _area_units(s, caster, ability, c):
				if not p.filter.is_empty and not p.filter.evaluate(s.vocab, _context(s, caster, u)): continue
				v = Num.add(v, 1.0 if p.over == PreferOver.AreaCount else _score(s, caster, p.value, u))
		keys.append(-v if p.highest else v)
	return keys

static func _score(s: GameState, caster: Entity, f: Formula, target: Entity) -> float:
	if f == null or f.is_empty or target == null: return 0.0
	return f.evaluate(s.vocab, _context(s, caster, target))

static func _context(s: GameState, caster: Entity, target: Entity) -> EvalContext:
	var ctx := EvalContext.new()
	ctx.source = caster; ctx.self_ = caster; ctx.target = target; ctx.rng = s.rng.clone()
	return ctx

## The units an aim would hit: its first area Attack step's targets, else its own target.
static func _area_units(s: GameState, caster: Entity, a: AbilityDef, c: InstinctCandidate) -> Array:
	var atk := _area_attack(s, caster, a)
	if atk == null: return [c.target] if c.target != null else []
	var result := []
	for id in Targeting.area_targets(s, caster.id, atk, c.aim, Tags.set_of(a.tags)):
		var u: Entity = s.get_entity(id)
		if u != null: result.append(u)
	return result

static func _hits_unit(s: GameState, caster: Entity, a: AbilityDef, c: InstinctCandidate, unit: int) -> bool:
	if c.target != null and c.target.id == unit: return true
	for u in _area_units(s, caster, a, c):
		if u.id == unit: return true
	return false

## The first Attack step whose area is larger than one tile, or null.
static func _area_attack(s: GameState, caster: Entity, a: AbilityDef) -> AttackStep:
	if a == null: return null
	var tags = Tags.set_of(a.tags)
	for step in a.steps:
		if step is AttackStep and step.area.shape != Shape.Single and step.area.shape != Shape.Ray \
				and Targeting.reaches_past_center(s, caster, step.area, tags):
			return step
	return null

## Most hit's keys (lower is better): with an area filter, the units it lets through; without
## one, the caster's enemies hit, then fewer allies hit (the caster counts as one); then the
## distance. The first key is minus what the aim is worth (0 = nothing worth hitting).
static func _hit_keys(s: GameState, caster: Entity, a: AbilityDef, aim: Aim, distance: float) -> Array:
	var atk := _area_attack(s, caster, a)
	if atk == null:
		var on: Entity = s.entity_at(aim.tile)
		return [-1.0 if on != null and s.relation(caster, on) == Relation.Enemy else 0.0, distance]
	var hit := []
	for id in Targeting.area_targets(s, caster.id, atk, aim, Tags.set_of(a.tags)):
		var u: Entity = s.get_entity(id)
		if u != null: hit.append(u)
	if not Condition.of(atk.area_filter).is_empty: return [-float(hit.size()), 0.0, distance]
	var enemies := 0
	var allies := 0
	for u in hit:
		if u != caster and s.relation(caster, u) == Relation.Enemy: enemies += 1
		if u == caster or s.relation(caster, u) == Relation.Ally: allies += 1
	return [-float(enemies), float(allies), distance]

## Compares key arrays element by element (shorter = padded with 0).
static func _compare_keys(x: Array, y: Array) -> int:
	var n := maxi(x.size(), y.size())
	for i in n:
		var a: float = x[i] if i < x.size() else 0.0
		var b: float = y[i] if i < y.size() else 0.0
		if a < b: return -1
		if a > b: return 1
	return 0
