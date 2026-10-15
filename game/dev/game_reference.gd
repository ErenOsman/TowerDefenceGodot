class_name GameReference
extends RefCounted
## Export Game Reference (GameReference.cs, Tools > Docs > Export Game Reference): Markdown pages describing the
## content as the game catalog has it (towers, enemies, abilities, passives, statuses, chapters, levels, maps and
## waves). Same page layout and sections as the Unity tool (the frozen Unity repo's Docs/Reference/*.md); written to
## docs/reference/ by tools/game_reference.gd. Numbers come through the AssetConverter (the same defs the game plays). Output is
## deterministic (no dates). Used by the TD Tools dock (res://addons/td_tools) and tests; pure logic, no nodes.
##   GameReference.pages(lib) → {"README.md": text, "Towers.md": …}; GameReference.export(folder, lib) → problem or "".

const Folder := "res://docs/reference"
const Header := "<!-- Generated from data/content by tools/game_reference.gd (or the TD Tools dock's Reference tab). Do not edit by hand: change the content and generate again. -->"
## The content folder, as the Source lines show it (data/content/Units.json).
const ContentFolder := "data/content"

## The pages (file name → Markdown) of a loaded content library.
static func pages(lib: ContentLibrary) -> Dictionary:
	var r := _Reference.new(lib.catalog, lib)
	return {
		"README.md": r.index(),
		"Towers.md": r.towers_page(),
		"Enemies.md": r.enemies_page(),
		"Statuses.md": r.statuses_page(),
		"Levels.md": r.levels_page(),
		"Codex.md": r.codex_page(),
	}

## Writes the pages into folder (res://, user:// or absolute); returns a problem, or "" when written.
static func export(folder: String, lib: ContentLibrary) -> String:
	if lib == null or lib.catalog == null: return "no game catalog"
	var abs_folder := ProjectSettings.globalize_path(folder)
	var err := DirAccess.make_dir_recursive_absolute(abs_folder)
	if err != OK and not DirAccess.dir_exists_absolute(abs_folder): return "cannot create %s: %s" % [folder, error_string(err)]
	var all := pages(lib)
	for file in all:
		var f := FileAccess.open(abs_folder.path_join(file), FileAccess.WRITE)
		if f == null: return "cannot write %s: %s" % [file, error_string(FileAccess.get_open_error())]
		f.store_string(String(all[file]).replace("\r\n", "\n"))
		f.close()
	return ""

# ------------------------------------------------------------------ the pages

