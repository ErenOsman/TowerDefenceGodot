class_name SequenceLine
extends RefCounted
## One line of a sequence (serialised in a Sequence asset; the level fills `{player}` in).

var speaker: int = SequenceSpeaker.Base
var text: String = ""
var point_at: int = SequencePointAt.Speaker
var tile_x: int = 0
var tile_y: int = 0
var ui_element: String = ""
var continue_on: int = SequenceContinue.Click
var seconds: float = 3.0
var wait_for: int = SequenceEvent.TowerPlaced
## Whether commands wait while the line shows (intros); tutorial steps leave the player free to act.
var pauses_play: bool = true

## A copy with different text (the level fills in the player's name).
func with_text(new_text: String) -> SequenceLine:
	var copy := SequenceLine.new()
	copy.speaker = speaker
	copy.text = new_text
	copy.point_at = point_at
	copy.tile_x = tile_x
	copy.tile_y = tile_y
	copy.ui_element = ui_element
	copy.continue_on = continue_on
	copy.seconds = seconds
	copy.wait_for = wait_for
	copy.pauses_play = pauses_play
	return copy
