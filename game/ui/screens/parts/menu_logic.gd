class_name MenuLogic
extends RefCounted
## The menus' pure rules and texts (no nodes, no autoloads), so they can be tested: the level select list
## (LevelCatalog.visible, per chapter in the Camp), the level's facts / enemies / requirement words, the minimap
## colours from a LevelAsset's layers (LevelMinimap.cs), the Controls page rows (UI_Settings.BuildControls),
## the chapter cards (UI_ChapterSelect.cs) and the Codex texts (UI_Codex.cs).

# ------------------------------------------------------------------ minimap (LevelMinimap.cs + build tiles)

const MAP_GROUND := Color(0.33, 0.45, 0.29)
const MAP_BUILD := Color(0.52, 0.53, 0.52)
const MAP_WALL := Color(0.38, 0.38, 0.42)
const MAP_CHASM := Color(0.07, 0.07, 0.1)
const MAP_ROAD := Color(0.72, 0.62, 0.42)
const MAP_ENTRY := Color(0.86, 0.3, 0.26)
const MAP_BASE := Color(0.32, 0.56, 0.9)

## The colour of every tile, top row first ([row][x], row 0 = the layer's first line = the top of the map):
## walls and chasms from the terrain's standing rule, build tiles grey, the road layer tan, each path's first
## tile (where enemies enter) red, the bases blue. Empty for no level.
static func minimap_colors(level: LevelAsset) -> Array:
	var out := []
	if level == null: return out
	var s := level.size
	if s.x == 0 or s.y == 0: return out
	for row in s.y:
		var line := []
		var y := s.y - 1 - row
		for x in s.x:
			var c := MAP_GROUND
			var stand := level.standing_at(x, y)
			if stand == Standing.Nobody: c = MAP_WALL
			elif stand == Standing.Flyers: c = MAP_CHASM
			elif level.build_at(x, y): c = MAP_BUILD
			var road = level.road_at(x, y)
			if road != null and road != "": c = MAP_ROAD
			line.append(c)
		out.append(line)
	for p in level.paths.size():
		var tiles := level.tiles_of(p)
		for i in range(tiles.size() - 1, -1, -1):
			_paint(out, s, tiles[i], MAP_ENTRY if i == 0 else MAP_ROAD)
	for b in level.bases:
		if b != null: _paint(out, s, b.tile, MAP_BASE)
	return out

static func _paint(out: Array, s: Vector2i, t: Vector2i, c: Color) -> void:
	if t.x < 0 or t.y < 0 or t.x >= s.x or t.y >= s.y: return
	out[s.y - 1 - t.y][t.x] = c

## The minimap as an Image: one block of pixels_per_tile pixels per tile, a darker line between tiles; null for no map.
static func minimap_image(level: LevelAsset, pixels_per_tile := 12) -> Image:
	var colors := minimap_colors(level)
	if colors.is_empty(): return null
	var h := colors.size()
	var w: int = colors[0].size()
	var p := maxi(1, pixels_per_tile)
	var img := Image.create(w * p, h * p, false, Image.FORMAT_RGBA8)
	for py in h * p:
		for px in w * p:
			var c: Color = colors[py / p][px / p]
			if p >= 4 and (px % p == 0 or py % p == 0): c = c.darkened(0.15)
			img.set_pixel(px, py, c)
	return img

# ------------------------------------------------------------------ level list (UI_LevelSelect.cs)

## What level select lists: every unlocked level plus the first locked one (LevelCatalog.visible); with a chapter
## (the Camp), only that chapter's levels: its unlocked ones and its first locked one. Array of {entry, unlocked}.
static func visible_levels(catalog: LevelCatalog, progress: LevelProgress, chapter := -1) -> Array:
	if catalog == null: return []
	if chapter < 0: return catalog.visible(progress)
	var shown := []
	var locked_shown := false
	for e in catalog.entries:
		if e.chapter != chapter: continue
		var open := catalog.is_unlocked(e, progress)
		if open: shown.append({"entry": e, "unlocked": true})
		elif not locked_shown:
			shown.append({"entry": e, "unlocked": false})
			locked_shown = true
	return shown