class _Reference:
	var catalog: GameCatalogAsset
	var lib: ContentLibrary
	var convert := AssetConverter.new()
	var vocab: Vocabulary = CombatVocabulary.create()
	var levels: Array = []   # [level, data, chapter]
	var towers: Array = []
	var enemies: Array = []
	var md := PackedStringArray()

	func _init(p_catalog: GameCatalogAsset, p_lib: ContentLibrary) -> void:
		catalog = p_catalog
		lib = p_lib
		for c in catalog.chapters:
			if c == null: continue
			for d in c.levels:
				if d != null and d.level != null: levels.append([d.level, d, c])
		# towers: the catalog's types, then any level reward not listed there
		for t in catalog.tower_types:
			if t != null and not towers.has(t): towers.append(t)
		for l in levels:
			var t = l[1].first_clear_reward
			if t != null and not towers.has(t): towers.append(t)
		# enemies: in order of first appearance across the catalog's levels
		for l in levels:
			for wave in l[0].waves:
				if wave == null: continue
				for s in wave.spawns:
					if s != null: _add(enemies, s.enemy)
				for e in wave.events:
					if e != null and e.kind == LevelEventKind.SpawnEnemies: _add(enemies, e.enemy)

	# -------------------------------------------------------------- README

	func index() -> String:
		_page("Game reference")
		_line("What the game contains, exported from the assets the game plays. For how the rules work, see the design docs in `docs/design/`.")
		_line()
		_line("| Page | Contents |")
		_line("|---|---|")
		_line("| [Towers](Towers.md) | %s: cost, stats, abilities, passives |" % _count(towers.size(), "tower type"))
		_line("| [Enemies](Enemies.md) | %s: stats, abilities, passives, where they appear |" % _count(enemies.size(), "enemy", "enemies"))
		_line("| [Statuses](Statuses.md) | Statuses the towers and enemies can apply or carry |")
		_line("| [Levels](Levels.md) | %s, %s: maps, energy, waves, rewards |" % [_count(catalog.chapters.size(), "chapter"), _count(levels.size(), "level")])
		_line("| [Codex](Codex.md) | What the in-game Codex lists, in order, and the full text of its tips |")
		_line()
		_line("Reading the numbers: HP is the most a unit has. Speed is tiles per move. Range is in tiles from the user. A cooldown is in its owner's turns (1 = usable every turn). Enemy cooldowns count down at the start of the player's turn.")
		return _done()

	# -------------------------------------------------------------- codex

	func codex_page() -> String:
		_page("Codex")
		var codex: CodexAsset = catalog.codex
		if codex == null:
			_line("The game catalog has no Codex yet: add the Codex entry `Settings/Codex` to `data/content/Codex.json` (by hand or in the wiki Content Editor) and set the catalog's `codex`.")
			return _done()
		_line("What the in-game Codex lists, in its order (`Settings/Codex` in `data/content/Codex.json`; add new content to its lists there, by hand or in the wiki Content Editor). Players see an entry once they have discovered it: towers when owned, enemies and statuses when met in a level; tips always. See [Codex — Design](../design/Codex%20—%20Design.md).")
		var names := []
		for t in codex.towers:
			if t != null: names.append("%s (%d energy)" % [t.get_display_name(), t.cost])
		_section("Towers", names)
		names = []
		for e in codex.enemies:
			if e != null: names.append(GameReference.name_of(e) + (" (boss)" if e.tags.has(Tags.Boss) else ""))
		_section("Enemies", names)
		names = []
		for s in codex.statuses:
			if s != null: names.append(s.name if s.display_name == "" else s.display_name)
		_section("Statuses", names)
		var tips := codex.tips.filter(func(t): return t != null)
		_line()
		_line("## Tips (%d)" % tips.size())
		_line()
		_line("*Key* and *click* in italics are filled in by the game with the player's own bindings (Settings > Controls), e.g. *End round key* shows as Enter by default.")
		for tip in tips:
			_line()
			_line("### " + tip.title)
			_line()
			_line(GameReference.tip_text(tip.text))
		return _done()

	func _section(title: String, names: Array) -> void:
		_line()
		_line("## %s (%d)" % [title, names.size()])
		_line()
		for i in names.size(): _line("%d. %s" % [i + 1, names[i]])

	# -------------------------------------------------------------- towers

	func towers_page() -> String:
		_page("Towers")
		_line("Towers are placed from the hand for energy, only on build tiles when a level has any. Each acts freely in the player phase.")
		_line()
		var units := towers.map(func(t): return t.entity)
		var columns := stat_columns(units)
		_line("| Tower | Cost | " + " | ".join(columns) + " | First clear of |")
		_line("|---|---|" + "".join(columns.map(func(_c): return "---|")) + "---|")
		for t in towers:
			var rewards := PackedStringArray()
			for l in levels:
				if l[1].first_clear_reward == t: rewards.append(l[0].get_display_name())
			var reward := ", ".join(rewards)
			var cells := PackedStringArray()
			for s in columns: cells.append(stat_text(t.entity, s))
			var last := GameReference.cell(reward) if reward.length() > 0 else ("starting tower" if catalog.starting_towers.has(t) else "—")
			_line("| [%s](#%s) | %d | %s | %s |" % [GameReference.cell(t.get_display_name()), GameReference.anchor(t.get_display_name()), t.cost, " | ".join(cells), last])
		for t in towers:
			_line()
			_line("## " + t.get_display_name())
			_line()
			var description: String = t.description if t.description != "" else (t.entity.description if t.entity != null else "")
			if description != "":
				_line(description)
				_line()
			_line("Cost **%d** energy · type ID `%s`" % [t.cost, t.get_id()])
			_line()
			_line(_source([t, t.entity]))
			_unit(t.entity)
		return _done()

	# -------------------------------------------------------------- enemies

	func enemies_page() -> String:
		_page("Enemies")
		_line("Enemies walk their road toward the base and act one at a time in the enemy phase, trying their abilities in order and using each one they can. Where an ability can aim at several targets, its instinct picks (see the Instinct design doc).")
		_line()
		var columns := stat_columns(enemies)
		_line("| Enemy | " + " | ".join(columns) + " | Tags | First appears in |")
		_line("|---|" + "".join(columns.map(func(_c): return "---|")) + "---|---|")
		for e in enemies:
			var cells := PackedStringArray()
			for s in columns: cells.append(stat_text(e, s))
			_line("| [%s](#%s) | %s | %s | %s |" % [GameReference.cell(e.display_name), GameReference.anchor(GameReference.name_of(e)), " | ".join(cells), _tags(e.tags), GameReference.cell(_first_level(e))])
		for e in enemies:
			_line()
			_line("## " + GameReference.name_of(e))
			_line()
			if e.description != "":
				_line(e.description)
				_line()
			var appears := PackedStringArray()
			for l in levels:
				if _spawns(l[0]).has(e): appears.append(l[0].get_display_name())
			_line("Appears in: " + ", ".join(appears))
			_line()
			_line(_source([e]))
			_unit(e)
		return _done()

	# -------------------------------------------------------------- statuses

	func statuses_page() -> String:
		_page("Statuses")
		_line("Statuses sit on a unit for a while: buffs, debuffs, shields and marks. Turns count the carrier's own turns; rounds count whole rounds.")
		var found := used_statuses()
		if found.is_empty():
			_line()
			_line("No statuses are used by the catalog's towers and enemies.")
			return _done()
		for asset in found:
			var s: StatusDef = convert.status(asset)
			_line()
			_line("## " + s.display_name)
			_line()
			if s.description != "":
				_line(GameReference.status_text(s.description))
				_line()
			var facts := PackedStringArray()
			if s.duration < 0: facts.append("lasts until removed")
			else: facts.append("lasts %d %s%s" % [s.duration, "round" if s.duration_unit == DurationUnit.Rounds else "turn", "" if s.duration == 1 else "s"])
			facts.append("stacking: " + Stacking.name_of(s.stacking) + (" (up to %d)" % s.max_stacks if s.stacking == Stacking.Stack else ""))
			if not s.shield_pool.is_empty: facts.append("shield: " + s.shield_pool.expression)
			if s.tags != null and s.tags.size() > 0: facts.append("tags: " + ", ".join(PackedStringArray(s.tags)))
			_line(" · ".join(facts))
			_line()
			_line("ID `%s`" % s.name)
			_line()
			_line(_source([asset]))
		return _done()

	# -------------------------------------------------------------- levels

	func levels_page() -> String:
		_page("Levels")
		_line("Map legend: `.` ground, `+` build tile, `#` wall, `~` chasm, `B` base, `1` `2`… the roads (by number), `S` where a road starts. Rows are numbered on the left (0 is the bottom row), columns underneath.")
		if catalog.tutorial != null:
			_line()
			_line("## Tutorial")
			_level(catalog.tutorial, "", "the first launch (not listed in level select)",
				catalog.tutorial_reward.get_display_name() + " (skipping the tutorial gives it too)" if catalog.tutorial_reward != null else "nothing")
		for chapter in catalog.chapters:
			if chapter == null: continue
			_line()
			_line("## " + (chapter.id if chapter.display_name == "" else chapter.display_name))
			var number := 0
			for data in chapter.levels:
				if data == null or data.level == null: continue
				number += 1
				_level(data.level, "%d. " % number, _requirement(data),
					data.first_clear_reward.get_display_name() if data.first_clear_reward != null else "nothing")
		return _done()

	## One level: description, energy, hand, unlock, reward, intro, map and waves.
	func _level(l: LevelAsset, number_prefix: String, unlocks: String, reward: String) -> void:
		_line()
		_line("### %s%s" % [number_prefix, l.get_display_name()])
		_line()
		if l.description != "":
			_line(l.description)
			_line()
		_line(_source([l]))
		_line()
		var size: Vector2i = l.size
		_line("- Energy: **%d** at the start, **%s%d** each round" % [l.start_energy, "+" if l.energy_per_round >= 0 else "", l.energy_per_round])
		var fixed := PackedStringArray()
		for t in l.fixed_hand:
			if t != null: fixed.append(t.get_display_name())
		var hand := ("its own: " + ", ".join(fixed)) if fixed.size() > 0 else "up to **%d** towers" % l.hand_cap
		_line("- Hand: %s · map %d×%d · %s · %s" % [hand, size.x, size.y, _count(l.paths.size(), "road"), _count(l.waves.size(), "wave")])
		_line("- Unlocks: " + unlocks)
		_line("- First clear gives: " + reward)
		var starting := PackedStringArray()
		for u in l.starting_units:
			if u != null and u.entity != null:
				starting.append("%s (%s) at (%d, %d)" % [GameReference.name_of(u.entity), StartingSide.name_of(u.side).to_lower(), u.tile.x, u.tile.y])
		if starting.size() > 0: _line("- Starting units: " + ", ".join(starting))
		if l.intro != null and l.intro.lines.size() > 0: _line("- Intro: %s (`%s`), the first time it is played" % [_count(l.intro.lines.size(), "line"), l.intro.name])
		_line("- ID `%s`" % l.get_id())
		_line()
		_line("```text")
		for row in GameReference.map_rows(l): _line(row)
		_line("```")
		for i in l.waves.size():
			var wave: WaveData = l.waves[i]
			if wave == null: continue
			_line()
			var start := ("after wave %d is cleared" % (wave.after_wave + 1)) if wave.start == WaveStart.AfterWave else "round %d" % wave.start_round
			_line("**Wave %d: %s** (starts %s)" % [i + 1, "unnamed" if wave.name == "" else wave.name, start])
			_line()
			var rows := []
			for sp in wave.spawns:
				if sp != null and sp.enemy != null: rows.append([sp.round, GameReference.name_of(sp.enemy), str(sp.path + 1), rows.size()])
			for e in wave.events:
				if e == null: continue
				var road := ""
				if e.kind == LevelEventKind.SpawnEnemies: road = "random" if e.path < 0 else str(e.path + 1)
				rows.append([e.round, GameReference.event_text(e), road, rows.size()])
			rows.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[3] < b[3])) # OrderBy: stable
			_line("| Wave round | What comes | Road |")
			_line("|---|---|---|")
			for x in rows: _line("| %d | %s | %s |" % [x[0], GameReference.cell(x[1]), x[2]])

	# -------------------------------------------------------------- shared pieces

	## Stats, abilities and passives of one unit, as sub-sections.
	func _unit(asset: EntityAsset) -> void:
		if asset == null:
			_line()
			_line("_No entity assigned._")
			return
		var def: EntityDef = convert.entity(asset)
		var me := DefStats.new(def)
		_line()
		var stats := PackedStringArray()
		for k in def.base_stats:
			if k != "Initiative" or float(def.base_stats[k]) != 0.0: stats.append("%s %s" % [GameReference.stat_label(k), Num.to_str(def.base_stats[k])])
		_line("Stats: " + " · ".join(stats) + (" · tags: " + ", ".join(PackedStringArray(def.tags)) if def.tags != null and def.tags.size() > 0 else ""))
		if def.abilities.size() > 0:
			_line()
			_line("Abilities, in the order " + ("it tries them:" if asset.footing == Footing.OnPath else "they show:"))
			_line()
			var i := 0
			for a in def.abilities:
				i += 1
				var tags := (" _(%s)_" % ", ".join(PackedStringArray(a.tags))) if a.tags != null and a.tags.size() > 0 else ""
				_line("%d. **%s**%s: %s" % [i, a.display_name, tags, "no description" if a.description == "" else a.description])
				_line("   " + AbilityText.summary(a, me, vocab) + ("" if a.instinct.is_default else " · instinct: " + GameReference.instinct_text(a.instinct)))
		if def.passives.size() > 0:
			_line()
			_line("Passives:")
			_line()
			for p in def.passives:
				_line("- **%s**%s: %s" % [p.display_name, " _(hidden from players)_" if p.hidden else "", "no description" if p.description == "" else p.description])

	func _requirement(data: CatalogLevelData) -> String:
		match data.requirement:
			RequirementKind.Open: return "open from the start"
			RequirementKind.Levels:
				var names := PackedStringArray()
				for x in data.requires:
					if x != null: names.append(x.get_display_name())
				if names.is_empty(): return "open from the start"
				return ("win all of " if data.require_all else "win any of ") + ", ".join(names)
			_:
				var index := -1
				for i in levels.size():
					if levels[i][1] == data:
						index = i
						break
				return "open from the start" if index <= 0 else "win " + levels[index - 1][0].get_display_name()

	## Statuses the catalog's towers and enemies reference (through their abilities and passives), by name.
	func used_statuses() -> Array:
		var roots := []
		for t in towers:
			if t.entity != null: roots.append(t.entity)
		roots.append_array(enemies)
		var found := []
		for o in GameReference.reachable(roots):
			if o is StatusAsset and not found.has(o): found.append(o)
		var keyed := []
		for i in found.size(): keyed.append([convert.status(found[i]).display_name, i, found[i]])
		keyed.sort_custom(func(a, b):
			var c := GameReference.culture_cmp(a[0], b[0])
			return c < 0 or (c == 0 and a[1] < b[1]))
		return keyed.map(func(k): return k[2])

	func _spawns(l: LevelAsset) -> Array:
		var out := []
		for w in l.waves:
			if w == null: continue
			for s in w.spawns:
				if s != null and s.enemy != null: out.append(s.enemy)
			for e in w.events:
				if e != null and e.kind == LevelEventKind.SpawnEnemies and e.enemy != null: out.append(e.enemy)
		return out

	func _first_level(e: EntityAsset) -> String:
		for l in levels:
			if _spawns(l[0]).has(e): return l[0].get_display_name()
		return "—"

	## The stats worth a column: every stat any of the units has, MaxHp and Speed first, Initiative only when someone's is not 0.
	func stat_columns(units: Array) -> Array:
		var defs := []
		for u in units:
			if u != null: defs.append(convert.entity(u))
		var names := []
		for d in defs:
			for k in d.base_stats:
				if not names.has(k): names.append(k)
		names = names.filter(func(s):
			if s != "Initiative": return true
			for d in defs:
				if d.base_stats.has(s) and float(d.base_stats[s]) != 0.0: return true
			return false)
		var rank := func(s): return 0 if s == "MaxHp" else (1 if s == "Speed" else 2)
		names.sort_custom(func(a, b):
			if rank.call(a) != rank.call(b): return rank.call(a) < rank.call(b)
			return GameReference.culture_cmp(a, b) < 0)
		return names.map(func(s): return GameReference.stat_label(s))

	func stat_text(unit: EntityAsset, label: String) -> String:
		if unit == null: return "—"
		var def: EntityDef = convert.entity(unit)
		var st := "MaxHp" if label == "HP" else label
		return Num.to_str(def.base_stats[st]) if def.base_stats.has(st) else "—"

	## Where the assets live: "Source: `data/content/Units.json` → `Unit/…`".
	func _source(assets: Array) -> String:
		var parts := PackedStringArray()
		for a in assets:
			if a == null: continue
			var key = lib.key_of(a) if lib != null else null
			parts.append("`%s/%s` → `%s`" % [GameReference.ContentFolder, ContentFiles.file_of(ContentSerializer.type_of(a)),
				key if key != null else a.name])
		return "<sub>Source: " + " · ".join(parts) + "</sub>"

	func _tags(tags) -> String:
		return ", ".join(PackedStringArray(tags)) if tags != null and tags.size() > 0 else "—"

	func _count(n: int, one: String, many := "") -> String:
		return "%d %s" % [n, one if n == 1 else (many if many != "" else one + "s")]

	static func _add(list: Array, e) -> void:
		if e != null and not list.has(e): list.append(e)

	func _page(title: String) -> void:
		md = PackedStringArray()
		_line(GameReference.Header)
		_line()
		_line("# " + title)
		_line()

	func _line(text := "") -> void:
		md.append(text)

	func _done() -> String:
		return "\n".join(md) + "\n"

