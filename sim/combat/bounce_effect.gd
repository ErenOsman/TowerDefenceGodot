class_name BounceEffect
extends Effect
## Picks the next unhit target around the last one from the entities alive now: the nearest
## (canonical order), or by the step's bounce instinct when it has one.

var remaining: int = 0
## EntityId (int).
var last: int = -1
var last_pos: Vector2i

func _kind() -> int: return EffectKind.Other

func is_valid(s: GameState) -> bool:
	var c: Entity = s.get_entity(attack.caster)
	return c != null and c.life != LifeState.Removed

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var last_e: Entity = s.get_entity(last)
	var center: Vector2i = last_e.pos if last_e != null and last_e.on_board else last_pos
	var step: AttackStep = attack.step
	var candidates: Array = []
	for id in Targeting.units_in(s, attack.caster, step.bounce_area, step.bounce_filter, center, Dirs.NONE, tags, false):
		if not attack.hit_units.has(id): candidates.append(id)
	if candidates.is_empty(): return # nothing left to bounce to
	var next: int = candidates[0]
	if step.bounce_instinct != null and not step.bounce_instinct.is_default:
		var c: Entity = s.get_entity(attack.caster)
		var pool: Array = []
		for id in candidates:
			var u: Entity = s.get_entity(id)
			pool.append(InstinctCandidate.new(Aim.at(center, u.pos), u))
		var preset: int = InstinctPreset.Nearest if step.bounce_instinct.preset == InstinctPreset.Default else step.bounce_instinct.preset
		var ranked: Array = Instinct.rank(s, c, step.bounce_instinct, preset, pool, center)
		if ranked.is_empty(): return # nothing passes the bounce's Must
		next = ranked[0].target.id

	var b := BatchEffect.new()
	b.targets = [next]
	ctx.push(attack.step_context.init(b))
	if remaining > 1:
		var bounce := BounceEffect.new()
		bounce.remaining = remaining - 1
		bounce.last = next
		bounce.last_pos = s.get_entity(next).pos
		ctx.push(attack.step_context.init(bounce))
