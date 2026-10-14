class_name LevelCatalog
extends RefCounted
## The levels in play order, grouped into chapters, and the unlock rules (Level Select — Design).
## Engine-free: the Data layer's catalog asset converts into this.
## Port note: the C# tuples (levels, all) are Dictionaries {"levels": Array[String], "all": bool};
## Visible() returns Dictionaries {"entry": CatalogEntry, "unlocked": bool}.

var entries: Array = []  # of CatalogEntry
## Per chapter index; a chapter without one is a main chapter.
var chapters: Array = []  # of ChapterInfo
## Missions & Guild (Godot-first): the board's missions in order (Array of MissionDef), for the Workshop's
## "Found in" (Workshop.found_in). GameCatalogAsset.to_catalog fills it; nothing else here reads it.
var missions: Array = []

func _init(p_entries: Array = [], p_chapters = null) -> void:
	entries.append_array(p_entries)
	if p_chapters != null: chapters.append_array(p_chapters)

func chapter(index: int) -> ChapterInfo:
	if index >= 0 and index < chapters.size() and chapters[index] != null: return chapters[index]
	return ChapterInfo.new()

## What opens a chapter: a main chapter, the last level of the main chapter before it (the first main
## chapter is open); a side chapter, its listed levels.
func chapter_requirement(c: int) -> Dictionary:
	var info := chapter(c)
	if info.kind == ChapterKind.Side: return {"levels": info.requires, "all": info.require_all}
	for k in range(c - 1, -1, -1):
		if chapter(k).kind != ChapterKind.Main: continue
		var last: CatalogEntry = null
		for e in entries:
			if e.chapter == k: last = e
		if last != null: return {"levels": [last.level_id], "all": true}
	return {"levels": [], "all": true}

func is_chapter_unlocked(c: int, progress: LevelProgress) -> bool:
	return _met(chapter_requirement(c), progress)

## The first main-chapter level that is open and not won yet (the main menu's Continue), or null.
func next_main_level(progress: LevelProgress) -> CatalogEntry:
	for e in entries:
		if chapter(e.chapter).kind == ChapterKind.Main and is_unlocked(e, progress) and not progress.is_won(e.level_id): return e
	return null

func find(level_id: String) -> CatalogEntry:
	for e in entries:
		if e.level_id == level_id: return e
	return null

## The levels that must be won to open this one, and whether all or any of them.
func requirement(e: CatalogEntry) -> Dictionary:
	match e.requirement:
		RequirementKind.Open:
			return {"levels": [], "all": true}
		RequirementKind.Levels:
			return {"levels": e.requires, "all": e.require_all}
	# the level before it in its chapter; a chapter's first level opens with the chapter
	var i := entries.find(e)
	if i > 0 and entries[i - 1].chapter == e.chapter: return {"levels": [entries[i - 1].level_id], "all": true}
	return chapter_requirement(e.chapter)

func is_unlocked(e: CatalogEntry, progress: LevelProgress) -> bool:
	return _met(requirement(e), progress)

func _met(req: Dictionary, progress: LevelProgress) -> bool:
	var levels: Array = req.levels
	if levels.is_empty(): return true
	if req.all: return levels.all(func(id): return progress.is_won(id))
	return levels.any(func(id): return progress.is_won(id))

## What level select shows, in catalog order: every unlocked level, plus the first locked one
## (the only locked level the player sees). Everything else stays hidden.
func visible(progress: LevelProgress) -> Array:
	var shown := []
	var locked_shown := false
	for e in entries:
		var open := is_unlocked(e, progress)
		if open: shown.append({"entry": e, "unlocked": true})
		elif not locked_shown:
			shown.append({"entry": e, "unlocked": false})
			locked_shown = true
	return shown

## The first unlocked level after this one in catalog order that is not won yet (the end screen's Next level), or null.
func next_after(level_id: String, progress: LevelProgress) -> CatalogEntry:
	var i := -1
	for k in entries.size():
		if entries[k].level_id == level_id:
			i = k
			break
	if i < 0: return null
	for k in range(i + 1, entries.size()):
		if is_unlocked(entries[k], progress) and not progress.is_won(entries[k].level_id): return entries[k]
	return null

## Catalog mistakes: empty or duplicate ids, requirements naming unknown levels or the level
## itself, an empty Levels requirement, and levels that can never be opened (cycles included).
func problems() -> Array[String]:
	var out: Array[String] = []
	var ids := {}
	for i in entries.size():
		var e: CatalogEntry = entries[i]
		var name: String = "entry %d" % (i + 1) if e.level_id == "" else e.level_id
		if e.level_id == "": out.append("%s: has no level id" % name)
		elif ids.has(e.level_id): out.append("%s: is in the catalog twice" % name)
		else: ids[e.level_id] = true
	for c in chapters.size():
		if chapter(c).kind == ChapterKind.Side:
			for id in chapter(c).requires:
				if not ids.has(id): out.append("side chapter %d: requires unknown level '%s'" % [c + 1, id])
	for e in entries:
		if e.requirement != RequirementKind.Levels: continue
		if e.requires.is_empty(): out.append("%s: requires listed levels but lists none (use Open)" % e.level_id)
		else:
			for id in e.requires:
				if id == e.level_id: out.append("%s: requires itself" % e.level_id)
				elif not ids.has(id): out.append("%s: requires unknown level '%s'" % [e.level_id, id])

	# reachable = can ever be opened by winning reachable levels (a fixpoint from the open ones)
	var reachable := {}
	var grew := true
	while grew:
		grew = false
		for e in entries:
			if e.level_id == "" or reachable.has(e.level_id): continue
			var req := requirement(e)
			var levels: Array = req.levels
			var open: bool = levels.is_empty() or (levels.all(func(id): return reachable.has(id)) if req.all else levels.any(func(id): return reachable.has(id)))
			if open:
				reachable[e.level_id] = true
				grew = true
	for e in entries:
		if e.level_id != "" and not reachable.has(e.level_id):
			out.append("%s: can never be unlocked (its requirement depends on levels that cannot be won first)" % e.level_id)
	var distinct: Array[String] = []
	for p in out:
		if not distinct.has(p): distinct.append(p)
	return distinct