## A chapter's name ("Chapter 2" when it has none).
static func chapter_name(asset: GameCatalogAsset, chapter: int) -> String:
	var c: ChapterData = asset.chapters[chapter] if asset != null and chapter >= 0 and chapter < asset.chapters.size() else null
	return c.display_name if c != null and c.display_name != "" else "Chapter %d" % (chapter + 1)

## The list's items in order: a heading where the chapter changes, then its levels.
## Array of {"heading": name, "chapter": c} or {"level_id", "unlocked", "chapter"}.
static func list_items(asset: GameCatalogAsset, visible: Array) -> Array:
	var out := []
	var chapter := -1
	for v in visible:
		var e: CatalogEntry = v.entry
		if e.chapter != chapter:
			chapter = e.chapter
			out.append({"heading": chapter_name(asset, chapter), "chapter": chapter})
		out.append({"level_id": e.level_id, "unlocked": v.unlocked, "chapter": e.chapter})
	return out

## The level selected last time if it can still be played, else the first unlocked one not won yet, else the last
## unlocked one ("" when none).
static func pick_start(visible: Array, progress: LevelProgress) -> String:
	var open := []
	for v in visible:
		if v.unlocked: open.append(v.entry.level_id)
	if open.is_empty(): return ""
	if open.has(progress.last_selected): return progress.last_selected
	for id in open:
		if not progress.is_won(id): return id
	return open[open.size() - 1]

## What opens a locked level, in words ("Win Spitters to open it."); "" when nothing is missing.
static func requirement_text(catalog: LevelCatalog, asset: GameCatalogAsset, level_id: String, progress: LevelProgress) -> String:
	var entry := catalog.find(level_id) if catalog != null else null
	if entry == null: return ""
	var req := catalog.requirement(entry)
	var names := []
	for id in req.levels:
		if progress.is_won(id): continue
		var l := asset.find_level(id) if asset != null else null
		names.append(l.get_display_name() if l != null else id)
	if names.is_empty(): return ""
	if names.size() == 1: return "Win %s to open it." % names[0]
	var head := ", ".join(PackedStringArray(names.slice(0, names.size() - 1)))
	return "Win %s %s %s to open it." % [head, "and" if req.all else "or", names[names.size() - 1]]

## The enemies a level sends, in order of first appearance: Array of [EntityAsset, total count].
static func enemy_counts(level: LevelAsset) -> Array:
	var order := []
	var counts := {}
	if level == null: return order
	for wave in level.waves:
		if wave == null: continue
		for s in wave.spawns:
			if s != null: _count(order, counts, s.enemy, 1)
		for e in wave.events:
			if e != null and e.kind == LevelEventKind.SpawnEnemies: _count(order, counts, e.enemy, e.count)
	var out := []
	for e in order: out.append([e, counts[e]])
	return out

static func _count(order: Array, counts: Dictionary, e: EntityAsset, n: int) -> void:
	if e == null or n <= 0: return
	if not counts.has(e):
		counts[e] = 0
		order.append(e)
	counts[e] += n

static func entity_name(e: EntityAsset) -> String:
	return e.display_name if e.display_name != "" else e.name

## "Enemies: Slime ×3, Runner ×2" ("Enemies: none").
static func enemies_text(level: LevelAsset) -> String:
	var parts := PackedStringArray()
	for pair in enemy_counts(level): parts.append("%s ×%d" % [entity_name(pair[0]), pair[1]])
	return "Enemies: none" if parts.is_empty() else "Enemies: " + ", ".join(parts)

