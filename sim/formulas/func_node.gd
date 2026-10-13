class_name FuncNode
extends IFormulaNode

var fn: int
var args: Array[IFormulaNode]

## The C# field is `Func`; `fn` here (FuncKind).
func _init(p_func: int, p_args: Array, p_text: String) -> void:
	fn = p_func
	args.assign(p_args)
	text = p_text
	kind = ValueKind.Number

func evaluate(ctx: EvalContext) -> float:
	match fn:
		FuncKind.Min:
			var m := args[0].evaluate(ctx)
			for i in range(1, args.size()): m = Num.min_of(m, args[i].evaluate(ctx))
			return m
		FuncKind.Max:
			var m := args[0].evaluate(ctx)
			for i in range(1, args.size()): m = Num.max_of(m, args[i].evaluate(ctx))
			return m
		FuncKind.Clamp:
			var x := args[0].evaluate(ctx)
			var lo := args[1].evaluate(ctx)
			var hi := args[2].evaluate(ctx)
			return Num.clamp_of(x, lo, hi)
		FuncKind.Floor: return Num.floor_of(Num.fix(args[0].evaluate(ctx)))
		_: return Num.round_of(Num.fix(args[0].evaluate(ctx)))

func collect(r: Requirements) -> void:
	for x in args: x.collect(r)
