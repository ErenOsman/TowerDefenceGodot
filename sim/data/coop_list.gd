class_name CoopList
extends RefCounted
## The co-op level list (Multiplayer — Design, co-op: "Levels"). Since Missions & Guild — Design (2026-10-14) every
## multiplayer level is a mission: the game builds it from the co-op missions (from_missions; each entry also
## carries its mission_id). res://data/coop.json → {"id", "displayName", "levels": [{"level": level id,
## "sharedPool": bool, "coopHandCap": int}]} is kept only for the relay's shared_pool lookup (it reads that file)
## and is generated from the missions (to_json_text; tools/coop_json.gd); a test keeps the two in sync.

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
			"mission_id": str(e.get("mission", "")),
		})
	return l

## The list built from missions (MissionDef; only the co-op ones, Coop / Any, in order). A level two missions play
## keeps its first mission.
static func from_missions(missions: Array) -> CoopList:
	var l := CoopList.new()
	for m in MissionBoard.coop_missions(missions):
		if m.level_id == "" or l.find(m.level_id) != null: continue
		l.levels.append({"level_id": m.level_id, "shared_pool": m.shared_pool, "coop_hand_cap": m.coop_hand_cap, "mission_id": m.id})
	return l

## The coop.json text of this list (the relay reads "level" and "sharedPool").
func to_json_text() -> String:
	var list := []
	for e in levels: list.append({"level": e.level_id, "sharedPool": e.shared_pool, "coopHandCap": e.coop_hand_cap, "mission": e.get("mission_id", "")})
	return JSON.stringify({"id": id, "displayName": display_name, "levels": list}, "\t", false) + "\n"

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