## "15 × 9  ·  2 waves  ·  Hand 5  ·  Start energy 550 (+45 a round)".
static func facts_text(level: LevelAsset) -> String:
	if level == null: return ""
	var s := level.size
	var w := level.waves.size()
	return "%d × %d   ·   %d wave%s   ·   Hand %d   ·   Start energy %d (+%d a round)" % [s.x, s.y, w, "" if w == 1 else "s",
		level.hand_cap, level.start_energy, level.energy_per_round]

## The hand strip's note.
static func hand_note(hand_count: int, cap: int) -> String:
	if hand_count == 0: return "Your hand is empty: add towers with Change hand."
	if hand_count > cap: return "This level takes the first %d of your %d towers." % [cap, hand_count]
	return "This level takes up to %d towers." % cap

# ------------------------------------------------------------------ level select (mockup screens-b/level-select.html)

## A chapter heading's right-hand tag: "new" while none of its levels has been played, else "4 levels" (all of the
## chapter's levels in the catalog, shown or not).
static func chapter_tag(catalog: LevelCatalog, progress: LevelProgress, chapter: int) -> String:
	if catalog == null: return ""
	var total := 0
	var played := false
	for e in catalog.entries:
		if e.chapter != chapter: continue
		total += 1
		if has_played(progress, e.level_id): played = true
	if not played: return "new"
	return "1 level" if total == 1 else "%d levels" % total

## A level's place in its chapter, from 1 (0 when it is not in the catalog).
static func level_number(catalog: LevelCatalog, level_id: String) -> int:
	if catalog == null: return 0
	var entry := catalog.find(level_id)
	if entry == null: return 0
	var n := 0
	for e in catalog.entries:
		if e.chapter != entry.chapter: continue
		n += 1
		if e.level_id == level_id: return n
	return 0

## Whether the level has been played at least once: any attempt counts (a loss, a quit through Pause), not only a
## win. The record exists from the first attempt (LevelProgress.record), so no separate flag is saved.
static func has_played(progress: LevelProgress, level_id: String) -> bool:
	if progress == null: return false
	var r := progress.find(level_id)
	return r != null and r.attempts > 0

## The enemies section of the level detail before the level has been played (user decision 2026-10-14, UI Design
## Rules "Level select"): the "Enemies in this level" heading stays, with this one muted body line under it instead
## of the chips; the enemies fact tile shows only the count. After one attempt the chips show.
const EnemiesUnplayedText := "You'll see them when you play it."

## A list row's right-hand state: "won" (a win recorded), "new" (unlocked, never played), "locked", or "" (played,
## not won yet).
static func row_state(progress: LevelProgress, level_id: String, unlocked: bool) -> String:
	if not unlocked: return "locked"
	if progress != null and progress.is_won(level_id): return "won"
	if not has_played(progress, level_id): return "new"
	return ""

## What opens a locked level, short (the row's second line and the detail's kicker): "Win Rock Garden first",
## "Win A and B first", "Win A or B first"; "" when nothing is missing.
static func requirement_line(catalog: LevelCatalog, asset: GameCatalogAsset, level_id: String, progress: LevelProgress) -> String:
	var t := requirement_text(catalog, asset, level_id, progress)
	if t == "": return ""
	return t.trim_suffix(" to open it.") + " first"

## The detail's kicker: "Chapter 1 · level 3".
static func kicker_text(chapter: String, number: int) -> String:
	return "%s · level %d" % [chapter, number] if number > 0 else chapter

## The four fact tiles: {waves, enemies (total count), hand (the cap), energy, per_round}.
static func level_facts(level: LevelAsset) -> Dictionary:
	if level == null: return {"waves": 0, "enemies": 0, "hand": 0, "energy": 0, "per_round": 0}
	var total := 0
	for pair in enemy_counts(level): total += pair[1]
	return {"waves": level.waves.size(), "enemies": total, "hand": level.hand_cap, "energy": level.start_energy,
		"per_round": level.energy_per_round}

## "wave"/"waves" and the like for the fact tiles.
static func plural(n: int, word: String, words := "") -> String:
	return word if n == 1 else (words if words != "" else word + "s")

