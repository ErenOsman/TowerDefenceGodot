class_name ArithNode
extends IFormulaNode

var op: int
var a: IFormulaNode
var b: IFormulaNode

func _init(p_op: int, p_a: IFormulaNode, p_b: IFormulaNode, p_text: String) -> void:
	op = p_op
	a = p_a
	b = p_b
	text = p_text
	kind = ValueKind.Number

func evaluate(ctx: EvalContext) -> float:
	var x := a.evaluate(ctx)
	var y := b.evaluate(ctx)
	match op:
		ArithOp.Add: return Num.add(x, y)
		ArithOp.Sub: return Num.sub(x, y)
		ArithOp.Mul: return Num.mul(x, y)
		ArithOp.Mod:
			if y == 0.0: ctx.warn("Modulo by zero in '%s'; result is 0." % text)
			return Num.mod(x, y)
		_:
			if y == 0.0: ctx.warn("Division by zero in '%s'; result is 0." % text)
			return Num.div(x, y)

func collect(r: Requirements) -> void:
	a.collect(r)
	b.collect(r)
