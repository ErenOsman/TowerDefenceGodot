class_name CompareNode
extends IFormulaNode

var op: int
var a: IFormulaNode
var b: IFormulaNode

func _init(p_op: int, p_a: IFormulaNode, p_b: IFormulaNode, p_text: String) -> void:
	op = p_op
	a = p_a
	b = p_b
	text = p_text
	kind = ValueKind.Bool

func evaluate(ctx: EvalContext) -> float:
	var x := Num.fix(a.evaluate(ctx))
	var y := Num.fix(b.evaluate(ctx))
	match op:
		CompareOp.Lt: return Num.bool_num(x < y)
		CompareOp.Le: return Num.bool_num(x <= y)
		CompareOp.Gt: return Num.bool_num(x > y)
		CompareOp.Ge: return Num.bool_num(x >= y)
		CompareOp.Eq: return Num.bool_num(x == y)
		_: return Num.bool_num(x != y)

func collect(r: Requirements) -> void:
	a.collect(r)
	b.collect(r)