## The hand strip's note: "Two Roads takes the first 4 towers; the rest wait on the bench." (more towers than the
## cap), "Two Roads takes the first 4 towers." (they all come; the words of hand select), or what to do with an empty hand.
static func hand_strip_note(level_name: String, hand_count: int, cap: int) -> String:
	if hand_count == 0: return "Your hand is empty: add towers with Change hand."
	var who := level_name if level_name != "" else "This level"
	if hand_count > cap: return "%s takes the first %d %s; the rest wait on the bench." % [who, cap, plural(cap, "tower")]
	return "%s takes the first %d %s." % [who, cap, plural(cap, "tower")]

## "5 of 8 slots used".
static func slots_used_text(used: int, slots := TowerCollection.MaxHand) -> String:
	return "%d of %d slots used" % [used, slots]

## The first-win reward card: [title, line]. Won: "First win reward: Priest" / "Already yours: replays give no
## reward."; not won yet: "Win it to earn: Priest" / "A new tower for your collection."; ["", ""] for no reward.
static func reward_lines(reward_name: String, won: bool) -> Array:
	if reward_name == "": return ["", ""]
	if won: return ["First win reward: " + reward_name, "Already yours: replays give no reward."]
	return ["Win it to earn: " + reward_name, "A new tower for your collection."]

## The Shield an enemy arrives with: the stacks its passives' OnSpawned reactions give it of a shield status (a
## plain number), 0 when none (Shield Slime: 10).
static func spawn_shield(entity: EntityAsset) -> int:
	var total := 0
	if entity == null: return 0
	for p in entity.passives:
		if p == null: continue
		for r in p.reactions:
			if r == null or r.trigger != Trigger.OnSpawned or r.response == null: continue
			for step in r.response.items:
				if not (step is ApplyStatusStepData) or step.status == null: continue
				if step.status.get_id().to_lower() != "shield" and step.status.display_name.to_lower() != "shield": continue
				var expr: String = step.stacks.expression.strip_edges() if step.stacks != null else ""
				if expr.is_valid_int(): total += int(expr)
	return total

## A tower's name for the player: its custom name, else its Workshop form's name ("Fire Archer"), else its type's.
static func tower_name(owned: OwnedTower, type: TowerAsset) -> String:
	if owned == null: return "Missing tower"
	if owned.custom_name != "": return owned.custom_name
	var f := form_in(owned, type)
	if f != null: return f.get_display_name()
	return type.get_display_name() if type != null else "Unknown tower"

## An owned tower's current form among its type's forms (TowerAsset.forms), or null (default / unknown form).
static func form_in(owned: OwnedTower, type: TowerAsset) -> FormAsset:
	if owned == null or owned.form == "" or type == null: return null
	for f in type.forms:
		if f != null and f.get_id() == owned.form: return f
	return null

## A form's badge sprite (res://art/ui/KitB/forms/<form id>.png); "" for null or no sprite.
static func form_badge(f: FormAsset) -> String:
	if f == null or f.badge == "": return ""
	var p := ArtPaths.kit(f.badge)
	return p if p != "" and ResourceLoader.exists(p) else ""

## An owned tower's current Workshop form (FormAsset), or null for the default form or a form the content lacks.
static func form_of(owned: OwnedTower, catalog: GameCatalogAsset) -> FormAsset:
	if owned == null or owned.form == "" or catalog == null: return null
	var f := catalog.find_form(owned.form)
	return f if f != null and f.tower != null and f.tower.get_id() == owned.type else null

## An owned tower's form name for hand cards, the Codex and the Workshop: "Fire Archer", else the type's name
## ("Archer"); "" when the type is unknown. The custom name (tower_name) shows beside it.
static func form_name(owned: OwnedTower, catalog: GameCatalogAsset) -> String:
	if owned == null: return ""
	var f := form_of(owned, catalog)
	if f != null: return f.get_display_name()
	var t: TowerAsset = catalog.find_tower(owned.type) if catalog != null else null
	return t.get_display_name() if t != null else ""

