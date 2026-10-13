class_name IFormulaNode
extends RefCounted
## An immutable node of a compiled formula. Each node evaluates itself.
## `kind` (ValueKind) and `text` are set by each node's constructor (they never change).

var kind: int = ValueKind.Number
## The source text of this node, used in traces and failure reasons.
var text: String = ""

func evaluate(_ctx: EvalContext) -> float:
	push_error("abstract")
	return 0.0

func collect(_r: Requirements) -> void:
	push_error("abstract")
