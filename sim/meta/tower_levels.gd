class_name TowerLevels
extends RefCounted
## Tower levels (Upgrades — Design § Rules), engine-free and static: a tower type's (or form's) ladder, an owned
## tower's level per form, the step being worked on, whether it can be upgraded now (and why not), upgrading, and the
## levelled entity a level builds (the step bonuses, cumulative, baked into the entity's base stats so previews,
## the inspector and the Codex read them like any stat). No currency anywhere. Godot-first (no C# counterpart).
##
## Forms: form_id "" = the tower's default (base) form; a form has its own level (OwnedTower.form_levels) and its own
## ladder (FormDef.levels) and can never pass the base's level. `type` arguments are the base TowerType of the
## owned tower (GameApp.tower_type(owned.type)); a resolved type (Workshop.resolve_form) works too.

## Why the last can_upgrade / upgrade said no ("" when it said yes) — the C# `out string reason`.
static var last_reason: String = ""

const MaxLevelText := "Max level"

## The ladder (Array of TowerLevelDef) of a type's form: the base's for "" , the form's own for a form id (an unknown
## form: []).
static func ladder(type: TowerType, form_id: String = "") -> Array:
	if type == null: return []
	var base: TowerType = type.base if type.base != null else type
	if form_id == "": return base.levels
	var f := base.find_form(form_id)
	return f.levels if f != null else []

## The ladder a built type fights with: its form's when it is a formed type, else its own.
static func ladder_of(def) -> Array:
	if def is Array: return def
	if def is FormDef: return def.levels
	if def is TowerType: return def.form.levels if def.form != null else (def.base.levels if def.base != null else def.levels)
	return []

## The highest level (Upgrades — Design: the ladder's length + 1): of a TowerType (its current form's ladder when it
## is a formed type), a FormDef or a ladder Array. 1 = no levels.
static func max_level(def) -> int:
	return ladder_of(def).size() + 1

## An owned tower's level in a form ("" = the default form; a form never upgraded is level 1).
static func level_of(tower: OwnedTower, form_id: String = "") -> int:
	if tower == null: return 1
	if form_id == "": return maxi(1, tower.level)
	return maxi(1, int(tower.form_levels.get(form_id, 1)))

## The level a level builds the tower at: its current form's level (the base's for the default form; a current form
## the content no longer has falls back to the base, as Workshop.resolve does).
static func current_level(tower: OwnedTower, type: TowerType) -> int:
	if tower == null: return 1
	var f := Workshop.current_form(tower, type)
	return level_of(tower, f.id if f != null else "")

## The task_progress key of a step: "3" (the default form's step to level 3) or "archer-fire:3".
static func step_key(form_id: String, to: int) -> String:
	return str(to) if form_id == "" else "%s:%d" % [form_id, to]

## The step being worked on (to the tower's next level in that form), or null at max level / unknown form.
static func step_for(tower: OwnedTower, type: TowerType, form_id: String = "") -> TowerLevelDef:
	var lad := ladder(type, form_id)
	var next := level_of(tower, form_id) + 1
	for s in lad:
		if s != null and s.to == next: return s
	var i := next - 2
	return lad[i] if i >= 0 and i < lad.size() else null

## The counts of the current step's tasks (one per task, 0 when nothing counted yet); [] without a step.
static func task_counts(tower: OwnedTower, type: TowerType, form_id: String = "") -> Array:
	var step := step_for(tower, type, form_id)
	if step == null or tower == null: return []
	return counts_of(tower, step_key(form_id, step.to), step.tasks.size())

## The saved counts under a step key, padded / cut to n entries.
static func counts_of(tower: OwnedTower, key: String, n: int) -> Array:
	var saved: Array = tower.task_progress.get(key, []) if tower != null else []
	var out := []
	for i in n: out.append(int(saved[i]) if i < saved.size() else 0)
	return out

## Every task of the current step is complete.
static func tasks_done(tower: OwnedTower, type: TowerType, form_id: String = "") -> bool:
	var step := step_for(tower, type, form_id)
	if step == null: return false
	var counts := task_counts(tower, type, form_id)
	for i in step.tasks.size():
		if counts[i] < maxi(1, step.tasks[i].count): return false
	return true

## Whether the tower (in that form) can be upgraded now: the form is unlocked on it, it is below max level, for a form
## the base's level is above the form's, and every task of the step is complete. Reasons: "Max level",
## "Raise Archer to level 3 first", the first missing task ("Deal 18 more damage with it", TowerTasks.missing),
## "No tower", "Not a form of this tower", "Not unlocked on this tower".
static func can_upgrade(tower: OwnedTower, type: TowerType, form_id: String = "") -> bool:
	last_reason = _upgrade_reason(tower, type, form_id)
	return last_reason == ""

