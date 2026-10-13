class_name NegNode
extends IFormulaNode

var a: IFormulaNode

func _init(p_a: IFormulaNode, p_text: String) -> void:
	a = p_a
	text = p_text
	kind = ValueKind.Number

func evaluate(ctx: EvalContext) -> float: return Num.sub(0.0, a.evaluate(ctx))

func collect(r: Requirements) -> void: a.collect(r)
