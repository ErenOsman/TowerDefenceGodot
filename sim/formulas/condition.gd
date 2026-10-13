class_name Condition
extends RefCounted
## A boolean formula. Empty means always true. Conditions never use rand(): a chance is a
## separate formula field, rolled once.
## A C# struct with an implicit conversion from string: Condition.new("Self.HpPct < 0.3") or Condition.of(v).

var expression: String = ""

func _init(p_expression = "") -> void:
	expression = "" if p_expression == null else p_expression

static func of(v) -> Condition:
	if v is Condition: return v
	return Condition.new(v)

var is_empty: bool:
	get: return expression.strip_edges().is_empty()

## On a parse error (the C# throws): push_error, ctx.fail(message) and false.
func evaluate(vocab: Vocabulary, ctx: EvalContext) -> bool:
	if is_empty: return true
	var node := vocab.compile(expression)
	if node == null:
		push_error("Condition '%s': %s" % [expression, vocab.last_error])
		ctx.fail(vocab.last_error)
		return false
	return Num.is_true(node.evaluate(ctx))

## Evaluates the condition and, when it fails, returns the first failing leaf as English text
## (e.g. "Requires Self.HpPct < 0.3"). Returns null when the condition passes.
## On a parse error (the C# throws): push_error, ctx.fail(message) and the error message.
func failure_reason(vocab: Vocabulary, ctx: EvalContext) -> Variant:
	if is_empty: return null
	var node := vocab.compile(expression)
	if node == null:
		push_error("Condition '%s': %s" % [expression, vocab.last_error])
		ctx.fail(vocab.last_error)
		return vocab.last_error
	return null if Num.is_true(node.evaluate(ctx)) else Condition._explain(node, ctx, false)

static func _explain(node: IFormulaNode, ctx: EvalContext, negated: bool) -> String:
	if node is LogicNode and node.op == LogicOp.And and not negated:
		# the first operand that is false explains the failure
		return Condition._explain(node.a, ctx, false) if not Num.is_true(node.a.evaluate(ctx)) else Condition._explain(node.b, ctx, false)
	if node is LogicNode and node.op == LogicOp.Or and negated:
		# not (a or b) fails when either is true
		return Condition._explain(node.a, ctx, true) if Num.is_true(node.a.evaluate(ctx)) else Condition._explain(node.b, ctx, true)
	if node is NotNode:
		return Condition._explain(node.a, ctx, not negated)
	return ("Requires not %s" % node.text) if negated else ("Requires %s" % node.text)

func _to_string() -> String:
	return expression
