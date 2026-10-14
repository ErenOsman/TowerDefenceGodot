class_name MissionProgress
extends RefCounted
## What the save keeps about missions (Missions & Guild — Design § Saves), apart from the chapter progress they
## never change: a record per mission id (attempts, wins, best values: a LevelRecord whose level_id holds the
## mission id), the plays spent per mission and day, and the towers' mission energy spent per day. Days are
## local calendar dates "YYYY-MM-DD" (MissionBoard.day_of). The rules reading it live in MissionBoard.
## Godot-first (Unity: Game.Meta.MissionProgress). Saved in GameData under "missions".

## Array of LevelRecord (level_id = the mission id), in first-played order.
var records: Array = []
## Array of {"id": mission id, "day": "YYYY-MM-DD", "count": plays spent that day}; one entry per mission (a new day
## replaces the old one).
var plays: Array = []
## Array of {"tower": owned tower id, "day": "YYYY-MM-DD", "count": missions gone on that day}; one entry per tower.
var tired: Array = []
## Why the last record() failed; "" otherwise.
var last_error: String = ""

## The record of a mission, or null when it was never played.
func find(mission_id: String) -> LevelRecord:
	for r in records:
		if r.level_id == mission_id: return r
	return null

func is_won(mission_id: String) -> bool:
	var r := find(mission_id)
	return r != null and r.won

## Adds one play's result under the mission id (every result is an attempt; a win also updates the best values),
## like LevelProgress.record. mission_id "" = result.level_id. Null (and last_error) without an id.
func record(result: LevelResult, mission_id: String = "") -> LevelRecord:
	var id := mission_id if mission_id != "" else (result.level_id if result != null else "")
	if result == null or id == "":
		last_error = "A mission result needs its mission id."
		return null
	last_error = ""
	var r := find(id)
	if r == null:
		r = LevelRecord.new()
		r.level_id = id
		records.append(r)
	r.attempts += 1
	if result.when != "": r.last_played = result.when
	if result.quit or not result.won: return r
	r.wins += 1
	r.won = true
	r.best_base_hp_pct = maxi(r.best_base_hp_pct, clampi(result.base_hp_pct, 0, 100))
	r.fewest_rounds = result.rounds if r.fewest_rounds < 0 else mini(r.fewest_rounds, result.rounds)
	r.fewest_towers_lost = result.towers_lost if r.fewest_towers_lost < 0 else mini(r.fewest_towers_lost, result.towers_lost)
	return r

## Plays of a mission spent on a day.
func plays_on(mission_id: String, day: String) -> int:
	for p in plays:
		if p.id == mission_id: return int(p.count) if p.day == day else 0
	return 0

## Spends one play of a mission on a day (an older day's count is replaced).
func add_play(mission_id: String, day: String) -> void:
	for p in plays:
		if p.id == mission_id:
			p.count = (int(p.count) if p.day == day else 0) + 1
			p.day = day
			return
	plays.append({"id": mission_id, "day": day, "count": 1})

## Missions a tower went on that day.
func uses_on(tower_id: String, day: String) -> int:
	for t in tired:
		if t.tower == tower_id: return int(t.count) if t.day == day else 0
	return 0

## Spends one of a tower's mission energy on a day.
func tire(tower_id: String, day: String) -> void:
	for t in tired:
		if t.tower == tower_id:
			t.count = (int(t.count) if t.day == day else 0) + 1
			t.day = day
			return
	tired.append({"tower": tower_id, "day": day, "count": 1})

## Dev: today's plays back and every tower rested (records stay).
func rest_all() -> void:
	plays.clear()
	tired.clear()

## Save form: {"records": [{missionId, attempts, wins, won, bestBaseHpPct, fewestRounds, fewestTowersLost,
## lastPlayed}], "plays": [{id, day, count}], "tired": [{tower, day, count}]}.
func to_dict() -> Dictionary:
	var list := []
	for r in records:
		list.append({"missionId": r.level_id, "attempts": r.attempts, "wins": r.wins, "won": r.won,
			"bestBaseHpPct": r.best_base_hp_pct, "fewestRounds": r.fewest_rounds,
			"fewestTowersLost": r.fewest_towers_lost, "lastPlayed": r.last_played})
	var p := []
	for e in plays: p.append({"id": e.id, "day": e.day, "count": int(e.count)})
	var t := []
	for e in tired: t.append({"tower": e.tower, "day": e.day, "count": int(e.count)})
	return {"records": list, "plays": p, "tired": t}

## Reads the save form; anything missing or malformed is skipped (a save from before missions: empty).
## A tired entry without "count" counts 1 (the design doc's {tower, day} shape).
static func from_dict(d) -> MissionProgress:
	var m := MissionProgress.new()
	if not (d is Dictionary): return m
	for o in _list(d.get("records")):
		var id := _str(o.get("missionId"))
		if id == "" or m.find(id) != null: continue
		var r := LevelRecord.new()
		r.level_id = id
		r.attempts = int(o.get("attempts", 0))
		r.wins = int(o.get("wins", 0))
		r.won = bool(o.get("won", false))
		r.best_base_hp_pct = int(o.get("bestBaseHpPct", -1))
		r.fewest_rounds = int(o.get("fewestRounds", -1))
		r.fewest_towers_lost = int(o.get("fewestTowersLost", -1))
		r.last_played = _str(o.get("lastPlayed"))
		m.records.append(r)
	var seen := {}
	for o in _list(d.get("plays")):
		var id := _str(o.get("id"))
		if id == "" or seen.has(id): continue
		seen[id] = true
		m.plays.append({"id": id, "day": _str(o.get("day")), "count": maxi(0, int(o.get("count", 1)))})
	seen = {}
	for o in _list(d.get("tired")):
		var id := _str(o.get("tower"))
		if id == "" or seen.has(id): continue
		seen[id] = true
		m.tired.append({"tower": id, "day": _str(o.get("day")), "count": maxi(0, int(o.get("count", 1)))})
	return m

static func _list(v) -> Array:
	var out := []
	if v is Array:
		for o in v:
			if o is Dictionary: out.append(o)
	return out

static func _str(v) -> String:
	return "" if v == null else str(v)
