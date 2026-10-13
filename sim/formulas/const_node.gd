class_name ConstNode
extends IFormulaNode

var value: float

func _init(p_value: float, p_text: String) -> void:
	value = p_value
	text = p_text
	kind = ValueKind.Number

func evaluate(_ctx: EvalContext) -> float: return value

func collect(_r: Requirements) -> void: pass
