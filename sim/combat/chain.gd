class_name Chain
extends RefCounted
## The ordered effects for one target inside a batch. Later effects read earlier results.

## EntityId (int).
var target: int = -1
## Array of Effect.
var effects: Array = []
## String -> float.
var vars: Dictionary = {}
var stopped: bool = false

func var_(name: String) -> bool:
	return vars.has(name) and Num.is_true(vars[name])
