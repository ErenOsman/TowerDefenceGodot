class_name TowerIds
extends RefCounted
## Tower IDs are GUIDs ("80a8ee3c-7e0c-4ff1-b4de-7490cd8b9aa1"): 122 random bits, unique without
## checking, also across players (trading, servers). Created outside battles, never from a battle's
## seeded RNG. Show short(id) where people read it.
## Port note: C# TowerIds.New() → new_id() (`new` is the GDScript constructor).

const _HEX := "0123456789abcdef"

## A fresh random (version 4) GUID, lower-case with hyphens like Guid.ToString().
static func new_id() -> String:
	var s := ""
	for i in 32:
		var v := randi() % 16
		if i == 12: v = 4                     # version 4
		elif i == 16: v = 8 + (v % 4)         # RFC 4122 variant
		s += _HEX[v]
		if i == 7 or i == 11 or i == 15 or i == 19: s += "-"
	return s

## Whether id parses as a GUID (Guid.TryParse: 32 hex digits, optionally hyphenated 8-4-4-4-12,
## optionally in braces or parentheses; surrounding white space allowed).
static func is_valid(id: String) -> bool:
	var s := id.strip_edges()
	if s.length() >= 2 and ((s.begins_with("{") and s.ends_with("}")) or (s.begins_with("(") and s.ends_with(")"))):
		s = s.substr(1, s.length() - 2)
		if s.length() != 36: return false
	if s.length() == 32: return _all_hex(s)
	if s.length() != 36: return false
	for i in [8, 13, 18, 23]:
		if s[i] != "-": return false
	return _all_hex(s.replace("-", "")) and s.replace("-", "").length() == 32

static func _all_hex(s: String) -> bool:
	for c in s.to_lower():
		if not _HEX.contains(c): return false
	return true

## The first 8 characters: enough to tell a player's towers apart on screen.
static func short(id: String) -> String:
	if id == "": return ""
	return id if id.length() <= 8 else id.substr(0, 8)
