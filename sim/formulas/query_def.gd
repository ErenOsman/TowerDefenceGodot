class_name QueryDef
extends RefCounted
## A query a game system registers, e.g. HasStatus or IsAlly.

var name: String = ""
var arg: int = QueryArg.None
var result: int = ValueKind.Number
## (unit: IEntity, name_arg: String (null when none), other: IEntity (null when none), ctx: EvalContext) -> float.
## Booleans return 1.0 or 0.0.
var evaluate: Callable

func _init(p_name: String = "", p_arg: int = QueryArg.None, p_result: int = ValueKind.Number, p_evaluate: Callable = Callable()) -> void:
	name = p_name
	arg = p_arg
	result = p_result
	evaluate = p_evaluate