# ------------------------------------------------------------------ helpers (static, tested)

## An entity's player-facing name: its display name, or the asset name when it has none.
static func name_of(e) -> String:
	return e.name if e.display_name == "" else e.display_name

## "MaxHp" → "HP".
static func stat_label(stat: String) -> String:
	return "HP" if stat == "MaxHp" else stat

## Text safe inside a Markdown table cell.
static func cell(text) -> String:
	return ("" if text == null else str(text)).replace("|", "\\|").replace("\n", " ")

## The GitHub-style heading anchor of a title ("The Slime King" → "the-slime-king").
static func anchor(title: String) -> String:
	var out := ""
	for c in title.to_lower():
		if c == " " or c == "-" or (c >= "0" and c <= "9") or c.to_upper() != c.to_lower(): out += c
	return out.replace(" ", "-")

## C#'s default (culture) string order, close enough for content names: case-insensitive first, then ordinal.
static func culture_cmp(a: String, b: String) -> int:
	var c := a.nocasecmp_to(b)
	return c if c != 0 else a.casecmp_to(b)

## "EndRound" → "End round".
static func words(id: String) -> String:
	var spaced := ""
	for i in id.length():
		var c := id[i]
		if i > 0 and c >= "A" and c <= "Z" and id[i - 1] >= "a" and id[i - 1] <= "z": spaced += " "
		spaced += c
	spaced = spaced.to_lower()
	return spaced.substr(0, 1).to_upper() + spaced.substr(1) if spaced.length() > 0 else spaced

