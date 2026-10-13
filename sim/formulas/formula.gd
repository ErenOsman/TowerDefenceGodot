class_name Formula
extends RefCounted
## A formula slot's value: the expression text is the single source of truth; the node tree
## is compiled once per vocabulary and cached by text.
## A C# struct with an implicit conversion from string: build one with Formula.new("Source.Str * 2")
## or Formula.of(string_or_formula). Treat it as immutable (assign a new Formula instead of editing).

var expression: String = ""

func _init(p_expression = "") -> void:
	expression = "" if p_expression == null else p_expression

## The C# implicit conversion: a String (or null) becomes a Formula; a Formula is returned as is.
static func of(v) -> Formula:
	if v is Formula: return v
	return Formula.new(v)

var is_empty: bool:
	get: return expression.strip_edges().is_empty()

## The compiled tree, or null on a parse error (C# throws FormulaException; see vocab.last_error).
func compile(vocab: Vocabulary) -> IFormulaNode:
	return vocab.compile(expression)

## On a parse error (the C# throws): push_error, ctx.fail(message) and 0.
func evaluate(vocab: Vocabulary, ctx: EvalContext) -> float:
	var node := compile(vocab)
	if node == null:
		push_error("Formula '%s': %s" % [expression, vocab.last_error])
		ctx.fail(vocab.last_error)
		return 0.0
	return node.evaluate(ctx)

func _to_string() -> String:
	return expression
