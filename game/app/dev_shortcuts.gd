class_name DevShortcuts
extends RefCounted
## Hidden shortcuts for trying later content without replaying (DevShortcuts.cs; the Credits' secrets: the E
## of "Eren" completes Chapter 1, the E of "Emre" wins the first 8 levels). They change the save the same way
## playing would, rewards included. Pure rules on a GameData + catalog; GameApp.complete_chapter1() /
## win_first_levels(n) call them on the live save and save it.

## Wins every level of the first main chapter not won yet; returns how many it won.
static func complete_chapter1(data: GameData, catalog: GameCatalogAsset) -> int:
	if catalog == null: return 0
	var levels := []
	for c in catalog.chapters:
		if c != null and c.kind == ChapterKind.Main:
			for e in c.levels:
				if e != null and e.level != null: levels.append(e.level)
			break
	return win(data, catalog, levels)

## Wins the first count levels of the main chapters, in order; returns how many it newly won.
static func win_first_levels(data: GameData, catalog: GameCatalogAsset, count: int) -> int:
	if catalog == null: return 0
	var levels := []
	for c in catalog.chapters:
		if c == null or c.kind != ChapterKind.Main: continue
		for e in c.levels:
			if levels.size() >= count: break
			if e != null and e.level != null: levels.append(e.level)
	return win(data, catalog, levels)

## Wins the levels not won yet (1 round, nothing lost) with their first-clear rewards; finishes the tutorial first.
static func win(data: GameData, catalog: GameCatalogAsset, levels: Array) -> int:
	if data == null or catalog == null: return 0
	if not data.profile.created: data.profile.create(PlayerProfile.DefaultName)
	catalog.grant_starting_towers(data.towers)
	if data.profile.tutorial_pending: NewGame.finish(data, catalog, TutorialState.Done)
	var won := 0
	for level in levels:
		if data.progress.is_won(level.get_id()): continue
		var result := LevelResult.new()
		result.level_id = level.get_id()
		result.won = true
		result.base_hp_pct = 100
		result.rounds = 1
		result.towers_lost = 0
		result.when = Time.get_datetime_string_from_system(true) + "Z"
		var record := data.progress.record(result)
		catalog.grant_first_clear_reward(result, record, data.towers)
		catalog.grant_drops(result, record, data.tokens)
		won += 1
	return won
