class_name FormulaException
extends RefCounted
## A parse or validation error, with the 1-based column when known.
## GDScript has no exceptions: the parser returns null and exposes one of these (Parser.last_error,
## Vocabulary.last_exception); `message` is exactly the C# Exception.Message.

var column: int = 0
var message: String = ""

func _init(p_message: String = "", p_column: int = 0) -> void:
	column = p_column
	message = ("col %d: %s" % [p_column, p_message]) if p_column > 0 else p_message

func _to_string() -> String:
	return message
