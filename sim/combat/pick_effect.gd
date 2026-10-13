class_name PickEffect
extends Effect
## A Pick step running: gathers the units in its area now, ranks them by its instinct and runs its steps on the first ones.

var step: PickStep

func _kind() -> int: return EffectKind.Other
func is_valid(_s: GameState) -> bool: return true

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var sc: StepContext = step_context
	var me: Entity = sc.self_
	if me == null: return
	var center: Vector2i = sc.aim.tile if step.center == PickCenter.Aim and sc.aim != null else me.pos

	var ectx: EvalContext = ctx.eval(self, me, s.get_entity(source), sc.target, ctx.vars(self))
	var count: int = maxi(0, Effect.floor_int(step.count.evaluate(s.vocab, ectx)))
	if count == 0: return

	var pool: Array = []
	for id in Targeting.units_in(s, me.id, step.area, step.filter, center, Dirs.NONE, tags, false):
		var u: Entity = s.get_entity(id)
		if u == null: continue
		pool.append(InstinctCandidate.new(Aim.at(center, u.pos), u))
	var preset: int = InstinctPreset.Nearest if step.instinct == null or step.instinct.preset == InstinctPreset.Default else step.instinct.preset
	var ranked: Array = Instinct.rank(s, me, step.instinct, preset, pool, center)

	var effects: Array = []
	for i in mini(count, ranked.size()):
		var branch: StepContext = sc.with_target(ranked[i].target)
		branch.depth = depth + 1
		effects.append_array(Step.expand_list(step.steps, branch))
	if chain != null: ctx.insert_into_chain(effects)
	else: ctx.push_all(effects)