static func _replace(text: String, pattern: String, fn: Callable) -> String:
	var re := RegEx.create_from_string(pattern)
	var out := ""
	var at := 0
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at) + str(fn.call(m))
		at = m.get_end()
	return out + text.substr(at)

## A tip's text with {key:Id} and {click:Id} shown as their action, since the keys are the player's.
static func tip_text(text: String) -> String:
	if text == "": return ""
	text = _replace(text, "\\{key:(\\w+)\\}", func(m): return "*%s key*" % words(m.get_string(1)))
	return _replace(text, "\\{click:(\\w+)\\}", func(m): return "*%s click*" % words(m.get_string(1)))

## A status description with its placeholders named: {stacks} → *stacks*, {stacks*5} → *5 × stacks*, {turns} → *turns left*.
static func status_text(text: String) -> String:
	return _replace(text, "(?i)\\{\\s*(stacks|turns)\\s*(?:\\*\\s*(\\d+)\\s*)?\\}", func(m):
		if m.get_string(1).to_lower() == "turns": return "*turns left*"
		return "*%s × stacks*" % m.get_string(2) if m.get_string(2) != "" else "*stacks*")

static func event_text(e: LevelEventData) -> String:
	match e.kind:
		LevelEventKind.SpawnEnemies: return "%d× %s" % [e.count, name_of(e.enemy) if e.enemy != null else "?"]
		LevelEventKind.GiveEnergy: return "+%d energy" % e.energy
		_: return "message: \"%s\"" % e.message

