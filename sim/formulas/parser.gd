class_name Parser
extends RefCounted
## Recursive-descent parser for the formula language (Formula System — Design, Expression language):
##   expr := or;  or := and ('or' and)*;  and := not ('and' not)*;  not := 'not' not | cmp
##   cmp  := sum (cmpOp sum)?;  sum := prod (('+'|'-') prod)*;  prod := unary (('*'|'/'|'%') unary)*
##   unary := '-' unary | atom;  atom := NUMBER | ref | call | '(' expr ')'
## Culture-invariant; names compare ordinally. Types are checked while parsing.
## No exceptions in GDScript: parse() returns null on an error and leaves the FormulaException (same message
## and column as the C#) in Parser.last_error. Internally the first error is kept in _err and every grammar
## function returns null once it is set.

enum Tok { Number, Ident, At, Op, LParen, RParen, Comma, Dot, End }

class Token:
	var kind: int
	var value: String
	var pos: int # 0-based
	func _init(k: int, v: String, p: int) -> void:
		kind = k
		value = v
		pos = p

## The error of the last parse() call, or null when it succeeded.
static var last_error: FormulaException = null

var _src: String
var _vocab: Vocabulary
var _ref_stack: Dictionary
var _tokens: Array[Token] = []
var _index := 0
var _err: FormulaException = null
var _result: IFormulaNode = null

func _init(src: String, vocab: Vocabulary, ref_stack: Dictionary) -> void:
	_src = src
	_vocab = vocab
	_ref_stack = ref_stack

## Returns the compiled tree, or null (see last_error).
static func parse(src: String, vocab: Vocabulary) -> IFormulaNode:
	var p := _parse(src, vocab, {})
	last_error = p._err
	return p._result

static func _parse(src: String, vocab: Vocabulary, ref_stack: Dictionary) -> Parser:
	var p := Parser.new(src, vocab, ref_stack)
	p._tokenize()
	if p._err != null: return p
	if p._peek().kind == Tok.End:
		p._err = FormulaException.new("empty formula", 1)
		return p
	var node := p._parse_or()
	if p._err != null: return p
	if p._peek().kind != Tok.End:
		p._error("unexpected '%s'" % p._peek().value, p._peek())
		return p
	p._result = node
	return p

# ----------------------------------------------------------------- tokenizer

const _WHITESPACE := " \t\n\r\u000B\u000C\u0085                 　"

static func _is_white_space(c: String) -> bool: return _WHITESPACE.contains(c)
static func _is_digit(c: String) -> bool: return c >= "0" and c <= "9"

func _tokenize() -> void:
	var i := 0
	var n := _src.length()
	while i < n:
		var c := _src[i]
		if _is_white_space(c):
			i += 1
			continue

		if _is_digit(c) or (c == "." and i + 1 < n and _is_digit(_src[i + 1])):
			var start := i
			while i < n and (_is_digit(_src[i]) or _src[i] == "."): i += 1
			_tokens.append(Token.new(Tok.Number, _src.substr(start, i - start), start))
			continue

		if _is_ident_start(c):
			var start := i
			while i < n and _is_ident_part(_src[i]): i += 1
			_tokens.append(Token.new(Tok.Ident, _src.substr(start, i - start), start))
			continue

		match c:
			"@": _tokens.append(Token.new(Tok.At, "@", i)); i += 1; continue
			"(": _tokens.append(Token.new(Tok.LParen, "(", i)); i += 1; continue
			")": _tokens.append(Token.new(Tok.RParen, ")", i)); i += 1; continue
			",": _tokens.append(Token.new(Tok.Comma, ",", i)); i += 1; continue
			".": _tokens.append(Token.new(Tok.Dot, ".", i)); i += 1; continue
			"+", "-", "*", "/", "%":
				_tokens.append(Token.new(Tok.Op, c, i)); i += 1; continue
			"<", ">", "=", "!":
				var two_char := i + 1 < n and _src[i + 1] == "="
				var op := _src.substr(i, 2) if two_char else c
				if op == "=" or op == "!":
					_err = FormulaException.new("unexpected '%s' (use == or !=)" % op, i + 1)
					return
				_tokens.append(Token.new(Tok.Op, op, i))
				i += op.length()
				continue
			_:
				_err = FormulaException.new("unexpected character '%s'" % c, i + 1)
				return
	_tokens.append(Token.new(Tok.End, "end of formula", n))

