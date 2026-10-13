class_name OverlayMarker
extends RefCounted
## What shows over one entity besides its plate (MarkerLayer.cs OverlayMarker): a chip with a word or number (a
## forecast's "-6", "+4", a "Kills" tag) and a row of pips.

var id: int = -1
## The chip's background (e.g. the kit's tag_kills); null: a bare word.
var chip: Texture2D = null
var text: String = ""
var text_color: Color = Color.WHITE
## One texture per pip, or empty.
var pips: Array = []

func _init(p_id: int = -1) -> void:
	id = p_id
