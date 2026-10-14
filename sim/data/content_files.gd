class_name ContentFiles
extends RefCounted
## Where content lives: the JSON file of each asset type (Content/<Type>.json; res://data/content here) and the
## asset path an entry key names.

## The content JSON folder in this project (C# Folder = "Content", relative to the Unity project).
const Folder := "res://data/content"

## Godot-only content overlay (Workshop forms/tokens and their entities, Missions, the catalog's guild fields and the
## rules' tower energy) merged over Folder by ContentLibrary.load_game() and hashed by ContentHash.compute(); see
## docs/GODOT-NOTES.md "Workshop & Missions content". Delete it when the Unity repo has Forms/Tokens/Missions.json.
const OverlayFolder := "res://data/content-godot"

## The overlay's field patches for assets the synced content already has:
## { "<asset key>": { "<field>": value, … } } (the catalog's guildUnlock / missions, the rules' towerEnergyPerDay).
const ExtrasFile := "Extras.json"

## Where content assets live in the Unity project; keys are paths under it without ".asset".
const DataRoot := "Assets/Data"

const FILES := {
	"TowerAsset": "Towers", "EntityAsset": "Units", "AbilityAsset": "Abilities", "PassiveAsset": "Passives",
	"ReactionAsset": "Reactions", "StatusAsset": "Statuses", "ItemAsset": "Items", "TerrainAsset": "Terrains",
	"TileAsset": "Tiles", "LevelAsset": "Levels", "SequenceAsset": "Sequences", "AbilityPresentationAsset": "Presentations",
	"CodexAsset": "Codex", "GameCatalogAsset": "Catalog", "GameRulesAsset": "Rules",
	"FormAsset": "Forms", "TokenAsset": "Tokens", "MissionAsset": "Missions",
}

## The JSON file name of an asset type ("Units.json"); other types get a file named after the type.
static func file_of(type_name: String) -> String:
	return FILES.get(type_name, type_name) + ".json"

## The asset path a key names: "Units/Enemies/Rabbit" → "Assets/Data/Units/Enemies/Rabbit.asset"; full paths stay ("#sub" dropped).
static func asset_path_of(key: String) -> String:
	var hash_at := key.find("#")
	var path := key.substr(0, hash_at) if hash_at >= 0 else key
	if path.begins_with("Assets/") or path.begins_with("Packages/"): return path
	return DataRoot + "/" + path + ".asset"
