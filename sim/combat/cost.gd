class_name Cost
extends RefCounted
## A resource an ability spends when cast (a C# struct: copy explicitly if you need a separate one).

var resource: String = ""
var amount: int = 0

func _init(p_resource: String = "", p_amount: int = 0) -> void:
	resource = p_resource
	amount = p_amount
