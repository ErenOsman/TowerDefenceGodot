class_name EvalContext
extends RefCounted
## Everything readable during one resolution.
## `self` is a GDScript keyword, so the C# field Self is `self_` here (see PORT.md Renames).
## C# evaluation throws InvalidOperationException when a subject, variable or the RNG is missing; here the
## node records the message in `error` (first one wins) and evaluates to 0. Callers that caught it in C#
## (AbilityText.TryEval) check `ctx.error != ""` after evaluating.

var mode: int = EvalMode.Execute
var source: IEntity
var target: IEntity
var self_: IEntity
var vars: Dictionary = {}
var rng: IRng
var trace: Trace
## null until the first warning, like the C# List.
var warnings = null
## Port-only: the message of the first InvalidOperationException the C# would have thrown; "" if none.
var error: String = ""

## Optional shortcut constructor (all fields can also be assigned after new()).
func _init(p_source: IEntity = null, p_self: IEntity = null, p_target: IEntity = null, p_rng: IRng = null, p_vars = null, p_mode: int = EvalMode.Execute) -> void:
	source = p_source
	self_ = p_self
	target = p_target
	rng = p_rng
	if p_vars != null: vars = p_vars
	mode = p_mode

func entity(s: int) -> IEntity:
	match s:
		Subject.Source: return source
		Subject.Target: return target
		_: return self_

func warn(message: String) -> void:
	if warnings == null: warnings = []
	warnings.append(message)

## Port-only: records what the C# would have thrown (InvalidOperationException).
func fail(message: String) -> void:
	if error == "": error = message