static func _upgrade_reason(tower: OwnedTower, type: TowerType, form_id: String) -> String:
	if tower == null or type == null: return "No tower"
	var base: TowerType = type.base if type.base != null else type
	if form_id != "":
		if base.find_form(form_id) == null: return "Not a form of this tower"
		if not Workshop.is_unlocked(tower, form_id): return "Not unlocked on this tower"
	var step := step_for(tower, type, form_id)
	if step == null: return MaxLevelText
	var lvl := level_of(tower, form_id)
	if form_id != "" and level_of(tower) <= lvl:
		return "Raise %s to level %d first" % [base.name if base.name != "" else base.id, lvl + 1]
	var counts := task_counts(tower, type, form_id)
	for i in step.tasks.size():
		if counts[i] < maxi(1, step.tasks[i].count): return TowerTasks.missing(step.tasks[i], counts[i])
	return ""

## Upgrades the tower in that form by one level when can_upgrade says yes: raises the level and drops the step's
## progress (the next step counts from 0). False (and last_reason) otherwise; nothing changes then.
static func upgrade(tower: OwnedTower, type: TowerType, form_id: String = "") -> bool:
	if not can_upgrade(tower, type, form_id): return false
	var step := step_for(tower, type, form_id)
	tower.task_progress.erase(step_key(form_id, step.to))
	if form_id == "": tower.level = step.to
	else: tower.form_levels[form_id] = step.to
	return true

## The ladder a tower works on now: its current form's id when that form is unlocked and in the content, else ""
## (the base). Eren 2026-10-16: the Upgrade view, the ready mark and "N ready" follow the CURRENT form only.
static func current_ladder(tower: OwnedTower, type: TowerType) -> String:
	var f := Workshop.current_form(tower, type)
	return f.id if f != null and Workshop.is_unlocked(tower, f.id) else ""

## Whether the tower can be upgraded now in its CURRENT form (the picker's "ready" mark; another form's ladder never
## counts, Eren 2026-10-16).
static func is_ready(tower: OwnedTower, type: TowerType) -> bool:
	if tower == null or type == null: return false
	var reason := last_reason
	var ready := can_upgrade(tower, type, current_ladder(tower, type))
	last_reason = reason
	return ready

## How many towers are ready now (the Blacksmith's Upgrade station "N ready"): each tower counted once, in its
## current form only (is_ready). type_by_id: Callable(String) -> TowerType (the base type).
static func ready_count(towers: Array, type_by_id: Callable) -> int:
	var n := 0
	for t in towers:
		if t == null: continue
		if is_ready(t, type_by_id.call(t.type)): n += 1
	return n

## Dev cheat (F1 "Level up all towers"): raises every tower and every unlocked form one level where the ladder allows
## (forms stay at or below the base), ignoring tasks; returns how many levels were added.
static func level_up_all(towers: Array, type_by_id: Callable) -> int:
	var n := 0
	for t in towers:
		var type: TowerType = type_by_id.call(t.type) if t != null else null
		if type == null: continue
		var step := step_for(t, type)
		if step != null:
			t.task_progress.erase(step_key("", step.to))
			t.level = step.to
			n += 1
		for f in t.forms:
			var fs := step_for(t, type, f)
			if fs != null and fs.to <= t.level:
				t.task_progress.erase(step_key(f, fs.to))
				t.form_levels[f] = fs.to
				n += 1
	return n

## Dev cheat (F1 "Complete current tasks"): fills every task of every tower's current steps (default form and every
## unlocked form); returns how many steps it completed.
static func complete_tasks(towers: Array, type_by_id: Callable) -> int:
	var n := 0
	for t in towers:
		var type: TowerType = type_by_id.call(t.type) if t != null else null
		if type == null: continue
		for form_id in [""] + t.forms:
			var step := step_for(t, type, form_id)
			if step == null: continue
			var counts := []
			for task in step.tasks: counts.append(maxi(1, task.count))
			t.task_progress[step_key(form_id, step.to)] = counts
			n += 1
	return n

# ------------------------------------------------------------------ bonuses

## The bonuses (Modifier) of every step up to and including level, in ladder order (cumulative).
static func bonuses_at(lad: Array, level: int) -> Array:
	var out := []
	for s in lad:
		if s != null and s.to <= level: out.append_array(s.bonuses)
	return out