static func _is_ident_start(c: String) -> bool: return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"
static func _is_ident_part(c: String) -> bool: return _is_ident_start(c) or (c >= "0" and c <= "9")

# ----------------------------------------------------------------- helpers

func _peek() -> Token: return _tokens[_index]

func _next() -> Token:
	var t := _tokens[_index]
	_index += 1
	return t

func _is_keyword(word: String) -> bool: return _peek().kind == Tok.Ident and _peek().value == word
func _is_op(op: String) -> bool: return _peek().kind == Tok.Op and _peek().value == op

## The token, or null (error set) when the next token is not of that kind.
func _expect(kind: int, what: String) -> Token:
	if _peek().kind != kind:
		_error("expected %s, found '%s'" % [what, _peek().value], _peek())
		return null
	return _next()

## Records the error (the first one wins, like the first throw).
func _error(message: String, at: Token) -> void:
	if _err == null: _err = FormulaException.new(message, at.pos + 1)

func _span(start_pos: int) -> String:
	var end := _tokens[_index - 1].pos + _tokens[_index - 1].value.length() if _index > 0 else start_pos
	if _tokens[_index - 1].kind == Tok.End: end = _src.length()
	return _src.substr(start_pos, maxi(0, end - start_pos)).strip_edges()

## False (error set) when the node is not of the kind.
func _require_kind(node: IFormulaNode, kind: int, at: Token, context: String) -> bool:
	if node.kind != kind:
		_error("%s expects a %s, but '%s' is a %s" % [context, _describe(kind), node.text, _describe(node.kind)], at)
		return false
	return true

static func _describe(k: int) -> String: return "boolean" if k == ValueKind.Bool else "number"

# ----------------------------------------------------------------- grammar

func _parse_or() -> IFormulaNode:
	var start := _peek().pos
	var first := _peek()
	var left := _parse_and()
	if _err != null: return null
	while _is_keyword("or"):
		_next()
		var right_tok := _peek()
		var right := _parse_and()
		if _err != null: return null
		if not _require_kind(left, ValueKind.Bool, first, "'or'"): return null
		if not _require_kind(right, ValueKind.Bool, right_tok, "'or'"): return null
		left = LogicNode.new(LogicOp.Or, left, right, _span(start))
	return left

func _parse_and() -> IFormulaNode:
	var start := _peek().pos
	var first := _peek()
	var left := _parse_not()
	if _err != null: return null
	while _is_keyword("and"):
		_next()
		var right_tok := _peek()
		var right := _parse_not()
		if _err != null: return null
		if not _require_kind(left, ValueKind.Bool, first, "'and'"): return null
		if not _require_kind(right, ValueKind.Bool, right_tok, "'and'"): return null
		left = LogicNode.new(LogicOp.And, left, right, _span(start))
	return left

func _parse_not() -> IFormulaNode:
	if _is_keyword("not"):
		var start := _peek().pos
		_next()
		var operand_tok := _peek()
		var operand := _parse_not()
		if _err != null: return null
		if not _require_kind(operand, ValueKind.Bool, operand_tok, "'not'"): return null
		return NotNode.new(operand, _span(start))
	return _parse_compare()

func _parse_compare() -> IFormulaNode:
	var start := _peek().pos
	var first := _peek()
	var left := _parse_sum()
	if _err != null: return null
	if _peek().kind == Tok.Op:
		var op := -1
		match _peek().value:
			"<": op = CompareOp.Lt
			"<=": op = CompareOp.Le
			">": op = CompareOp.Gt
			">=": op = CompareOp.Ge
			"==": op = CompareOp.Eq
			"!=": op = CompareOp.Ne
		if op >= 0:
			_next()
			var right_tok := _peek()
			var right := _parse_sum()
			if _err != null: return null
			var equality := op == CompareOp.Eq or op == CompareOp.Ne
			if equality:
				if left.kind != right.kind:
					_error("cannot compare '%s' with '%s'" % [left.text, right.text], right_tok)
					return null
			else:
				if not _require_kind(left, ValueKind.Number, first, "a comparison"): return null
				if not _require_kind(right, ValueKind.Number, right_tok, "a comparison"): return null
			return CompareNode.new(op, left, right, _span(start))
	return left

