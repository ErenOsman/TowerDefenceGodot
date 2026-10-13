class_name RefNode
extends IFormulaNode
## @Name: a named formula from the library, compiled in place.

var name: String
var body: IFormulaNode

func _init(p_name: String, p_body: IFormulaNode, p_text: String) -> void:
	name = p_name
	body = p_body
	text = p_text
	kind = p_body.kind

func evaluate(ctx: EvalContext) -> float: return body.evaluate(ctx)

func collect(r: Requirements) -> void: body.collect(r)
