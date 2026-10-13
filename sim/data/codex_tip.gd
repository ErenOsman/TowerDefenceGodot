class_name CodexTip
extends RefCounted
## A Codex tip: a title and a short text (with an optional picture).

## Stable ID (the save does not use it yet; keep it unique).
var id: String = ""
var title: String = ""
var text: String = ""
## A Unity sprite path ("" for none); the presentation layer maps it.
var image: String = ""