func _parse_sum() -> IFormulaNode:
	var start := _peek().pos
	var first := _peek()
	var left := _parse_prod()
	if _err != null: return null
	while _is_op("+") or _is_op("-"):
		var op := ArithOp.Add if _next().value == "+" else ArithOp.Sub
		var right_tok := _peek()
		var right := _parse_prod()
		if _err != null: return null
		if not _require_kind(left, ValueKind.Number, first, "arithmetic"): return null
		if not _require_kind(right, ValueKind.Number, right_tok, "arithmetic"): return null
		left = ArithNode.new(op, left, right, _span(start))
	return left

func _parse_prod() -> IFormulaNode:
	var start := _peek().pos
	var first := _peek()
	var left := _parse_unary()
	if _err != null: return null
	while _is_op("*") or _is_op("/") or _is_op("%"):
		var symbol := _next().value
		var op := ArithOp.Mul if symbol == "*" else (ArithOp.Div if symbol == "/" else ArithOp.Mod)
		var right_tok := _peek()
		var right := _parse_unary()
		if _err != null: return null
		if not _require_kind(left, ValueKind.Number, first, "arithmetic"): return null
		if not _require_kind(right, ValueKind.Number, right_tok, "arithmetic"): return null
		left = ArithNode.new(op, left, right, _span(start))
	return left

func _parse_unary() -> IFormulaNode:
	if _is_op("-"):
		var start := _peek().pos
		_next()
		var operand_tok := _peek()
		var operand := _parse_unary()
		if _err != null: return null
		if not _require_kind(operand, ValueKind.Number, operand_tok, "'-'"): return null
		return NegNode.new(operand, _span(start))
	return _parse_atom()

## decimal.TryParse(NumberStyles.Number) on a token of digits and dots: valid when it has at most one dot.
static func _valid_number(s: String) -> bool:
	return s.count(".") <= 1 and s != "."

func _parse_atom() -> IFormulaNode:
	var t := _peek()
	match t.kind:
		Tok.Number:
			_next()
			if not _valid_number(t.value):
				_error("invalid number '%s'" % t.value, t)
				return null
			return ConstNode.new(Num.parse(t.value), t.value)
		Tok.LParen:
			_next()
			var inner := _parse_or()
			if _err != null: return null
			if _expect(Tok.RParen, "')'") == null: return null
			return inner
		Tok.At:
			return _parse_ref()
		Tok.Ident:
			return _parse_ident()
		_:
			_error("unexpected '%s'" % t.value, t)
			return null

func _parse_ref() -> IFormulaNode:
	var start := _peek().pos
	_next() # @
	var name := _expect(Tok.Ident, "a library formula name after '@'")
	if name == null: return null
	var body = _vocab.try_get_library(name.value)
	if body == null:
		_error("unknown library formula '@%s'" % name.value, name)
		return null
	if _ref_stack.has(name.value):
		_error("library formula '@%s' references itself" % name.value, name)
		return null
	_ref_stack[name.value] = true
	var sub := Parser._parse(body, _vocab, _ref_stack)
	_ref_stack.erase(name.value)
	if sub._err != null:
		_error("in '@%s': %s" % [name.value, sub._err.message], name)
		return null
	return RefNode.new(name.value, sub._result, _span(start))

## The Subject named s, or -1.
static func _try_parse_subject(s: String) -> int:
	match s:
		"Source": return Subject.Source
		"Target": return Subject.Target
		"Self": return Subject.Self
		_: return -1

