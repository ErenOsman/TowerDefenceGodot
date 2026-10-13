class_name RandNode
extends IFormulaNode
## rand(a, b): draws only from the context RNG; previews return a bound.

var lo: IFormulaNode
var hi: IFormulaNode

func _init(p_lo: IFormulaNode, p_hi: IFormulaNode, p_text: String) -> void:
	lo = p_lo
	hi = p_hi
	text = p_text
	kind = ValueKind.Number

func evaluate(ctx: EvalContext) -> float:
	var l := lo.evaluate(ctx)
	var h := hi.evaluate(ctx)
	if ctx.mode == EvalMode.PreviewMin: return l
	if ctx.mode == EvalMode.PreviewMax: return h
	if ctx.rng == null:
		ctx.fail("%s: no RNG in context." % text)
		return 0.0
	var v := Num.add(l, Num.mul(Num.sub(h, l), ctx.rng.next_unit()))
	if ctx.trace != null: ctx.trace.add(text, v)
	return v

func collect(r: Requirements) -> void:
	r.uses_random = true
	lo.collect(r)
	hi.collect(r)
