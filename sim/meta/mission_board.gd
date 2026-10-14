class_name MissionBoard
extends RefCounted
## The mission rules (Missions & Guild — Design § Rules), engine-free and static: the Guild's unlock, a mission's
## unlock, plays per day (spent at start, reset at local midnight), tower energy (a tower that went on a mission
## today is tired until the reset), starting a play, the drops of a result, where a token drops, and the co-op
## checks (create / join / the auto-leave rule). Godot-first (Unity: Game.Meta.MissionBoard).
##
## `now` is injectable everywhere it matters so tests are deterministic: null = the system's local time
## (Time.get_datetime_dict_from_system()), a Dictionary like that one ({year, month, day, hour, minute, second}),
## or a String "YYYY-MM-DD" / "YYYY-MM-DDTHH:MM[:SS]" (local time). Days compare as "YYYY-MM-DD".
## Hands are Arrays of owned tower ids (Strings) or of objects with an `id` (TowerDef); results keep the element type.

## Why the last check said no ("" when it said yes) — the C# `out string reason`.
static var last_reason: String = ""

## Missions a tower can go on per day (the rules' towerEnergyPerDay; GameApp sets it from the content, default 1).
static var energy_per_day: int = 1

const SecondsPerDay := 86400
const AllTired := "All your towers are tired: change your hand or come back tomorrow"
const EmptyHand := "No towers in your hand"

# ------------------------------------------------------------------ time

## The system's local time now.
static func now() -> Dictionary:
	return Time.get_datetime_dict_from_system()

## now as {year, month, day, hour, minute, second} (see the class doc for the accepted forms).
static func when_of(now_value) -> Dictionary:
	var n = now_value if now_value != null else now()
	if n is String:
		var s: String = n.strip_edges()
		var date := s.substr(0, 10).split("-")
		var time := s.substr(11).trim_suffix("Z").split(":") if s.length() > 11 else PackedStringArray()
		var at := func(a: PackedStringArray, i: int, d: int) -> int: return int(a[i]) if i < a.size() and a[i].strip_edges() != "" else d
		return {"year": at.call(date, 0, 1970), "month": at.call(date, 1, 1), "day": at.call(date, 2, 1),
			"hour": at.call(time, 0, 0), "minute": at.call(time, 1, 0), "second": int(float(time[2])) if time.size() > 2 else 0}
	if n is Dictionary:
		return {"year": int(n.get("year", 1970)), "month": int(n.get("month", 1)), "day": int(n.get("day", 1)),
			"hour": int(n.get("hour", 0)), "minute": int(n.get("minute", 0)), "second": int(n.get("second", 0))}
	return when_of(null)

## The local calendar date of now: "2026-10-14".
static func day_of(now_value = null) -> String:
	var w := when_of(now_value)
	return "%04d-%02d-%02d" % [w.year, w.month, w.day]

## Seconds until the next local midnight (the daily reset): 1..86400. Daylight-saving shifts are ignored.
static func resets_in(now_value = null) -> int:
	var w := when_of(now_value)
	return SecondsPerDay - clampi(w.hour * 3600 + w.minute * 60 + w.second, 0, SecondsPerDay - 1)

## A wait as players read it: whole hours rounded up ("5 h") from an hour on, else minutes rounded up ("20 min").
static func duration_text(seconds: int) -> String:
	if seconds >= 3600: return "%d h" % ceili(seconds / 3600.0)
	return "%d min" % maxi(1, ceili(seconds / 60.0))

## "resets in 5 h" / "resets in 20 min".
static func resets_in_text(now_value = null) -> String:
	return "resets in " + duration_text(resets_in(now_value))

## A used-up mission: "Done today · resets in 5 h".
static func done_text(now_value = null) -> String:
	return "Done today · " + resets_in_text(now_value)

## A tired tower: "Tired · rests in 5 h".
static func tired_text(now_value = null) -> String:
	return "Tired · rests in " + duration_text(resets_in(now_value))

# ------------------------------------------------------------------ unlock

## The Guild (and the Signpost's Missions) is open: the catalog's guildUnlock level is won. Reason when not:
## "Win The Glutton to open the Guild" ("The Guild is not in this game" without a guildUnlock).
static func is_guild_unlocked(progress: LevelProgress, catalog: GameCatalogAsset) -> bool:
	if catalog == null or catalog.guild_unlock == null:
		last_reason = "The Guild is not in this game"
		return false
	if catalog.guild_unlocked(progress):
		last_reason = ""
		return true
	last_reason = "Win %s to open the Guild" % catalog.guild_unlock.get_display_name()
	return false