func _parse_ident() -> IFormulaNode:
	var start := _peek().pos
	var id := _next()

	var who := _try_parse_subject(id.value)
	if who >= 0:
		if _expect(Tok.Dot, "'.' after '%s'" % id.value) == null: return null
		var name := _expect(Tok.Ident, "a stat or query after '%s.'" % id.value)
		if name == null: return null

		var q := _vocab.try_get_query(name.value)
		if q != null:
			var name_arg = null
			var subject_arg = null
			if q.arg != QueryArg.None:
				if _expect(Tok.LParen, "'(' after '%s'" % name.value) == null: return null
				var arg := _expect(Tok.Ident, "an argument for '%s'" % name.value)
				if arg == null: return null
				if q.arg == QueryArg.Subject:
					var s := _try_parse_subject(arg.value)
					if s < 0:
						_error("'%s' expects Source, Target or Self, found '%s'" % [name.value, arg.value], arg)
						return null
					subject_arg = s
				else:
					name_arg = arg.value
				if _expect(Tok.RParen, "')'") == null: return null
			return QueryNode.new(who, q, name_arg, subject_arg, _span(start))

		if not _vocab.is_stat(name.value):
			_error("unknown stat '%s'" % name.value, name)
			return null
		return StatNode.new(who, name.value, _span(start))

	match id.value:
		"min", "max", "clamp", "floor", "round":
			return _parse_func(id, start)
		"if":
			return _parse_if(id, start)
		"rand":
			return _parse_rand(id, start)
		"true":
			return CompareNode.new(CompareOp.Eq, ConstNode.new(1.0, "1"), ConstNode.new(1.0, "1"), "true")
		"false":
			return CompareNode.new(CompareOp.Ne, ConstNode.new(1.0, "1"), ConstNode.new(1.0, "1"), "false")

	var var_kind = _vocab.try_get_var(id.value)
	if var_kind != null: return VarNode.new(id.value, var_kind, id.value)
	_error("unknown name '%s'" % id.value, id)
	return null

## [args: Array[IFormulaNode], arg_tokens: Array[Token]], or null on an error.
func _parse_args(fn: Token) -> Array:
	if _expect(Tok.LParen, "'(' after '%s'" % fn.value) == null: return []
	var args: Array = []
	var arg_tokens: Array = []
	if _peek().kind != Tok.RParen:
		while true:
			arg_tokens.append(_peek())
			var a := _parse_or()
			if _err != null: return []
			args.append(a)
			if _peek().kind == Tok.Comma:
				_next()
				continue
			break
	if _expect(Tok.RParen, "')'") == null: return []
	return [args, arg_tokens]

func _parse_func(fn: Token, start: int) -> IFormulaNode:
	var parsed := _parse_args(fn)
	if _err != null: return null
	var args: Array = parsed[0]
	var arg_tokens: Array = parsed[1]
	var kind: int
	var min_args: int
	var max_args: int
	match fn.value:
		"min": kind = FuncKind.Min; min_args = 2; max_args = 0x7FFFFFFF
		"max": kind = FuncKind.Max; min_args = 2; max_args = 0x7FFFFFFF
		"clamp": kind = FuncKind.Clamp; min_args = 3; max_args = 3
		"floor": kind = FuncKind.Floor; min_args = 1; max_args = 1
		_: kind = FuncKind.Round; min_args = 1; max_args = 1
	if args.size() < min_args or args.size() > max_args:
		var takes := str(min_args) if min_args == max_args else "%d or more" % min_args
		_error("'%s' takes %s arguments, got %d" % [fn.value, takes, args.size()], fn)
		return null
	for i in args.size():
		if not _require_kind(args[i], ValueKind.Number, arg_tokens[i], "'%s'" % fn.value): return null
	return FuncNode.new(kind, args, _span(start))

func _parse_if(fn: Token, start: int) -> IFormulaNode:
	var parsed := _parse_args(fn)
	if _err != null: return null
	var args: Array = parsed[0]
	var arg_tokens: Array = parsed[1]
	if args.size() != 3:
		_error("'if' takes 3 arguments, got %d" % args.size(), fn)
		return null
	if not _require_kind(args[0], ValueKind.Bool, arg_tokens[0], "the condition of 'if'"): return null
	if args[1].kind != args[2].kind:
		_error("both branches of 'if' must have the same type", arg_tokens[2])
		return null
	return IfNode.new(args[0], args[1], args[2], _span(start))

func _parse_rand(fn: Token, start: int) -> IFormulaNode:
	var parsed := _parse_args(fn)
	if _err != null: return null
	var args: Array = parsed[0]
	var arg_tokens: Array = parsed[1]
	if args.size() != 2:
		_error("'rand' takes 2 arguments, got %d" % args.size(), fn)
		return null
	if not _require_kind(args[0], ValueKind.Number, arg_tokens[0], "'rand'"): return null
	if not _require_kind(args[1], ValueKind.Number, arg_tokens[1], "'rand'"): return null
	return RandNode.new(args[0], args[1], _span(start))