## An owned tower's form badge sprite (res://art/ui/KitB/forms/<form id>.png); "" for the default form or no sprite.
static func badge_path(owned: OwnedTower, catalog: GameCatalogAsset) -> String:
	return form_badge(form_of(owned, catalog))

# ------------------------------------------------------------------ chapters (UI_ChapterSelect.cs)

## One card per chapter of a kind (ChapterKind.Main / Side): {chapter, name, open, status, won, total, plus the
## card's details: complete (every level won), active (holds the next main level to play: the one cobalt card),
## progress ("4 / 4 won ✓ Complete", "2 / 4 won"), reason (a locked chapter: "Finish Chapter 1 first" / "Win A2";
## "" when open), levels (per level {level_id, name, state: "won" | "open" | "locked"}), first_level (LevelAsset
## for the thumbnail), reward (the last level's first_clear_reward TowerAsset or null) and reward_name}.
static func chapter_cards(asset: GameCatalogAsset, catalog: LevelCatalog, progress: LevelProgress, kind: int) -> Array:
	var out := []
	if asset == null or catalog == null: return out
	var next := catalog.next_main_level(progress)
	for c in asset.chapters.size():
		var data: ChapterData = asset.chapters[c]
		if data == null or data.kind != kind: continue
		var open := catalog.is_chapter_unlocked(c, progress)
		var total := 0
		var won := 0
		var levels := []
		for e in catalog.entries:
			if e.chapter != c: continue
			total += 1
			var state := "locked"
			if progress.is_won(e.level_id):
				won += 1
				state = "won"
			elif open and catalog.is_unlocked(e, progress): state = "open"
			var l := asset.find_level(e.level_id)
			levels.append({"level_id": e.level_id, "name": l.get_display_name() if l != null else e.level_id, "state": state})
		var first: LevelAsset = null
		var reward: TowerAsset = null
		for d in data.levels:
			if d == null: continue
			if first == null: first = d.level
			reward = d.first_clear_reward
		out.append({"chapter": c, "name": chapter_name(asset, c), "open": open, "won": won, "total": total,
			"status": "%d / %d won" % [won, total] if open else chapter_opens_text(catalog, asset, c),
			"complete": chapter_complete(won, total), "active": open and next != null and next.chapter == c,
			"progress": chapter_progress_text(won, total), "reason": "" if open else chapter_locked_reason(catalog, asset, c),
			"levels": levels, "first_level": first, "reward": reward,
			"reward_name": reward.get_display_name() if reward != null else ""})
	return out

## Every level of the chapter is won (a chapter without levels is never complete).
static func chapter_complete(won: int, total: int) -> bool:
	return total > 0 and won >= total

## A chapter card's progress line: "2 / 4 won", "4 / 4 won ✓ Complete".
static func chapter_progress_text(won: int, total: int) -> String:
	var s := "%d / %d won" % [won, total]
	return s + " ✓ Complete" if chapter_complete(won, total) else s

## Why a chapter is still locked: a main chapter waits for the main chapter before it ("Finish Chapter 1 first");
## a side chapter names its levels ("Win The Slime King", "Win one of A, B"). "" when nothing opens it.
static func chapter_locked_reason(catalog: LevelCatalog, asset: GameCatalogAsset, chapter: int) -> String:
	if catalog == null: return ""
	if catalog.chapter(chapter).kind != ChapterKind.Side:
		for k in range(chapter - 1, -1, -1):
			if catalog.chapter(k).kind == ChapterKind.Main: return "Finish %s first" % chapter_name(asset, k)
	return chapter_opens_text(catalog, asset, chapter)

## What a locked chapter needs: "Win The Slime King", "Win one of A, B".
static func chapter_opens_text(catalog: LevelCatalog, asset: GameCatalogAsset, chapter: int) -> String:
	var req := catalog.chapter_requirement(chapter)
	var names := PackedStringArray()
	for id in req.levels:
		var l := asset.find_level(id)
		names.append(l.get_display_name() if l != null else id)
	if names.is_empty(): return ""
	if names.size() == 1: return "Win %s" % names[0]
	return ("Win " if req.all else "Win one of ") + ", ".join(names)

