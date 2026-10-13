class_name ResurrectEffect
extends Effect
## Returns a Dead entity to Alive on its death tile (or the nearest free tile). Cleared statuses do not return.

var hp: Formula = Formula.new("Target.MaxHp")

func _kind() -> int: return EffectKind.Resurrect

func is_valid(s: GameState) -> bool:
	var t: Entity = s.get_entity(target_id)
	return t != null and t.life == LifeState.Dead

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var target: Entity = s.get_entity(target_id)
	var tile = s.free_tile_near(target.death.tile, target.has_tag(Tags.Flying))
	if tile == null:
		var f := GameEvent.new()
		f.type = GameEventType.Fizzled
		f.source = source
		f.target = target_id
		f.detail = "Resurrect (no free tile)"
		ctx.write(self, f)
		return

	var ectx: EvalContext = ctx.eval(self, self_of(s), s.get_entity(source), target, ctx.vars(self))
	var value: int = Effect.floor_int(hp.evaluate(s.vocab, ectx))

	target.life = LifeState.Alive
	target.position = tile
	target.death = null
	target.hp_zero_by = -1
	target.hp = maxi(1, mini(value, target.max_hp))

	var e := GameEvent.new()
	e.type = GameEventType.EntityResurrected
	e.source = source
	e.target = target_id
	e.to = tile
	e.facts["Hp"] = float(target.hp)
	ctx.write(self, e)
