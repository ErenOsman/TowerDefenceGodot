class_name IfEffect
extends Effect
## Step evaluation point: chooses a branch when it runs; inside a chain the branch runs in place.

var step: IfStep

func _kind() -> int: return EffectKind.Other
func is_valid(_s: GameState) -> bool: return true

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var sc: StepContext = step_context
	var ectx: EvalContext = ctx.eval(self, sc.self_, s.get_entity(source), sc.target, ctx.vars(self))
	var pass_: bool = step.condition.evaluate(s.vocab, ectx)

	var branch_ctx: StepContext = sc.with_target(sc.target)
	branch_ctx.depth = depth + 1
	var effects: Array = Step.expand_list(step.then if pass_ else step.else_, branch_ctx)
	if chain != null: ctx.insert_into_chain(effects)
	else: ctx.push_all(effects)
