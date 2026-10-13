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

## A tower's name for the player: its custom name, else its type's name.
static func tower_name(owned: OwnedTower, type: TowerAsset) -> String:
	if owned == null: return "Missing tower"
	if owned.custom_name != "": return owned.custom_name
	return type.get_display_name() if type != null else "Unknown tower"

# ------------------------------------------------------------------ chapters (UI_ChapterSelect.cs)

## One card per chapter of a kind (ChapterKind.Main / Side): {chapter, name, open, status, won, total}.
static func chapter_cards(asset: GameCatalogAsset, catalog: LevelCatalog, progress: LevelProgress, kind: int) -> Array:
	var out := []
	if asset == null or catalog == null: return out
	for c in asset.chapters.size():
		var data: ChapterData = asset.chapters[c]
		if data == null or data.kind != kind: continue
		var open := catalog.is_chapter_unlocked(c, progress)
		var total := 0
		var won := 0
		for e in catalog.entries:
			if e.chapter != c: continue
			total += 1
			if progress.is_won(e.level_id): won += 1
		out.append({"chapter": c, "name": chapter_name(asset, c), "open": open, "won": won, "total": total,
			"status": "%d / %d won" % [won, total] if open else chapter_opens_text(catalog, asset, c)})
	return out

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

## The words for an undiscovered entry.
static func locked_text(section: int) -> String:
	match section:
		CodexSection.Towers: return "Not yours yet. Win levels to gain new towers."
		CodexSection.Enemies: return "Not met yet. Meet it in a level to learn about it."
	return "Not seen yet. It is recorded the first time it appears on the board."

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
	return "%d tips" % total if section == CodexSection.Tips else "%d / %d discovered" % [known, total]

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
