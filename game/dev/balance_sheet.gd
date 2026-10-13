class_name BalanceSheet
extends RefCounted
## Balance Sheet (BalanceSheet.cs + Balance.cs, Tools > Combat > Balance Sheet) as read-only rows: every unit's
## stats (towers with their cost; grouped Towers / Enemies / Bases / Other), every ability's cooldown / start /
## range / min range / damage / heal as written plus its numbers evaluated for its first owner (AbilityText with
## DefStats), and every status's duration / max stacks / stacking / shield. In Godot the numbers are the Unity
## repo's (data/content is a copy): change them there (Balance.txt or the Unity Balance Sheet) and sync.
## Pure logic on a ContentLibrary; the TD Tools dock shows it and writes the CSV (user://balance.csv).

## The usual stats, first (Balance.Stats).
const STATS := ["MaxHp", "Speed", "Power", "Potency", "Range", "Radius", "Duration", "Initiative"]
const ABILITY_FIELDS := ["cooldown", "start", "range", "minRange", "damage", "heal"]
const STATUS_FIELDS := ["duration", "maxStacks", "stacking", "shield"]
const GROUPS := ["Towers", "Enemies", "Bases", "Other"]
const CSV_PATH := "user://balance.csv"

## The label of an asset in the sheet: "Display (asset)" when they differ (BalanceSheet.NameButton).
static func label_of(asset) -> String:
	var dn: String = asset.display_name
	return asset.name if dn == "" or dn == asset.name else "%s (%s)" % [dn, asset.name]

static func _listed(lib: ContentLibrary, type_name: String, examples: bool) -> Array:
	var out := []
	for a in lib.all_of(type_name):
		var key = lib.key_of(a)
		if not examples and key is String and key.contains("/Examples/"): continue
		out.append(a)
	return out

## Every stat any listed unit has, the usual ones first.
static func unit_columns(lib: ContentLibrary, examples := false) -> Array:
	var cols := STATS.duplicate()
	for e in _listed(lib, "EntityAsset", examples):
		for s in e.stats:
			if s != null and s.stat != "" and not cols.has(s.stat): cols.append(s.stat)
	return cols

## A unit's stat as written ("" when it does not have it).
static func stat_of(e: EntityAsset, stat: String) -> String:
	for s in e.stats:
		if s != null and s.stat == stat: return s.value
	return ""

## The units: {group, name, label, key, file, cost ("" for non-towers), stats: {stat: value or ""}}, by group.
static func unit_rows(lib: ContentLibrary, examples := false) -> Array:
	var towers := lib.all_of("TowerAsset")
	var tower_of := {}
	for t in towers:
		if t.entity != null and not tower_of.has(t.entity): tower_of[t.entity] = t
	var cols := unit_columns(lib, examples)
	var by_group := {}
	for g in GROUPS: by_group[g] = []
	for e in _listed(lib, "EntityAsset", examples):
		var group := "Other"
		if tower_of.has(e): group = "Towers"
		elif e.footing == Footing.OnPath: group = "Enemies"
		elif e.tags.has(Tags.Base): group = "Bases"
		var stats := {}
		for c in cols: stats[c] = stat_of(e, c)
		by_group[group].append({"group": group, "name": e.name, "label": label_of(e), "key": str(lib.key_of(e)),
			"file": lib.file_of(e), "cost": str(tower_of[e].cost) if tower_of.has(e) else "", "stats": stats, "asset": e})
	var out := []
	for g in GROUPS: out.append_array(by_group[g])
	return out

## An ability's field as written (Balance.AbilityField); "" when it has none.
static func ability_field(a: AbilityAsset, field: String) -> String:
	match field:
		"cooldown": return "reset" if a.cooldown_until_reset else str(a.cooldown)
		"start": return str(a.start_cooldown)
		"range": return a.targeting.max_radius.expression if a.targeting != null else ""
		"minRange": return a.targeting.min_radius.expression if a.targeting != null else ""
		"damage":
			for s in a.steps.items:
				if s is AttackStepData: return s.power.expression
			return ""
		"heal":
			for s in a.steps.items:
				if s is HealStepData: return s.amount.expression
			return ""
	return ""

