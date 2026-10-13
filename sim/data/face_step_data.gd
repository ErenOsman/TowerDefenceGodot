class_name FaceStepData
extends StepData

var on: int = StepTarget.Self
## TowardAim: the aimed tile. Direction: the direction below. AlongPath: the way its own path goes. Needs facing enabled.
var mode: int = FaceMode.TowardAim
## Up is towards the first row of the map text, Down towards the last.
var direction: int = CardinalDirection.Down

func to_core(_c: AssetConverter) -> Step:
	var s := FaceStep.new()
	s.on = on
	s.mode = mode
	s.direction = direction
	return s
