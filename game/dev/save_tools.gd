class_name SaveTools
extends RefCounted
## The Persistent Data tools (PersistentDataViewer.cs + the DevShortcuts cheats) as pure rules on a GameData and
## the catalog, plus reading/writing the save file, so the editor dock (no autoloads there) and the runtime F1
## panel (on SaveData.data) share them. Every quick action changes the save the way playing would (rewards
## included) and returns a line for the tool's status bar.

const PATH := "user://gamedata.json"
## The quick actions both tools show: [id, label].
const ACTIONS := [
	["grant_towers", "Grant all towers"],
	["chapter1", "Complete Chapter 1"],
	["win_first", "Win first N levels"],
	["tutorial_done", "Mark tutorial done"],
	["clear_codex", "Clear codex"],
	["unlock_forms", "Unlock all forms"],
]

## The file's text ("" when there is none).
static func read_text(path: String = PATH) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

## The save at path as a GameData (defaults when missing or not JSON).
static func load_data(path: String = PATH) -> GameData:
	var g: GameData = GameData.from_json(read_text(path)) if FileAccess.file_exists(path) else null
	return g if g != null else GameData.new()

## Writes a GameData; returns a problem or "".
static func write_data(path: String, data: GameData) -> String:
	return _write(path, data.to_json())

## Why a text is not a save ("" when it is a JSON object GameData reads).
static func check_text(text: String) -> String:
	var json := JSON.new()
	if json.parse(text) != OK: return "line %d: %s" % [json.get_error_line(), json.get_error_message()]
	if not (json.data is Dictionary): return "the save must be a JSON object"
	return ""

## Writes edited text after checking it, normalised through GameData (unknown keys dropped, defaults filled);
## returns a problem or "".
static func write_text(path: String, text: String) -> String:
	var problem := check_text(text)
	if problem != "": return problem
	return write_data(path, GameData.from_json(text))

## The save's text as GameData writes it (pretty JSON).
static func pretty(data: GameData) -> String:
	return data.to_json()

static func _write(path: String, text: String) -> String:
	var dir := ProjectSettings.globalize_path(path).get_base_dir()
	if not DirAccess.dir_exists_absolute(dir): DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return "cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(text)
	f.close()
	return ""

# ---------------------------------------------------------------- quick actions (pure)

## Sets the player's name (creating the profile when there is none); returns the name kept.
static func set_player_name(data: GameData, player_name: String) -> String:
	if not data.profile.created: data.profile.create(player_name)
	else: data.profile.player_name = PlayerProfile.clean_name(player_name)
	return data.profile.player_name

## Gives one tower of every catalog type the player owns none of (into the hand while there is room); returns how many.
static func grant_all_towers(data: GameData, catalog: GameCatalogAsset) -> int:
	if catalog == null: return 0
	var owned := {}
	for o in data.towers.towers: owned[o.type] = true
	var n := 0
	for t in catalog.tower_types:
		if t == null or owned.has(t.get_id()): continue
		var o: OwnedTower = data.towers.add(t.get_id())
		if data.towers.can_add_to_hand(o.id): data.towers.add_to_hand(o.id)
		owned[t.get_id()] = true
		n += 1
	return n

## Marks the tutorial done (creating the profile when there is none) and gives its reward once; the tower given or null.
static func mark_tutorial_done(data: GameData, catalog: GameCatalogAsset) -> TowerAsset:
	if not data.profile.created:
		data.profile.create(PlayerProfile.DefaultName)
		if catalog != null: catalog.grant_starting_towers(data.towers)
	return NewGame.finish(data, catalog, TutorialState.Done)

## Forgets everything the Codex discovered and viewed.
static func clear_codex(data: GameData) -> void:
	data.codex.discovered.clear()
	data.codex.viewed.clear()

## Runs a quick action by id on data; returns the status line. arg: the name (set_name) or N (win_first).
static func run(action: String, data: GameData, catalog: GameCatalogAsset, arg = null) -> String:
	match action:
		"set_name": return "Player name: " + set_player_name(data, str(arg))
		"grant_towers": return "Granted %d tower(s)." % grant_all_towers(data, catalog)
		"chapter1": return "Chapter 1: won %d level(s)." % DevShortcuts.complete_chapter1(data, catalog)
		"win_first": return "Won %d of the first %d level(s)." % [DevShortcuts.win_first_levels(data, catalog, int(arg)), int(arg)]
		"tutorial_done":
			var reward := mark_tutorial_done(data, catalog)
			return "Tutorial done" + (" (reward: %s)." % reward.get_display_name() if reward != null else ".")
		"clear_codex":
			clear_codex(data)
			return "Codex cleared."
		"unlock_forms": return "Unlocked %d form(s) on your towers." % unlock_all_forms(data, catalog)
		"add_tokens":
			# arg: [token id, amount] (the F1 panel's Tokens line)
			var a: Array = arg if arg is Array and arg.size() >= 2 else ["", 0]
			var token: TokenAsset = catalog.find_token(str(a[0])) if catalog != null else null
			if token == null: return "Unknown token '%s'." % str(a[0])
			data.tokens.add(token.get_id(), int(a[1]))
			return "+%d %s (now %d)." % [int(a[1]), token.get_display_name(), data.tokens.count(token.get_id())]
	return "Unknown action '%s'." % action

## Workshop cheat: unlocks every form of every owned tower's type (no tokens spent; the current forms stay).
## Returns how many unlocks it added.
static func unlock_all_forms(data: GameData, catalog: GameCatalogAsset) -> int:
	if catalog == null: return 0
	var n := 0
	for o in data.towers.towers:
		var t := catalog.find_tower(o.type)
		if t == null: continue
		for f in t.forms:
			if f != null and not o.forms.has(f.get_id()):
				o.forms.append(f.get_id())
				n += 1
	return n

## One line describing a save: name, tutorial, towers, levels won, codex entries.
static func summary(data: GameData) -> String:
	var won := 0
	for r in data.progress.levels:
		if r.won: won += 1
	return "%s · tutorial %s · %d towers (%d in hand) · %d levels won · codex %d · tokens %d" % [
		data.profile.player_name if data.profile.created else "(no profile)", TutorialState.name_of(data.profile.tutorial),
		data.towers.towers.size(), data.towers.hand.size(), won, data.codex.discovered.size(), data.tokens.total()]
