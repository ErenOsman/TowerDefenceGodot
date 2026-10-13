class_name NotNode
extends IFormulaNode

var a: IFormulaNode

func _init(p_a: IFormulaNode, p_text: String) -> void:
	a = p_a
	text = p_text
	kind = ValueKind.Bool

func evaluate(ctx: EvalContext) -> float: return Num.bool_num(not Num.is_true(a.evaluate(ctx)))

func collect(r: Requirements) -> void: a.collect(r)
