class_name ChapterData
extends RefCounted
## A chapter of the game catalog: its levels in play order and what opens it.

## Stable chapter ID, e.g. "meadow".
var id: String = ""
var display_name: String = ""
## Main: the story, opened by the main chapter before it. Side: extra, opened by the levels listed below.
var kind: int = ChapterKind.Main
## Side chapters: the levels that open it (empty: open from the start). Array of LevelAsset.
var requires: Array = []
## Side chapters: all listed levels must be won (on) or any one (off).
var require_all: bool = true
## Array of CatalogLevelData.
var levels: Array = []