# ------------------------------------------------------------------ controls (UI_Settings.BuildControls)

## The Controls page's rows: per group (in order of first appearance, key actions first) a header, its modifier
## rows, then its key rows. Array of {"kind": "header", "label"} / {"kind": "modifier"|"key", "id", "label"}.
static func controls_rows(actions: Array, modifier_actions: Array) -> Array:
	var groups := []
	for a in actions:
		if not groups.has(a.group): groups.append(a.group)
	for a in modifier_actions:
		if not groups.has(a.group): groups.append(a.group)
	var out := []
	for g in groups:
		if str(g) != "": out.append({"kind": "header", "label": g})
		for m in modifier_actions:
			if m.group == g: out.append({"kind": "modifier", "id": m.id, "label": m.label})
		for a in actions:
			if a.group == g: out.append({"kind": "key", "id": a.id, "label": a.label})
	return out

## What a modifier choice is called in its dropdown ("No modifier", "Shift", "Ctrl+Shift").
static func modifier_option(m: int) -> String:
	return "No modifier" if m == Modifiers.None else ("Ctrl+Shift" if m == Modifiers.CtrlShift else Modifiers.name_of(m))

## The game speed stages of the Gameplay slider (UI_Settings.GAME_SPEED_STAGES) and the stage nearest a speed.
const GAME_SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]

static func speed_stage(speed: float) -> int:
	var best := 0
	for i in GAME_SPEEDS.size():
		if absf(GAME_SPEEDS[i] - speed) < absf(GAME_SPEEDS[best] - speed): best = i
	return best

# ------------------------------------------------------------------ codex (UI_Codex.cs)

## One section's entries, in the Codex asset's order: {section, id, name, icon (Unity path), asset, tip}.
## Hidden statuses are left out.
static func codex_entries(codex: CodexAsset, section: int) -> Array:
	var out := []
	if codex == null: return out
	match section:
		CodexSection.Towers:
			for t in codex.towers:
				if t == null: continue
				var icon: String = t.icon if t.icon != "" else (t.entity.icon if t.entity != null else "")
				out.append({"section": section, "id": t.get_id(), "name": t.get_display_name(), "icon": icon, "asset": t, "tip": null})
		CodexSection.Enemies:
			for e in codex.enemies:
				if e != null: out.append({"section": section, "id": e.get_id(), "name": entity_name(e), "icon": e.icon, "asset": e, "tip": null})
		CodexSection.Statuses:
			for s in codex.statuses:
				if s == null or s.tags.has(Tags.Hidden): continue
				out.append({"section": section, "id": s.get_id(), "name": s.display_name if s.display_name != "" else s.name,
					"icon": s.icon, "asset": s, "tip": null})
		CodexSection.Tips:
			for tip in codex.tips:
				if tip != null: out.append({"section": section, "id": tip.id, "name": tip.title, "icon": tip.image, "asset": null, "tip": tip})
	return out

## The words for an undiscovered entry: none (the title and the lock say it; no explanations on everyday screens,
## Eren 2026-10-17).
static func locked_text(_section: int) -> String:
	return ""

## A locked Codex entry's name in its list row and on its page: towers are found, enemies (and statuses) met.
static func locked_title(section: int) -> String:
	return "Not found yet" if section == CodexSection.Towers else "Not met yet"

## The Codex list of a section with each entry's lock state: every entry is listed (undiscovered ones locked, their
## name hidden behind locked_title, Eren 2026-10-17: towers too, like enemies). Adds "known" and "shown_name".
static func codex_list(codex: CodexAsset, section: int, progress: CodexProgress) -> Array:
	var out := []
	for e in codex_entries(codex, section):
		var known := progress != null and progress.is_discovered(e.section, e.id)
		e["known"] = known
		e["shown_name"] = e.name if known else locked_title(e.section)
		out.append(e)
	return out