## A mission is open: the Guild is (skipped when catalog is null) and its requirement is met — every listed level
## or mission won (requireAll) or any one of them; none listed = open with the Guild. Reasons: the Guild's, or
## "Win Rock Garden first" / "Win Rock Garden and Night Watch first" / "Win Rock Garden or Night Watch first".
static func is_unlocked(mission: MissionDef, progress: LevelProgress, mission_progress: MissionProgress, catalog: GameCatalogAsset = null) -> bool:
	if mission == null:
		last_reason = "No mission"
		return false
	if catalog != null and not is_guild_unlocked(progress, catalog): return false
	var missing := []
	var met := 0
	for id in mission.requires:
		var won: bool = (progress != null and progress.is_won(id)) or (mission_progress != null and mission_progress.is_won(id))
		if won: met += 1
		else: missing.append(id)
	var ok: bool = mission.requires.is_empty() or (missing.is_empty() if mission.require_all else met > 0)
	if ok:
		last_reason = ""
		return true
	var names := []
	for id in (missing if mission.require_all else mission.requires): names.append(_name_of(id, catalog))
	last_reason = "Win %s first" % _join(names, " and " if mission.require_all else " or ")
	return false

# ------------------------------------------------------------------ plays

## Plays of the mission left today: playsPerDay − plays spent on now's date (never below 0).
static func plays_left(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> int:
	if mission == null: return 0
	var used := mission_progress.plays_on(mission.id, day_of(now_value)) if mission_progress != null else 0
	return maxi(0, maxi(1, mission.plays_per_day) - used)

## A play is left today. Reason when not: "Done today · resets in 5 h".
static func can_play(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> bool:
	if mission == null:
		last_reason = "No mission"
		return false
	if plays_left(mission, mission_progress, now_value) <= 0:
		last_reason = done_text(now_value)
		return false
	last_reason = ""
	return true

## "1 play left today" / "2 plays left today" / "Done today · resets in 5 h".
static func plays_text(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> String:
	var n := plays_left(mission, mission_progress, now_value)
	if n <= 0: return done_text(now_value)
	return "%d play%s left today" % [n, "" if n == 1 else "s"]

## The detail's pips line: "1 of 1 play left today" / "0 of 2 plays left today".
static func plays_of_text(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> String:
	var total := maxi(1, mission.plays_per_day) if mission != null else 1
	return "%d of %d play%s left today" % [plays_left(mission, mission_progress, now_value), total, "" if total == 1 else "s"]

## The board's mode chip: "Solo" / "Co-op 2–6" / "Any".
static func mode_text(mission: MissionDef) -> String:
	if mission == null: return ""
	match mission.mode:
		MissionMode.Coop: return "Co-op %d–%d" % [mission.min_players, mission.max_players]
		MissionMode.Any: return "Any"
	return "Solo"

# ------------------------------------------------------------------ tower energy

## The tower went on as many missions today as the rules allow (energy_per_day): tired until the reset.
static func is_tired(tower_id: String, mission_progress: MissionProgress, now_value = null) -> bool:
	if mission_progress == null or tower_id == "": return false
	return mission_progress.uses_on(tower_id, day_of(now_value)) >= maxi(1, energy_per_day)

## The hand without its tired towers, in hand order.
static func rested_hand(hand: Array, mission_progress: MissionProgress, now_value = null) -> Array:
	var out := []
	for t in hand:
		if not is_tired(_id_of(t), mission_progress, now_value): out.append(t)
	return out

## The towers a mission would take now: the hand's first rested ones up to cap (the "▲ goes" marks).
static func taken(hand: Array, mission_progress: MissionProgress, cap: int, now_value = null) -> Array:
	var out := []
	var seen := {}
	for t in rested_hand(hand, mission_progress, now_value):
		if out.size() >= cap: break
		var id := _id_of(t)
		if id == "" or seen.has(id): continue
		seen[id] = true
		out.append(t)
	return out

## Whether the hand would bring at least one rested tower (Play / Ready). Reasons: EmptyHand, AllTired.
static func can_bring(hand: Array, mission_progress: MissionProgress, cap: int, now_value = null) -> bool:
	if hand.is_empty() or cap <= 0:
		last_reason = EmptyHand
		return false
	if taken(hand, mission_progress, cap, now_value).is_empty():
		last_reason = AllTired
		return false
	last_reason = ""
	return true

## Whether the mission can start now with this hand: a play left today and a rested tower to bring.
static func can_start(mission: MissionDef, mission_progress: MissionProgress, hand: Array, cap: int, now_value = null) -> bool:
	if not can_play(mission, mission_progress, now_value): return false
	return can_bring(hand, mission_progress, cap, now_value)

## Starts a play (the level starts): spends one of today's plays and tires the towers taken (the hand's first
## rested ones up to cap); returns them. Refused ([] and last_reason) when no play is left or no rested tower would
## come in ("All your towers are tired: change your hand or come back tomorrow"); nothing changes then.
static func start_play(mission: MissionDef, mission_progress: MissionProgress, hand: Array, cap: int, now_value = null) -> Array:
	if mission_progress == null or not can_start(mission, mission_progress, hand, cap, now_value): return []
	var out := taken(hand, mission_progress, cap, now_value)
	record_play(mission, mission_progress, out, now_value)
	return out

## Spends the play and the towers' energy without checking (a co-op match start: the relay already started it).
static func record_play(mission: MissionDef, mission_progress: MissionProgress, towers: Array, now_value = null) -> void:
	if mission == null or mission_progress == null: return
	var day := day_of(now_value)
	mission_progress.add_play(mission.id, day)
	for t in towers:
		var id := _id_of(t)
		if id != "": mission_progress.tire(id, day)

# ------------------------------------------------------------------ rewards

## The tokens a mission result gives: winTokens on every win, firstWinTokens once (record = what
## MissionProgress.record returned, wins == 1); nothing on a loss or a quit. {token id: amount}.
static func drops(result: LevelResult, record: LevelRecord, mission: MissionDef) -> Dictionary:
	return Workshop.drops(result, record, mission)

## Records a mission's result (under the mission id, never in the chapter progress) and gives its drops to the
## wallet; returns the drops ({} on a loss or quit). What the level does when a mission ends (LevelController._record).
static func finish(result: LevelResult, mission: MissionDef, mission_progress: MissionProgress, wallet: TokenWallet) -> Dictionary:
	if result == null or mission == null or mission_progress == null: return {}
	var record := mission_progress.record(result, mission.id)
	var out := drops(result, record, mission)
	if wallet != null: wallet.add_all(out)
	return out

## The ids of the missions that drop a token, in board order (the Workshop's "Found in").
static func found_in(token_id: String, missions: Array) -> Array:
	return Workshop.found_in(token_id, missions)

## "Night Watch and Drum Line" / "Patrol, Night Watch and Drum Line" ("" when no mission drops it).
static func found_in_text(token_id: String, missions: Array) -> String:
	var names := []
	for m in missions:
		if m != null and m.drops_token(token_id): names.append(m.name)
	return _join(names, " and ")

# ------------------------------------------------------------------ lists and co-op

## A mission by id in a list, or null.
static func find(missions: Array, mission_id: String) -> MissionDef:
	for m in missions:
		if m != null and m.id == mission_id: return m
	return null

## The co-op missions (Coop / Any) of a list, in order: the lobby's list.
static func coop_missions(missions: Array) -> Array:
	return missions.filter(func(m): return m != null and m.is_coop)

## The first co-op mission playing a level (rooms carry level ids), or null.
static func for_level(missions: Array, level_id: String) -> MissionDef:
	for m in missions:
		if m != null and m.is_coop and m.level_id == level_id: return m
	return null

## The client may create a room set to the mission: a co-op mission with a play left today.
## Reasons: "Not a co-op mission", "Done today · resets in 5 h".
static func can_create(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> bool:
	if mission != null and not mission.is_coop:
		last_reason = "Not a co-op mission"
		return false
	return can_play(mission, mission_progress, now_value)

## The client may join a room set to the mission (same rule as creating one).
static func can_join(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> bool:
	return can_create(mission, mission_progress, now_value)

## The auto-leave rule: the room is now set to a mission with no play left today → the client leaves and shows this
## ("Done today: the room switched to Night Watch"); "" = stay.
static func auto_leave_reason(mission: MissionDef, mission_progress: MissionProgress, now_value = null) -> String:
	if mission == null or plays_left(mission, mission_progress, now_value) > 0: return ""
	return "Done today: the room switched to %s" % mission.name

# ------------------------------------------------------------------ helpers

static func _id_of(t) -> String:
	if t is String: return t
	if t is Object and "id" in t: return str(t.id)
	return ""

static func _name_of(id: String, catalog: GameCatalogAsset) -> String:
	if catalog != null:
		var l := catalog.find_level(id)
		if l != null: return l.get_display_name()
		var m := catalog.find_mission(id)
		if m != null: return m.get_display_name()
	return id

static func _join(names: Array, last: String) -> String:
	if names.is_empty(): return ""
	if names.size() == 1: return str(names[0])
	return ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + last + str(names[names.size() - 1])
