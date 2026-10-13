class_name GameCatalogAsset
extends ContentAsset
## The game's content list, one per project (Unity: Resources/GameCatalog; here ContentLibrary.catalog): the
## chapters and levels in play order with what opens each (Level Select — Design), the tower types saves can
## refer to, and the towers a new save starts with.

## Where the Unity runtime finds it: Assets/Resources/GameCatalog.asset.
const ResourcePath := "GameCatalog"

## Array of ChapterData.
var chapters: Array = []

## Every tower type a save may own (saves refer to them by type ID): Array of TowerAsset.
var tower_types: Array = []

## Towers a new save starts with, put in the hand in this order: Array of TowerAsset.
var starting_towers: Array = []

# Tutorial
## The first-launch tutorial level. Kept out of the chapters, so level select never lists it.
var tutorial: LevelAsset = null
## The tower finishing (or skipping) the tutorial gives.
var tutorial_reward: TowerAsset = null

# Camp
## The level whose win opens the Camp (the last level of Chapter 1). Null: no Camp yet.
var camp_unlock: LevelAsset = null

# Codex
## What the Codex lists (towers, enemies, statuses, tips).
var codex: CodexAsset = null

## Every level entry in play order, with its chapter index: Array of [CatalogLevelData, chapter index].
func entries() -> Array:
	var result := []
	for c in chapters.size():
		if chapters[c] == null or chapters[c].levels == null: continue
		for l in chapters[c].levels:
			if l != null: result.append([l, c])
	return result

func find_level(level_id: String) -> LevelAsset:
	for e in entries():
		var l: LevelAsset = e[0].level
		if l != null and l.get_id() == level_id: return l
	return null

func find_tower(type_id: String) -> TowerAsset:
	for t in tower_types:
		if t != null and t.get_id() == type_id: return t
	return null

## The engine-free catalog the unlock rules run on.
func to_catalog() -> LevelCatalog:
	var list := []
	for e in entries():
		var data: CatalogLevelData = e[0]
		var entry := CatalogEntry.new()
		entry.level_id = data.level.get_id() if data.level != null else ""
		entry.chapter = e[1]
		entry.requirement = data.requirement
		var req := []
		for r in data.requires: req.append(r.get_id() if r != null else "")
		entry.requires = req
		entry.require_all = data.require_all
		list.append(entry)
	var infos := []
	for c in chapters:
		var info := ChapterInfo.new()
		info.kind = c.kind if c != null else ChapterKind.Main
		var req := []
		if c != null:
			for r in c.requires:
				if r != null: req.append(r.get_id())
		info.requires = req
		info.require_all = c == null or c.require_all
		infos.append(info)
	return LevelCatalog.new(list, infos)

## The Camp is open: its unlock level has been won (Camp & Chapters — Design).
func camp_unlocked(progress: LevelProgress) -> bool:
	return camp_unlock != null and progress != null and progress.is_won(camp_unlock.get_id())

## The next main-chapter level to play (the main menu's Continue), or null when there is none.
func next_main_level(progress: LevelProgress) -> LevelAsset:
	if progress == null: return null
	var e: CatalogEntry = to_catalog().next_main_level(progress)
	return find_level(e.level_id) if e != null else null

## The saved hand as level towers: each owned tower's type looked up in tower_types. Hand
## entries that are not owned or whose type is not listed are skipped and reported.
func build_hand(towers: TowerCollection, convert: AssetConverter, problems = null) -> Array:
	var type_by_id := func(type_id: String) -> TowerType:
		var t := find_tower(type_id)
		return convert.tower_type(t) if t != null else null
	return towers.build_hand(type_by_id, problems)

## The first-clear reward: call right after recording a result (LevelProgress.record returned
## record). On the level's first win (record.wins == 1) it gives the player a new tower of the
## level's first_clear_reward type, into the hand when there is room, and returns that type; otherwise null.
func grant_first_clear_reward(result: LevelResult, record: LevelRecord, towers: TowerCollection) -> TowerAsset:
	if result == null or not result.won or result.quit or record == null or record.wins != 1 or towers == null: return null
	var entry: CatalogLevelData = null
	for e in entries():
		if e[0].level != null and e[0].level.get_id() == result.level_id:
			entry = e[0]
			break
	var reward: TowerAsset = entry.first_clear_reward if entry != null else null
	if reward == null: return null
	_give(towers, reward)
	return reward

## Gives the tutorial's reward tower (into the hand when there is room); the tower type given, or null.
func grant_tutorial_reward(towers: TowerCollection) -> TowerAsset:
	if tutorial_reward == null or towers == null: return null
	_give(towers, tutorial_reward)
	return tutorial_reward

## Gives a collection with no towers the starting towers, in the hand in order. Returns whether it did.
func grant_starting_towers(towers: TowerCollection) -> bool:
	if towers.towers.size() > 0: return false
	for t in starting_towers:
		if t != null: _give(towers, t)
	return towers.towers.size() > 0

func _give(towers: TowerCollection, type: TowerAsset) -> void:
	var owned: OwnedTower = towers.add(type.get_id())
	if towers.can_add_to_hand(owned.id): towers.add_to_hand(owned.id)