## Discovers every tower type the player owns (the Codex catch-up, the hand editor's collection); the towers you start
## with are not news (no "New" dot), only towers earned later. True when any was new (save then).
static func discover_owned(codex: CodexProgress, towers: TowerCollection, catalog: GameCatalogAsset) -> bool:
	var found := false
	for owned in towers.towers:
		if codex.discover(CodexSection.Towers, owned.type):
			found = true
			if first_earned(catalog, owned.type) == "the tutorial": codex.mark_viewed(CodexSection.Towers, owned.type)
	return found

## How many entries of a codex_list are discovered.
static func codex_known_count(list: Array) -> int:
	var n := 0
	for e in list: if e.get("known", false): n += 1
	return n

static func section_name(section: int) -> String:
	return ["Tower", "Enemy", "Status", "Tip"][clampi(section, 0, 3)]

## "Status · Harmful" / "Status · Helpful" / "Status".
static func status_kind(tags: Array) -> String:
	if tags.has(Tags.Debuff): return "Status · Harmful"
	if tags.has(Tags.Buff): return "Status · Helpful"
	return "Status"

## What applying the status again does.
static func stacking_text(stacking: int, max_stacks: int) -> String:
	match stacking:
		Stacking.Stack: return "adds a stack (up to %d) and starts its time over" % max_stacks if max_stacks > 1 else "starts its time over"
		Stacking.Refresh: return "starts its time over"
		Stacking.Replace: return "replaces it"
		Stacking.Independent: return "adds another one"
		Stacking.PerSource: return "one per unit that gives it"
	return Stacking.name_of(stacking)

## How long a status lasts: "until removed", "1 turn", "3 rounds".
static func lasts_text(duration: int, rounds: bool) -> String:
	if duration < 0: return "until removed"
	var unit := "round" if rounds else "turn"
	return "%d %s%s" % [duration, unit, "" if duration == 1 else "s"]

## A status description with {stacks}, {stacks*N} and {turns} filled in (EntityText.StatusDescription), values in BBCode colour col.
static func status_description(description: String, stacks: int, turns_left: int, col := "") -> String:
	if description == "": return description
	var re := RegEx.create_from_string("(?i)\\{\\s*(stacks|turns)\\s*(?:\\*\\s*(\\d+)\\s*)?\\}")
	var out := ""
	var at := 0
	for m in re.search_all(description):
		out += description.substr(at, m.get_start() - at)
		var is_stacks := m.get_string(1).to_lower() == "stacks"
		var value := stacks if is_stacks else turns_left
		var shown := "–" if (not is_stacks and value < 0) else str(value * (int(m.get_string(2)) if m.get_string(2) != "" else 1))
		out += ("[color=%s]%s[/color]" % [col, shown]) if col != "" else shown
		at = m.get_end()
	return out + description.substr(at)

## The Codex progress line: "5 / 9 discovered" ("7 tips" for Tips).
static func codex_progress_text(section: int, known: int, total: int) -> String:
	match section:
		CodexSection.Tips: return "%d tips" % total
		CodexSection.Towers: return "%d / %d discovered" % [known, total]
		CodexSection.Statuses: return "%d / %d seen" % [known, total]
	return "%d / %d met" % [known, total]

## The main chapter whose last level opens the Workshop (user decision 2026-10-14: "Opens after Chapter 2").
const WORKSHOP_CHAPTER := 2

## The last level of the n-th main chapter (1-based, catalog order), or null.
static func main_chapter_last_level(asset: GameCatalogAsset, n: int) -> LevelAsset:
	if asset == null: return null
	var k := 0
	for c in asset.chapters:
		if c == null or c.kind != ChapterKind.Main: continue
		k += 1
		if k != n: continue
		for i in range(c.levels.size() - 1, -1, -1):
			if c.levels[i] != null and c.levels[i].level != null: return c.levels[i].level
		return null
	return null

