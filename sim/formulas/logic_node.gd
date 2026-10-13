class_name LogicNode
extends IFormulaNode
## Short-circuits left to right; conditions are pure, so this only affects speed and reasons.

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
	var x := Num.is_true(a.evaluate(ctx))
	if op == LogicOp.And: return Num.bool_num(x and Num.is_true(b.evaluate(ctx)))
	return Num.bool_num(x or Num.is_true(b.evaluate(ctx)))

func collect(r: Requirements) -> void:
	a.collect(r)
	b.collect(r)