## The levelled thing a level builds:
## - a TowerType → a copy at that level (same id, forms, form, base, cost and name; `level` set; the entity levelled
##   with its ladder's bonuses: the form's own ladder for a formed type, else the base's). level ≤ 1 → the type itself.
## - an EntityDef → a copy with the bonuses of `lad` up to level baked into its base stats (level ≤ 1 → itself).
## The content's own definitions are never changed (the converter caches them).
static func apply(what, level: int, lad = null):
	if what == null or level <= 1: return what
	if what is TowerType:
		var steps: Array = lad if lad is Array else ladder_of(what)
		var t := TowerType.new()
		t.id = what.id
		t.name = what.name
		t.description = what.description
		t.cost = what.cost
		t.forms = what.forms
		t.form = what.form
		t.base = what.base
		t.levels = what.levels
		t.level = level
		t.entity = levelled_entity(what.entity, bonuses_at(steps, level))
		return t
	if what is EntityDef:
		return levelled_entity(what, bonuses_at(lad if lad is Array else [], level))
	return what

## A copy of an entity definition with the modifiers baked into its base stats (abilities, passives and tags shared);
## levelled_from points at the original. No modifiers → the definition itself.
static func levelled_entity(def: EntityDef, mods: Array) -> EntityDef:
	if def == null or mods.is_empty(): return def
	var d := EntityDef.new()
	d.name = def.name
	d.display_name = def._display_name
	d.description = def.description
	d.kind = def.kind
	d.tags = def.tags.duplicate()
	d.base_stats = stats_with(def.base_stats, mods)
	d.blocks_projectiles = def.blocks_projectiles
	d.abilities = def.abilities.duplicate()
	d.passives = def.passives.duplicate()
	d.die_with_summoner = def.die_with_summoner
	d.footing = def.footing
	d.levelled_from = def.levelled_from if def.levelled_from != null else def
	return d

## Base stats with the modifiers applied: per stat (base + Flat amounts) × (1 + PctAdd amounts); a stat that was a
## whole number stays one (rounded). Other kinds are ignored (the validator only allows Flat and PctAdd).
static func stats_with(base_stats: Dictionary, mods: Array) -> Dictionary:
	var out := base_stats.duplicate()
	var flat := {}
	var pct := {}
	for m in mods:
		if m == null or m.target == "": continue
		var v := amount_of(m)
		if m.kind == ModKind.Flat: flat[m.target] = float(flat.get(m.target, 0.0)) + v
		elif m.kind == ModKind.PctAdd: pct[m.target] = float(pct.get(m.target, 0.0)) + v
	var stats := {}
	for s in flat: stats[s] = true
	for s in pct: stats[s] = true
	for s in stats:
		var b := float(out.get(s, 0.0))
		var v := (b + float(flat.get(s, 0.0))) * (1.0 + float(pct.get(s, 0.0)))
		out[s] = float(roundi(v)) if is_equal_approx(b, roundf(b)) and pct.has(s) else v
	return out

## A bonus's amount as a number (its formula is a constant; anything else counts 0).
static func amount_of(m: Modifier) -> float:
	var v = AssetConverter.try_parse(m.amount.expression if m != null and m.amount != null else "")
	return float(v) if v != null else 0.0

# ------------------------------------------------------------------ texts

## A stat's name for players ("MaxHp" → "Max HP").
static func stat_name(stat: String) -> String:
	return {"MaxHp": "Max HP"}.get(stat, stat)

## One bonus for players: "+2 Power", "+10% Max HP", "-1 Speed".
static func bonus_text(m: Modifier) -> String:
	var v := amount_of(m)
	if m.kind == ModKind.PctAdd:
		var p := v * 100.0
		return "%s%s%% %s" % ["+" if p >= 0 else "-", _num(absf(p)), stat_name(m.target)]
	return "%s%s %s" % ["+" if v >= 0 else "-", _num(absf(v)), stat_name(m.target)]

## A step's bonuses on one line: "+3 Power, +5 Max HP" ("" for none).
static func bonuses_text(mods: Array) -> String:
	var parts := PackedStringArray()
	for m in mods:
		if m != null: parts.append(bonus_text(m))
	return ", ".join(parts)

## What each level gives (the Codex "Levels" line, the Upgrade view at max level): ["Level 2: +2 Power", …].
static func level_summary(lad: Array) -> Array:
	var out := []
	for s in lad:
		if s != null: out.append("Level %d: %s" % [s.to, bonuses_text(s.bonuses) if not s.bonuses.is_empty() else "no stat change"])
	return out

static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))
