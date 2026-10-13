class_name ContentAsset
extends RefCounted
## Base of every content asset (the C# ScriptableObject): its asset name (the last part of its key,
## "Units/Enemies/Rabbit" → "Rabbit"). Not a C# class: the port's stand-in for UnityEngine.ScriptableObject.

var name: String = ""

## The C# class name ("AbilityAsset").
func type_name() -> String:
	return get_script().get_global_name()

func _to_string() -> String:
	return "%s (%s)" % [name, type_name()]
