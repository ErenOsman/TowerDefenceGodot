extends Node
## Autoload `SaveData` (PersistentDataManager.cs + NewGame.cs): the live GameData, saved as JSON in
## user://gamedata.json. Change fields directly (SaveData.towers.add(...), SaveData.profile.camp_seen = true…)
## and call save(). A missing save starts from defaults (and is written); a save from before profiles existed
## (no "profile" key) is adopted as past the tutorial.

signal saved
signal loaded

const PATH := "user://gamedata.json"

var data: GameData = GameData.new()
## The path in use (tests or tools may point it elsewhere before load()).
var path: String = PATH

var settings: SettingsData:
	get: return data.settings
var towers: TowerCollection:
	get: return data.towers
var progress: LevelProgress:
	get: return data.progress
var profile: PlayerProfile:
	get: return data.profile
var codex: CodexProgress:
	get: return data.codex
## The Workshop tokens (Workshop — Design).
var tokens: TokenWallet:
	get: return data.tokens
## Mission records, today's plays and tired towers (Missions & Guild — Design).
var missions: MissionProgress:
	get: return data.missions

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()

## Writes the save. Returns false when the file could not be written.
func save() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveData] cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(data.to_json())
	f.close()
	saved.emit()
	return true

## Loads the save (defaults, written at once, when there is none or it cannot be read).
func load_data() -> void:
	var parsed: GameData = null
	if FileAccess.file_exists(path):
		parsed = GameData.from_json(FileAccess.get_file_as_string(path))
		if parsed == null: push_warning("[SaveData] %s is not valid JSON: starting from defaults" % path)
	if parsed == null:
		data = GameData.new()
		save()
	else:
		data = parsed
		# a save from before profiles existed: its player is past the first run. A save whose profile is not
		# created yet is a first launch left at the Welcome screen: still a first run.
		if not data.had_profile and data.profile.adopt_existing_save(): save()
	loaded.emit()

## Same as load_data() (the brief's name; inside this script `load` is the global resource loader).
func load() -> void:
	load_data()

## Every field back to its defaults, saved at once.
func reset() -> void:
	data = GameData.new()
	save()
	loaded.emit()

# ---------------------------------------------------------------- new game (NewGame.cs)

## Creates the profile and starting towers, then plays the tutorial (or, skipped or missing, gives its
## reward and opens the main menu).
func begin(player_name: String, play_tutorial: bool) -> void:
	var catalog: GameCatalogAsset = GameApp.catalog
	NewGame.create_profile(data, catalog, player_name)
	save()
	if play_tutorial and catalog != null and catalog.tutorial != null:
		GameApp.play_level(catalog.tutorial)
	else:
		skip_tutorial()
		SceneFlow.go(SceneFlow.MainMenu)

## Marks the tutorial skipped and gives its reward (once); the TowerAsset given, or null.
func skip_tutorial() -> TowerAsset:
	return _finish(TutorialState.Skipped)

## Marks the tutorial done and gives its reward (once); the TowerAsset given, or null.
func complete_tutorial() -> TowerAsset:
	return _finish(TutorialState.Done)

func _finish(state: int) -> TowerAsset:
	if not data.profile.tutorial_pending: return null
	var reward := NewGame.finish(data, GameApp.catalog, state)
	save()
	return reward
