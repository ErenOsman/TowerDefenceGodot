class_name IfNode
extends IFormulaNode
## if(cond, a, b): only the chosen branch is evaluated.

var cond: IFormulaNode
var then_node: IFormulaNode
var else_node: IFormulaNode

## C# fields Cond/Then/Else; `then`/`else` are GDScript keywords → then_node/else_node.
func _init(p_cond: IFormulaNode, p_then: IFormulaNode, p_else: IFormulaNode, p_text: String) -> void:
	cond = p_cond
	then_node = p_then
	else_node = p_else
	text = p_text
	kind = p_then.kind

func evaluate(ctx: EvalContext) -> float:
	return then_node.evaluate(ctx) if Num.is_true(cond.evaluate(ctx)) else else_node.evaluate(ctx)

func collect(r: Requirements) -> void:
	cond.collect(r)
	then_node.collect(r)
	else_node.collect(r)
