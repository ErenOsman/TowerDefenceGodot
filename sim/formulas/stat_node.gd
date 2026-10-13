class_name StatNode
extends IFormulaNode

var who: int
var stat: String

func _init(p_who: int, p_stat: String, p_text: String) -> void:
	who = p_who
	stat = p_stat
	text = p_text
	kind = ValueKind.Number

func evaluate(ctx: EvalContext) -> float:
	var unit := ctx.entity(who)
	if unit == null:
		ctx.fail("%s: %s is not available in this context." % [text, Subject.name_of(who)])
		return 0.0
	var v: float = unit.stat(stat)
	if ctx.trace != null: ctx.trace.add(text, v)
	return v

func collect(r: Requirements) -> void:
	r.subjects |= SubjectNeedsUtil.of(who)
	r.subject_reads.append(text)
