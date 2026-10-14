class_name CoopLevels
extends RefCounted
## The game side of the co-op data: the content version sent in hello (ContentHash), the co-op list (CoopList)
## built once from the co-op missions (Missions & Guild — Design: every multiplayer level is a mission; without the
## GameApp autoload it falls back to res://data/coop.json), its level assets from the catalog, the player's co-op
## hand (the saved hand's first coop_hand_cap RESTED towers), and the client-side mission checks: can_create /
## can_join (a play left today), auto_leave_reason (the host switched the room to a mission used up today),
## can_ready (a rested tower to bring) and on_match_start (the match spends a play and tires the towers taken).
## Rooms still carry level ids (the relay only knows levels): mission_for_level maps them back. Static, no Node.

static var _list: CoopList = null
static var _version := ""
## Why the last can_create / can_join / can_ready said no ("" when it said yes).
static var last_reason := ""

static func list() -> CoopList:
	if _list == null:
		var ms := missions()
		_list = CoopList.from_missions(ms) if not ms.is_empty() else CoopList.load()
	return _list

## Forgets the cached list (tests, content reloads).
static func reset() -> void:
	_list = null

## The co-op missions (Coop / Any), in board order ([] without the GameApp autoload).
static func missions() -> Array:
	var app = _app()
	return MissionBoard.coop_missions(app.missions()) if app != null else []

## A co-op mission by id, or null.
static func mission(mission_id: String) -> MissionDef:
	return MissionBoard.find(missions(), mission_id)

## The co-op mission a room's level plays, or null (a level no co-op mission uses).
static func mission_for_level(level_id: String) -> MissionDef:
	return MissionBoard.for_level(missions(), level_id)

## What the lobby shows for a room's level: the mission's name, else the level's.
static func room_title(level_id: String) -> String:
	var m := mission_for_level(level_id)
	return m.name if m != null else level_name(level_id)

## Plays of the room level's mission left today for this player (0 for a level that is no mission).
static func plays_left(level_id: String, now = null) -> int:
	return MissionBoard.plays_left(mission_for_level(level_id), _progress(), now)

## The client may create a room set to this level: it is a co-op mission with a play left today. Check before
## sending `create`; last_reason ("Done today · resets in 5 h", "Not a mission") otherwise.
static func can_create(level_id: String, now = null) -> bool:
	return _check(level_id, now)

## The client may join a room (its Dictionary from the relay's room list, or its level id): same rule. Check
## before sending `join`; the lobby shows "Done today" on such rooms and disables Join.
static func can_join(room, now = null) -> bool:
	return _check(str(room.get("level", "")) if room is Dictionary else str(room), now)

static func _check(level_id: String, now) -> bool:
	var m := mission_for_level(level_id)
	if m == null:
		last_reason = "Not a mission"
		return false
	var ok := MissionBoard.can_join(m, _progress(), now)
	last_reason = MissionBoard.last_reason
	return ok

## The auto-leave rule, for the room screen on every `room` message: the room's level is a mission this player
## has used up today → send `leave` and show this ("Done today: the room switched to Night Watch"); "" = stay.
## A room that started (the match runs) never drops anyone.
static func auto_leave_reason(room: Dictionary, now = null) -> String:
	if room.is_empty() or bool(room.get("started", false)): return ""
	return MissionBoard.auto_leave_reason(mission_for_level(str(room.get("level", ""))), _progress(), now)

## Ready is allowed: the hand brings at least one rested tower to the room's mission (last_reason: the all-tired
## line otherwise). Levels that are no mission: always.
static func can_ready(level_id: String, now = null) -> bool:
	var sd = _node("SaveData")
	if sd == null or mission_for_level(level_id) == null:
		last_reason = ""
		return true
	var ok := MissionBoard.can_bring(sd.towers.hand, sd.missions, hand_cap(level_id), now)
	last_reason = MissionBoard.last_reason
	return ok

