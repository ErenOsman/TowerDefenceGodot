class_name GameData
extends RefCounted
## The root of everything saved (GameData.cs): settings, towers, progress, profile, codex. Serialised to the
## same JSON shape Unity's JsonUtility wrote (camelCase field names, enums as numbers), so a save stays
## recognisable side by side. The SaveData autoload holds the live one and writes it to user://gamedata.json.

var settings: SettingsData = SettingsData.new()
## The towers the player owns and the hand.
var towers: TowerCollection = TowerCollection.new()
## Per-level results and the last selected level.
var progress: LevelProgress = LevelProgress.new()
## The player's name, the tutorial's state and the intros seen.
var profile: PlayerProfile = PlayerProfile.new()
## What the Codex shows as discovered and what is still new.
var codex: CodexProgress = CodexProgress.new()

## Set by from_dict: the save had a "profile" (a save from before profiles is adopted as past the tutorial).
var had_profile: bool = true

func to_dict() -> Dictionary:
	return {
		"settings": settings.to_dict(),
		"towers": towers_to_dict(towers),
		"progress": progress_to_dict(progress),
		"profile": profile_to_dict(profile),
		"codex": {"discovered": codex.discovered.duplicate(), "viewed": codex.viewed.duplicate()},
	}

func to_json() -> String:
	return JSON.stringify(to_dict(), "    ", false)

static func from_dict(d) -> GameData:
	var g := GameData.new()
	if not (d is Dictionary): return g
	g.settings = SettingsData.from_dict(d.get("settings"))
	g.towers = towers_from_dict(d.get("towers"))
	g.progress = progress_from_dict(d.get("progress"))
	g.had_profile = d.has("profile")
	g.profile = profile_from_dict(d.get("profile"))
	var c = d.get("codex")
	if c is Dictionary:
		g.codex.discovered = _strings(c.get("discovered"))
		g.codex.viewed = _strings(c.get("viewed"))
	return g

## Parses a save; null when the text is not a JSON object.
static func from_json(text: String) -> GameData:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary): return null
	return from_dict(json.data)

# ---------------------------------------------------------------- meta classes

static func towers_to_dict(t: TowerCollection) -> Dictionary:
	var list := []
	for o in t.towers: list.append({"id": o.id, "type": o.type, "customName": o.custom_name})
	return {"towers": list, "hand": t.hand.duplicate()}

static func towers_from_dict(d) -> TowerCollection:
	var t := TowerCollection.new()
	if not (d is Dictionary): return t
	for o in d.get("towers", []):
		if not (o is Dictionary): continue
		var owned := OwnedTower.new()
		owned.id = _str(o.get("id"))
		owned.type = _str(o.get("type"))
		owned.custom_name = _str(o.get("customName"))
		t.towers.append(owned)
	t.hand = _strings(d.get("hand"))
	return t

static func progress_to_dict(p: LevelProgress) -> Dictionary:
	var list := []
	for r in p.levels:
		list.append({"levelId": r.level_id, "attempts": r.attempts, "wins": r.wins, "won": r.won,
			"bestBaseHpPct": r.best_base_hp_pct, "fewestRounds": r.fewest_rounds,
			"fewestTowersLost": r.fewest_towers_lost, "lastPlayed": r.last_played})
	return {"levels": list, "lastSelected": p.last_selected}

static func progress_from_dict(d) -> LevelProgress:
	var p := LevelProgress.new()
	if not (d is Dictionary): return p
	for o in d.get("levels", []):
		if not (o is Dictionary): continue
		var r := LevelRecord.new()
		r.level_id = _str(o.get("levelId"))
		r.attempts = int(o.get("attempts", 0))
		r.wins = int(o.get("wins", 0))
		r.won = bool(o.get("won", false))
		r.best_base_hp_pct = int(o.get("bestBaseHpPct", -1))
		r.fewest_rounds = int(o.get("fewestRounds", -1))
		r.fewest_towers_lost = int(o.get("fewestTowersLost", -1))
		r.last_played = _str(o.get("lastPlayed"))
		p.levels.append(r)
	p.last_selected = _str(d.get("lastSelected"))
	return p

static func profile_to_dict(p: PlayerProfile) -> Dictionary:
	return {"created": p.created, "playerName": p.player_name, "tutorial": p.tutorial,
		"campSeen": p.camp_seen, "seenIntros": p.seen_intros.duplicate()}

static func profile_from_dict(d) -> PlayerProfile:
	var p := PlayerProfile.new()
	if not (d is Dictionary): return p
	p.created = bool(d.get("created", false))
	p.player_name = _str(d.get("playerName"))
	var t = d.get("tutorial", 0)
	p.tutorial = maxi(0, TutorialState.parse(t)) if t is String else clampi(int(t), 0, TutorialState.Skipped)
	p.camp_seen = bool(d.get("campSeen", false))
	p.seen_intros = _strings(d.get("seenIntros"))
	return p

static func _str(v) -> String:
	return "" if v == null else str(v)

static func _strings(v) -> Array:
	var out := []
	if v is Array:
		for s in v:
			if s != null: out.append(str(s))
	return out
