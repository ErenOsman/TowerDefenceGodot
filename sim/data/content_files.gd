class_name ContentFiles
extends RefCounted
## Where content lives: the JSON file of each asset type (res://data/content/<Type>.json, the source of truth; see
## docs/CONTENT.md) and the asset path an entry key names.

## The content JSON folder (C# Folder = "Content", relative to the frozen Unity project).
const Folder := "res://data/content"

## Where content assets live in the Unity project; keys are paths under it without ".asset".
const DataRoot := "Assets/Data"

const FILES := {
	"TowerAsset": "Towers", "EntityAsset": "Units", "AbilityAsset": "Abilities", "PassiveAsset": "Passives",
	"ReactionAsset": "Reactions", "StatusAsset": "Statuses", "ItemAsset": "Items", "TerrainAsset": "Terrains",
	"TileAsset": "Tiles", "LevelAsset": "Levels", "SequenceAsset": "Sequences", "AbilityPresentationAsset": "Presentations",
	"CodexAsset": "Codex", "GameCatalogAsset": "Catalog", "GameRulesAsset": "Rules",
	"FormAsset": "Forms", "TokenAsset": "Tokens", "MissionAsset": "Missions",
}

## The key folder of each asset type (docs/CONTENT.md "Keys"): every key of the type starts with "<folder>/"; folder
## names are singular, file names plural (Status/Burn in Statuses.json). The catalog's key is its own fixed path, the
## rules and the Codex live under Settings/. Only the game content is held to it: the loader takes any key (golden
## plays the frozen Unity snapshot, whose keys are plural).
const KEY_FOLDERS := {
	"StatusAsset": "Status", "ReactionAsset": "Reaction", "AbilityAsset": "Ability", "PassiveAsset": "Passive",
	"EntityAsset": "Unit", "TowerAsset": "Tower", "LevelAsset": "Level", "TerrainAsset": "Terrain", "TileAsset": "Tile",
	"FormAsset": "Form", "TokenAsset": "Token", "MissionAsset": "Mission", "SequenceAsset": "Sequence",
	"AbilityPresentationAsset": "Presentation", "ItemAsset": "Item", "GameRulesAsset": "Settings", "CodexAsset": "Settings",
	"GameCatalogAsset": "Assets/Resources",
}

## Sub-folder names under a key folder that must be singular too (Unit/Enemy/…, Ability/Example/…): plural → singular.
const PLURAL_SUBFOLDERS := {"Towers": "Tower", "Enemies": "Enemy", "Bases": "Base", "Forms": "Form", "Examples": "Example"}

## The JSON file name of an asset type ("Units.json"); other types get a file named after the type.
static func file_of(type_name: String) -> String:
	return FILES.get(type_name, type_name) + ".json"

## The asset path a key names (C# AssetPathOf): "Unit/Enemy/Rabbit" → "Assets/Data/Unit/Enemy/Rabbit.asset"; full paths
## stay ("#sub" dropped). (The frozen Unity project's own keys are plural: "Units/Enemies/Rabbit".)
static func asset_path_of(key: String) -> String:
	var hash_at := key.find("#")
	var path := key.substr(0, hash_at) if hash_at >= 0 else key
	if path.begins_with("Assets/") or path.begins_with("Packages/"): return path
	return DataRoot + "/" + path + ".asset"