## The room's hand strip note: "1 tired: the next rested tower goes" ("" when none of the first cap towers is tired).
static func tired_note(cap: int, now = null) -> String:
	var sd = _node("SaveData")
	if sd == null: return ""
	var n := 0
	for id in sd.towers.hand.slice(0, cap):
		if MissionBoard.is_tired(id, sd.missions, now): n += 1
	return "" if n == 0 else "%d tired: the next rested tower%s" % [n, " goes" if n == 1 else "s go"]

## The relay started a match (match_start / match_ready info): when its level is a mission, spends one of today's
## plays and tires this player's towers taken (the hand's first rested ones up to the mission's cap, the same ones
## my_hand_types sent), then saves. Returns the owned tower ids tired ([] for a level that is no mission).
static func on_match_start(info: Dictionary, now = null) -> Array:
	var m := mission_for_level(str(info.get("level", "")))
	var sd = _node("SaveData")
	if m == null or sd == null: return []
	var taken := MissionBoard.taken(sd.towers.hand, sd.missions, m.coop_hand_cap, now)
	MissionBoard.record_play(m, sd.missions, taken, now)
	if sd.has_method("save"): sd.save()
	return taken

## The content hash (16 hex) both clients must share; cached.
static func content_version() -> String:
	if _version == "": _version = ContentHash.compute()
	return _version

static func shared_pool(level_id: String) -> bool:
	return list().shared_pool(level_id)

static func hand_cap(level_id: String) -> int:
	return list().hand_cap(level_id)

## The co-op levels' assets (unknown ids skipped), in list order.
static func level_assets() -> Array:
	var app = _app()
	return list().level_assets(app.catalog) if app != null else []

static func level_asset(level_id: String) -> LevelAsset:
	var app = _app()
	if app == null or app.catalog == null: return null
	return app.catalog.find_level(level_id)

## The level's name for players (the id when it is unknown).
static func level_name(level_id: String) -> String:
	var a := level_asset(level_id)
	return a.get_display_name() if a != null else level_id

## "Shared pool · 100, +12 a round" / "Separate energy · 1/4 each · 25 each, +3 a round".
static func energy_text(level_id: String, players: int) -> String:
	var a := level_asset(level_id)
	if a == null: return ""
	if shared_pool(level_id): return "Shared pool · %d, +%d a round" % [a.start_energy, a.energy_per_round]
	var n := maxi(1, players)
	return "Separate energy · 1/%d each · %d each, +%d a round" % [n, a.start_energy / n, a.energy_per_round / n]

## The tower TYPE ids the player brings (the protocol's `hand`): the saved hand's owned RESTED towers (tired ones
## skipped: every co-op level is a mission), in order, cut to cap. A formed tower is sent as "<type id>@<form id>"
## (CoopSession.hand_entry; the relay never reads it).
static func my_hand_types(cap: int, now = null) -> Array:
	var sd = _node("SaveData")
	var out := []
	if sd == null: return out
	for id in MissionBoard.rested_hand(sd.towers.hand, sd.missions, now):
		var owned = sd.towers.find(id)
		if owned != null: out.append(CoopSession.hand_entry(owned.type, owned.form))
		if out.size() >= cap: break
	return out

## A TowerAsset by type id or hand entry ("archer@archer-fire" → the Archer; for pictures), or null.
static func tower_asset(type_id: String) -> TowerAsset:
	var app = _app()
	return app.catalog.find_tower(CoopSession.parse_hand_entry(type_id)[0]) if app != null and app.catalog != null else null

## The FormAsset of a hand entry ("archer@archer-fire"), or null for the default form.
static func form_asset(entry: String) -> FormAsset:
	var app = _app()
	var form_id: String = CoopSession.parse_hand_entry(entry)[1]
	return app.catalog.find_form(form_id) if form_id != "" and app != null and app.catalog != null else null

static func _progress() -> MissionProgress:
	var sd = _node("SaveData")
	return sd.missions if sd != null else null

static func _app():
	return _node("GameApp")

static func _node(n: String):
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(n) if tree != null else null
