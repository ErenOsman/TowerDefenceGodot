class_name CoopList
extends RefCounted
## The Multiplayer station's level list, kept like a chapter (Multiplayer — Design, co-op: "Levels"):
## res://data/coop.json → {"id", "displayName", "levels": [{"level": level id, "sharedPool": bool,
## "coopHandCap": int}]}. Every level in it can be played co-op; no locks for now.
## Godot-only for now: these fields should move into the Unity content (see docs/GODOT-NOTES.md).

const Path := "res://data/coop.json"
const DefaultHandCap := 3

var id: String = "multiplayer"
var display_name: String = "Multiplayer"
## Array of {"level_id": String, "shared_pool": bool, "coop_hand_cap": int}, in list order.
var levels: Array = []
## Why the last load/parse failed ("" when it worked).
var last_error: String = ""

static func load(path: String = Path) -> CoopList:
	if not FileAccess.file_exists(path):
		var l := CoopList.new()
		l.last_error = "No co-op list at " + path
		return l
	return parse(FileAccess.get_file_as_string(path))

static func parse(text: String) -> CoopList:
	var l := CoopList.new()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		l.last_error = "Bad co-op list JSON: " + json.get_error_message()
		return l
	var d: Dictionary = json.data
	l.id = str(d.get("id", l.id))
	l.display_name = str(d.get("displayName", l.display_name))
	for e in d.get("levels", []):
		if not (e is Dictionary) or not (e.get("level") is String) or e.level == "": continue
		l.levels.append({
			"level_id": e.level,
			"shared_pool": bool(e.get("sharedPool", false)),
			"coop_hand_cap": int(e.get("coopHandCap", DefaultHandCap)),
		})
	return l

## The entry of a level, or null when the level is not in the list.
func find(level_id: String) -> Variant:
	for e in levels:
		if e.level_id == level_id: return e
	return null

func level_ids() -> Array:
	var out := []
	for e in levels: out.append(e.level_id)
	return out

## No co-op locks for now: every listed level can be picked.
func is_unlocked(level_id: String) -> bool:
	return find(level_id) != null

func shared_pool(level_id: String) -> bool:
	var e = find(level_id)
	return e != null and e.shared_pool

func hand_cap(level_id: String) -> int:
	var e = find(level_id)
	return e.coop_hand_cap if e != null else DefaultHandCap

## The listed levels' assets from the game catalog (unknown ids skipped), in list order.
func level_assets(catalog: GameCatalogAsset) -> Array:
	var out := []
	if catalog == null: return out
	for e in levels:
		var a := catalog.find_level(e.level_id)
		if a != null: out.append(a)
	return out
