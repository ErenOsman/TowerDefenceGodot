class_name NewGame
extends RefCounted
## The first-launch flow's rules (NewGame.cs), on a GameData + catalog so they run without the autoloads:
## creating the profile and starting towers, and finishing the tutorial (done or skipped: the only place
## the tutorial's reward is given, so both end with the same towers). The SaveData autoload wraps these with
## saving and the scene changes (SaveData.begin / skip_tutorial / complete_tutorial).

## Whether a level is the catalog's tutorial.
static func is_tutorial(level: LevelAsset, catalog: GameCatalogAsset) -> bool:
	return level != null and catalog != null and catalog.tutorial == level

## Creates the player's profile and gives the starting towers (Begin's first half).
static func create_profile(data: GameData, catalog: GameCatalogAsset, player_name: String) -> void:
	data.profile.create(player_name)
	if catalog != null: catalog.grant_starting_towers(data.towers)

## Marks the tutorial finished (TutorialState.Done or Skipped) and gives its reward once; the tower given, or null.
static func finish(data: GameData, catalog: GameCatalogAsset, state: int) -> TowerAsset:
	if data == null or not data.profile.tutorial_pending: return null
	data.profile.tutorial = state
	return catalog.grant_tutorial_reward(data.towers) if catalog != null else null