## The abilities: {name, label, key, file, fields: {field: text}, owner (first unit that has it, or ""),
## numbers ("10 Damage · 2 Range" for that owner, via AbilityText.tags), summary (AbilityText.summary)}.
static func ability_rows(lib: ContentLibrary, examples := false) -> Array:
	var convert := AssetConverter.new()
	var vocab: Vocabulary = ContentCheck.vocabulary_of(lib.rules)
	var owner_of := {}
	for e in lib.all_of("EntityAsset"):
		for a in e.abilities:
			if a != null and not owner_of.has(a): owner_of[a] = e
	var out := []
	for a in _listed(lib, "AbilityAsset", examples):
		var fields := {}
		for f in ABILITY_FIELDS: fields[f] = ability_field(a, f)
		var owner: EntityAsset = owner_of.get(a)
		var def := convert.ability(a)
		var me: IEntity = null
		if owner != null:
			var ed := convert.entity(owner)
			if ed != null: me = DefStats.new(ed)
		var numbers := ""
		var summary := ""
		if def != null:
			var parts := PackedStringArray()
			for pair in AbilityText.tags(def, me, vocab): parts.append("%s %s" % [pair[0], pair[1]])
			numbers = " · ".join(parts)
			summary = AbilityText.summary(def, me, vocab)
		out.append({"name": a.name, "label": label_of(a), "key": str(lib.key_of(a)), "file": lib.file_of(a), "fields": fields,
			"owner": owner.name if owner != null else "", "numbers": numbers, "summary": summary, "asset": a})
	return out

## A status's field as written (Balance.StatusField).
static func status_field(s: StatusAsset, field: String) -> String:
	match field:
		"duration": return str(s.duration)
		"maxStacks": return str(s.max_stacks)
		"stacking": return Stacking.name_of(s.stacking)
		"shield": return s.shield_pool.expression
	return ""

## The statuses: {name, label, key, file, fields: {field: text}, unit ("Turns"/"Rounds"), tags}.
static func status_rows(lib: ContentLibrary, examples := false) -> Array:
	var out := []
	for s in _listed(lib, "StatusAsset", examples):
		var fields := {}
		for f in STATUS_FIELDS: fields[f] = status_field(s, f)
		out.append({"name": s.name, "label": label_of(s), "key": str(lib.key_of(s)), "file": lib.file_of(s), "fields": fields,
			"unit": DurationUnit.name_of(s.duration_unit), "tags": ", ".join(PackedStringArray(s.tags)), "asset": s})
	return out

# ---------------------------------------------------------------- CSV

static func csv_cell(v) -> String:
	var s := str(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n"): return "\"" + s.replace("\"", "\"\"") + "\""
	return s

static func _csv_line(cells: Array) -> String:
	return ",".join(PackedStringArray(cells.map(func(c): return csv_cell(c))))

## The whole sheet as CSV: three sections (Units, Abilities, Statuses), each with its header row, a blank line between.
static func to_csv(lib: ContentLibrary, examples := false) -> String:
	var lines := PackedStringArray()
	var cols := unit_columns(lib, examples)
	lines.append(_csv_line(["section", "group", "name", "key", "cost"] + cols))
	for r in unit_rows(lib, examples):
		var cells := ["Units", r.group, r.label, r.key, r.cost]
		for c in cols: cells.append(r.stats[c])
		lines.append(_csv_line(cells))
	lines.append("")
	lines.append(_csv_line(["section", "name", "key"] + ABILITY_FIELDS + ["owner", "numbers", "summary"]))
	for r in ability_rows(lib, examples):
		var cells := ["Abilities", r.label, r.key]
		for f in ABILITY_FIELDS: cells.append(r.fields[f])
		cells.append_array([r.owner, r.numbers, r.summary])
		lines.append(_csv_line(cells))
	lines.append("")
	lines.append(_csv_line(["section", "name", "key"] + STATUS_FIELDS + ["unit", "tags"]))
	for r in status_rows(lib, examples):
		var cells := ["Statuses", r.label, r.key]
		for f in STATUS_FIELDS: cells.append(r.fields[f])
		cells.append_array([r.unit, r.tags])
		lines.append(_csv_line(cells))
	return "\n".join(lines) + "\n"

## Writes the CSV; returns a problem or "".
static func export_csv(lib: ContentLibrary, path: String = CSV_PATH, examples := false) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return "cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(to_csv(lib, examples))
	f.close()
	return ""