## An instinct in words: its preset, or a custom one's preferences, plus any Must.
static func instinct_text(i: InstinctDef) -> String:
	var parts := PackedStringArray()
	if i.preset == InstinctPreset.Custom:
		var prefer := PackedStringArray()
		for p in i.prefer:
			if p != null: prefer.append(preference_text(p))
		if prefer.size() > 0: parts.append("prefers " + ", then ".join(prefer))
	elif i.preset != InstinctPreset.Default: parts.append(preset_text(i.preset))
	if not i.must.is_empty: parts.append("only where `%s`" % i.must.expression)
	return "; ".join(parts)

static func preference_text(p: Preference) -> String:
	var dir := "highest" if p.highest else "lowest"
	var filter := "" if p.filter.is_empty else " (counting `%s`)" % p.filter.expression
	match p.over:
		PreferOver.AreaCount: return ("most" if p.highest else "fewest") + " units in the area" + filter
		PreferOver.AreaSum: return "%s total `%s` over the area%s" % [dir, p.value.expression, filter]
		_: return "%s `%s`" % [dir, p.value.expression]

static func preset_text(preset: int) -> String:
	match preset:
		InstinctPreset.MostHurt: return "most hurt"
		InstinctPreset.MostHit: return "most hit"
		InstinctPreset.FarthestStep: return "farthest step"
		InstinctPreset.FirstValid: return "first valid aim"
		InstinctPreset.Engage: return "engage (walks to where its attack can reach its target)"
		InstinctPreset.Ahead: return "ahead (the unit furthest along its path)"
		_: return InstinctPreset.name_of(preset).to_lower()

