class_name VarNode
extends IFormulaNode

var name: String

func _init(p_name: String, p_kind: int, p_text: String) -> void:
	name = p_name
	kind = p_kind
	text = p_text

func evaluate(ctx: EvalContext) -> float:
	if ctx.vars == null or not ctx.vars.has(name):
		ctx.fail("Variable '%s' is not available in this context." % name)
		return 0.0
	var v: float = ctx.vars[name]
	if ctx.trace != null: ctx.trace.add(name, v)
	return v

func collect(r: Requirements) -> void:
	r.vars[name] = true
