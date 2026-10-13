class_name ChapterInfo
extends RefCounted
## A chapter's kind and what opens it.

var kind: int = ChapterKind.Main
## Side chapters: the levels that open it (empty: open from the start).
var requires: Array = []
## All listed levels must be won (true) or any one (false).
var require_all: bool = true