## The map as text, top row first, with roads, starts and bases drawn over it.
static func map_rows(l: LevelAsset) -> Array:
	var size: Vector2i = l.size
	var w := size.x
	var h := size.y
	var grid := []
	for y in h:
		var row := []
		for x in w:
			var stand: int = l.standing_at(x, y)
			row.append(LevelAsset.Wall if stand == Standing.Nobody else (LevelAsset.Chasm if stand == Standing.Flyers
				else (LevelAsset.Buildable if l.build_at(x, y) else LevelAsset.Ground)))
		grid.append(row)
	for p in l.paths.size():
		var tiles: Array = l.tiles_of(p)
		for i in range(tiles.size() - 1, -1, -1):
			var t: Vector2i = tiles[i]
			if t.x >= 0 and t.y >= 0 and t.x < w and t.y < h: grid[t.y][t.x] = "S" if i == 0 else String.chr(49 + p % 9)
	for b in l.bases:
		if b != null and b.tile.x >= 0 and b.tile.y >= 0 and b.tile.x < w and b.tile.y < h: grid[b.tile.y][b.tile.x] = "B"
	var rows := []
	for y in range(h - 1, -1, -1):
		rows.append("%2d " % y + " ".join(PackedStringArray(grid[y])))
	if w > 10:
		var tens := PackedStringArray()
		for x in w: tens.append(str(x / 10 % 10) if x >= 10 else " ")
		rows.append(("   " + " ".join(tens)).rstrip(" "))
	var ones := PackedStringArray()
	for x in w: ones.append(str(x % 10))
	rows.append("   " + " ".join(ones))
	return rows

## Every content object reachable from the roots through their serialized references (the roots included), in
## the order found.
static func reachable(roots: Array) -> Array:
	var seen := {}
	var order := []
	var queue := roots.duplicate()
	var recorder := _RefRecorder.new()
	while not queue.is_empty():
		var o = queue.pop_front()
		if o == null or seen.has(o): continue
		seen[o] = true
		order.append(o)
		recorder.found.clear()
		ContentSerializer.to_json(o, recorder)
		for nxt in recorder.found:
			if not seen.has(nxt): queue.append(nxt)
	return order

## Collects the assets a serialization pass refers to.
class _RefRecorder:
	var found := []
	func key_of(o):
		if o is ContentAsset: found.append(o)
		return o.name if o is Object else o
