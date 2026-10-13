class_name QueryNode
extends IFormulaNode

var who: int
var query: QueryDef
## String, or null when the query takes no name argument.
var name_arg
## Subject, or null when the query takes no subject argument (C# Subject?).
var subject_arg

func _init(p_who: int, p_query: QueryDef, p_name_arg, p_subject_arg, p_text: String) -> void:
	who = p_who
	query = p_query
	name_arg = p_name_arg
	subject_arg = p_subject_arg
	text = p_text
	kind = p_query.result

func evaluate(ctx: EvalContext) -> float:
	var unit := ctx.entity(who)
	if unit == null:
		ctx.fail("%s: %s is not available in this context." % [text, Subject.name_of(who)])
		return 0.0
	var other: IEntity = ctx.entity(subject_arg) if subject_arg != null else null
	var v: float = query.evaluate.call(unit, name_arg, other, ctx)
	if ctx.trace != null: ctx.trace.add(text, v)
	return v

func collect(r: Requirements) -> void:
	r.subjects |= SubjectNeedsUtil.of(who)
	if subject_arg != null: r.subjects |= SubjectNeedsUtil.of(subject_arg)
	r.subject_reads.append(text)
