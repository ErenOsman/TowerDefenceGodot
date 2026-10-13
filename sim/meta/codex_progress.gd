class_name CodexProgress
extends RefCounted
## What the player has discovered for the Codex (Codex — Design): enemies and statuses met in a level,
## towers ever owned. Each key is "section:id" (e.g. "Enemies:slime"). A discovered entry stays "new"
## (a dot in the Codex) until the player opens it. Tips need no discovery.

var discovered: Array = []
var viewed: Array = []

## The key of an entry.
static func key(section: int, id: String) -> String:
	return CodexSection.name_of(section) + ":" + id

## Records a discovery; returns false when it was already known (nothing to save).
func discover(section: int, id: String) -> bool:
	if id == "": return false
	var k := key(section, id)
	if discovered.has(k): return false
	discovered.append(k)
	return true

func is_discovered(section: int, id: String) -> bool:
	return section == CodexSection.Tips or discovered.has(key(section, id))

## Discovered but not opened yet in the Codex.
func is_new(section: int, id: String) -> bool:
	return section != CodexSection.Tips and is_discovered(section, id) and not viewed.has(key(section, id))

## The player opened the entry; returns false when it was already marked.
func mark_viewed(section: int, id: String) -> bool:
	if not is_new(section, id): return false
	viewed.append(key(section, id))
	return true
