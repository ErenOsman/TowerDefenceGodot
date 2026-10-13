class_name Trace
extends RefCounted
## Collects a step-by-step breakdown of a resolution when attached to a context.

var lines: Array[String] = []

func add(what: String, value: float) -> void:
	lines.append("%s = %s" % [what, Num.to_str(value)])

func _to_string() -> String:
	return "\n".join(lines)
