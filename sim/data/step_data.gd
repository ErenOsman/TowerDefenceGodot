class_name StepData
extends RefCounted
## Inspector-editable data for one step. Each type converts into the matching core Step.
## Saved data records the class name ("$type"): renaming a step class loses saved steps.

## The core step (abstract).
func to_core(_c: AssetConverter) -> Step:
	push_error("abstract")
	return null

## The name shown in the Inspector's step header and type picker (C# DisplayName).
var display_name: String:
	get: return _display_name()

## Override to change display_name (GDScript cannot override a property).
func _display_name() -> String:
	return get_script().get_global_name().replace("StepData", "")