## Whether the Workshop is open: the last level of main chapter WORKSHOP_CHAPTER is won (one rule, shared by the
## Camp station and anything else that needs it).
static func workshop_unlocked(asset: GameCatalogAsset, progress: LevelProgress) -> bool:
	var last := main_chapter_last_level(asset, WORKSHOP_CHAPTER)
	return last != null and progress != null and progress.is_won(last.get_id())

## The locked Workshop station's line: "Opens after Chapter 2" (the chapter's name from the catalog).
static func workshop_locked_text(asset: GameCatalogAsset) -> String:
	var k := 0
	if asset != null:
		for i in asset.chapters.size():
			var c = asset.chapters[i]
			if c == null or c.kind != ChapterKind.Main: continue
			k += 1
			if k == WORKSHOP_CHAPTER: return "Opens after " + chapter_name(asset, i)
	return "Opens after Chapter %d" % WORKSHOP_CHAPTER

## How many towers of a type the collection holds.
static func owned_count(towers: TowerCollection, type_id: String) -> int:
	var n := 0
	if towers != null:
		for o in towers.towers:
			if o.type == type_id: n += 1
	return n

## Where a tower type is first earned (the Codex Overview): "the tutorial" (a starting tower or the tutorial's
## reward), else the name of the level whose first win gives it, else "".
static func first_earned(catalog: GameCatalogAsset, type_id: String) -> String:
	if catalog == null: return ""
	if catalog.tutorial_reward != null and catalog.tutorial_reward.get_id() == type_id: return "the tutorial"
	for t in catalog.starting_towers:
		if t != null and t.get_id() == type_id: return "the tutorial"
	for e in catalog.entries():
		var d = e[0]
		if d.first_clear_reward != null and d.first_clear_reward.get_id() == type_id and d.level != null: return d.level.get_display_name()
	return ""

## A model's portrait name: the view's file name ("Assets/Art/Models/Big Slime/Big Slime Blender.prefab" → "Big Slime").
static func portrait_name(view_path: String) -> String:
	var p := ArtPaths.model(view_path)
	return p.get_file().get_basename() if p != "" else ""

## A sprite reference's name ("Assets/Art/Icons/Abilities/Shoot.png#Shoot" → "Shoot").
static func icon_name(unity_path: String) -> String:
	return ArtPaths.strip(unity_path).get_file().get_basename()

## A description with a stat's name replaced by its value where a number belongs ("up to Speed tiles" →
## "up to 2 tiles", "for Power" → "for 10"); values: {stat name: value text}. Other uses of the word stay.
static func fill_stat_words(description: String, values: Dictionary) -> String:
	var out := description
	for stat in values:
		var re := RegEx.create_from_string("\\b(up to|for|within|by|deals|heals) %s\\b" % stat)
		out = re.sub(out, "$1 " + str(values[stat]), true)
		out = RegEx.create_from_string("\\b%s (tiles?|damage|HP)\\b" % stat).sub(out, str(values[stat]) + " $1", true)
	return out

## A result tag's name as shown: a walk's "Move" is its range.
static func result_name(n: String) -> String:
	return "Range" if n == "Move" else n

## How applying a status again reads: no stack limit shown when it is effectively unlimited (99 or more).
static func stacking_shown(stacking: int, max_stacks: int) -> String:
	if stacking == Stacking.Stack and max_stacks >= 99: return "adds a stack and starts its time over"
	return stacking_text(stacking, max_stacks)

## A game speed as shown: "0.5×", "1×", "1.5×", "2×", "0.25×" (up to 2 decimals, trailing zeros dropped).
static func speed_text(speed: float) -> String:
	var t := "%.2f" % speed
	while t.ends_with("0"): t = t.substr(0, t.length() - 1)
	if t.ends_with("."): t = t.substr(0, t.length() - 1)
	return t + "×"
