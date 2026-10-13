class_name CatalogEntry
extends RefCounted
## One level in the catalog: its id, its chapter and what opens it.

var level_id: String = ""
var chapter: int = 0
var requirement: int = RequirementKind.Previous
var requires: Array = []
## For Levels: all listed levels must be won (true) or any one (false).
var require_all: bool = true
