class_name UpgradeLogic
extends RefCounted
## The Upgrade screens' pure helpers (Upgrades — Design § The Upgrade view; UI/UX mockups screens-b/upgrade*.html,
## end-screen-tasks, lv-chip), no nodes and no autoloads, so they can be tested: the picker's "Ready to upgrade"
## filter and count, the detail card's lines, the view's ladders (base + unlocked forms), task rows with their bar
## values ("42 / 60 damage"), the one action and its disabled reason (TowerLevels.last_reason), what a level gives,
## the after-upgrade card's changed stats, the confirm and beat texts and the end screen's task rows.
## The rules themselves are TowerLevels' and TowerTasks' (sim/meta). A ladder id is a form id; "" = the base.
## Eren 2026-10-16 (review of the first build): the view works on the tower's CURRENT form only (no forms row), shows
## no max level, no "Base form", no "What it gives" / "Then" column: left the tower now, centre the tasks and the one
## Upgrade, right the same card AFTER the upgrade (level + 1) with the changed numbers marked.
## `type` arguments are the owned tower's BASE TowerType (GameApp.tower_type(owned.type)).

const BASE := ""

# ------------------------------------------------------------------ the picker

## The picker's ready mark and the "Ready to upgrade" filter: the tower can be upgraded now in its CURRENT form
## (Eren 2026-10-16; the Blacksmith's "N ready" counts the same way: ready_count). TowerLevels.is_ready.
static func is_ready(owned: OwnedTower, type: TowerType) -> bool:
	return TowerLevels.is_ready(owned, type)

## The entries (HandLogic.entries) that pass the "Ready to upgrade" toggle; ready_of: Callable(tower id) -> bool.
static func ready_filter(entries: Array, ready_of: Callable) -> Array:
	return entries.filter(func(e): return bool(ready_of.call(e.id)))

## The grid's count: "5 ready" while the toggle is on, else HandLogic's "10 towers" / "3 of 10 towers".
static func count_text(shown: int, total: int, ready_on: bool) -> String:
	return "%d ready" % shown if ready_on else HandLogic.count_text(shown, total)

## How many towers are ready in their current form (the Blacksmith's "N ready"; TowerLevels.ready_count).
static func ready_count(towers: Array, type_by_id: Callable) -> int:
	return TowerLevels.ready_count(towers, type_by_id)

## "Lv 3".
static func chip_text(level: int) -> String:
	return "Lv %d" % maxi(1, level)

## The picker card's line: "Level 3: 1 of 2 tasks done" (pass the current form's ladder) or "Max level".
static func tasks_done_line(owned: OwnedTower, type: TowerType, form_id := BASE) -> String:
	var step := TowerLevels.step_for(owned, type, form_id)
	if step == null: return TowerLevels.MaxLevelText
	var counts := TowerLevels.task_counts(owned, type, form_id)
	var done := 0
	for i in step.tasks.size():
		if counts[i] >= maxi(1, step.tasks[i].count): done += 1
	return "Level %d: %d of %d task%s done" % [step.to, done, step.tasks.size(), "" if step.tasks.size() == 1 else "s"]

## The picker card's green line: "Fire Archer is ready to upgrade" (the current form's ladder); "" when it is not.
static func ready_line(owned: OwnedTower, type: TowerType) -> String:
	return "%s is ready to upgrade" % ladder_name(type, start_ladder(owned, type)) if is_ready(owned, type) else ""

# ------------------------------------------------------------------ ladders

## A ladder's name: the form's ("Fire Archer"), else the tower type's ("Archer").
static func ladder_name(type: TowerType, form_id := BASE) -> String:
	if type == null: return ""
	var base: TowerType = type.base if type.base != null else type
	var f := base.find_form(form_id) if form_id != BASE else null
	return f.name if f != null else base.name

## The ladder the view shows: the tower's current form when it is unlocked, else the base.
static func start_ladder(owned: OwnedTower, type: TowerType) -> String:
	return TowerLevels.current_ladder(owned, type)

## The highest level of a ladder (5 for a base, 3 for a form with the starter content).
static func max_of(type: TowerType, form_id := BASE) -> int:
	return TowerLevels.ladder(type, form_id).size() + 1

## The card's sub line: "" for the base (Eren 2026-10-16: no "Base form"), "Form of Archer" for a form.
static func form_sub(type: TowerType, form_id := BASE) -> String:
	return "" if form_id == BASE else "Form of " + ladder_name(type, BASE)

## The type a ladder fights as, at its level (the left column's stats): the form resolved, levelled with its ladder.
static func levelled_type(owned: OwnedTower, type: TowerType, form_id := BASE) -> TowerType:
	if type == null: return null
	var base: TowerType = type.base if type.base != null else type
	var f := base.find_form(form_id) if form_id != BASE else null
	var t := Workshop.resolve_form(base, f)
	var lvl := TowerLevels.level_of(owned, form_id)
	return TowerLevels.apply(t, lvl) if lvl > 1 else t

## The same ladder AFTER the upgrade: a levelled copy at the next step's level (the right card); null at max level.
static func after_type(owned: OwnedTower, type: TowerType, form_id := BASE) -> TowerType:
	var step := TowerLevels.step_for(owned, type, form_id)
	if type == null or step == null: return null
	var base: TowerType = type.base if type.base != null else type
	var f := base.find_form(form_id) if form_id != BASE else null
	return TowerLevels.apply(Workshop.resolve_form(base, f), step.to)

## What changes between two stat tile lists (HandLogic.stat_tiles: [[stat, label, value], …]): {stat: "+5"} for every
## stat whose value differs ("-1" when it drops; a stat new in `after`: its value with "+").
static func stat_diffs(now: Array, after: Array) -> Dictionary:
	var before := {}
	for t in now: before[t[0]] = float(t[2])
	var out := {}
	for t in after:
		var v := float(t[2])
		var d := v - float(before.get(t[0], 0.0))
		if is_zero_approx(d): continue
		out[t[0]] = ("+" if d > 0 else "-") + HandLogic.num_text(absf(d))
	return out

# ------------------------------------------------------------------ tasks

## The rows of the current step's tasks: {text, have, need, done, bar (a bar shows: count > 1), ratio (0..1),
## have_text "42", need_text "60 damage", progress "42 / 60 damage", kind, index (the task's index in the step:
## GameApp.pay_into), gold (a gold Pay task: the row gets the Pay button), missing (what is still missing)}.
## [] at max level.
static func task_rows(owned: OwnedTower, type: TowerType, form_id := BASE) -> Array:
	var out := []
	var step := TowerLevels.step_for(owned, type, form_id)
	if step == null: return out
	var counts := TowerLevels.task_counts(owned, type, form_id)
	for i in step.tasks.size():
		var r := task_row(step.tasks[i], counts[i])
		r["index"] = i
		out.append(r)
	return out

## One task row (see task_rows).
static func task_row(task: TaskDef, have: int) -> Dictionary:
	var need := maxi(1, task.count) if task != null else 1
	var h := clampi(have, 0, need)
	return {"text": TowerTasks.describe(task), "have": h, "need": need, "done": h >= need, "bar": need > 1,
		"ratio": float(h) / float(need), "have_text": str(h), "need_text": "%d %s" % [need, unit(task, need)],
		"progress": "%d / %d %s" % [h, need, unit(task, need)], "kind": task.kind if task != null else -1,
		"index": -1, "gold": TowerTasks.is_gold(task), "missing": need - h}

## What a task counts, short, for "1 / 2 missions", "4 / 10 kills", "42 / 60 damage".
static func unit(task: TaskDef, n: int) -> String:
	if task == null: return ""
	if task.text != "": return ""
	match task.kind:
		TowerTaskKind.WinMission: return "mission" if n == 1 else "missions"
		TowerTaskKind.WinLevel: return "level" if n == 1 else "levels"
		TowerTaskKind.WinMissionId, TowerTaskKind.WinNoLoss: return "win" if n == 1 else "wins"
		TowerTaskKind.Kills: return "kill" if n == 1 else "kills"
		TowerTaskKind.Damage: return "damage"
		TowerTaskKind.HitsTaken: return "hit" if n == 1 else "hits"
		TowerTaskKind.Placed: return "time" if n == 1 else "times"
		TowerTaskKind.Pay: return TowerTasks.currency_text(task)
	return ""

## A task kind's icon name (TdDrops.icon_texture: the extra set, then the kit): flag for wins, range (a target)
## for kills, power (the sword) for damage, heart for hits taken, cards for placing.
static func task_icon(kind: int) -> String:
	match kind:
		TowerTaskKind.Kills: return "range"
		TowerTaskKind.Damage: return "power"
		TowerTaskKind.HitsTaken: return "heart"
		TowerTaskKind.Placed: return "cards"
		TowerTaskKind.Pay: return "gold"
	return "flag"

# ------------------------------------------------------------------ the action

## The view's one action for a ladder: {kind "upgrade" | "blocked" | "max", text "Upgrade to level 3", to,
## reason ("" when it can; TowerLevels.last_reason: the first missing task, "Raise Archer to level 3 first", …),
## lock (the reason is the form cap), note (the line under the disabled button: ONLY the form cap, "Raise Archer to
## level 3 first", with a lock; a missing task has no line, its bar shows it: Eren 2026-10-16)}. unlocked false
## (before the Blacksmith): "The Blacksmith is not open yet" (a note too).
static func action(owned: OwnedTower, type: TowerType, form_id := BASE, unlocked := true) -> Dictionary:
	var step := TowerLevels.step_for(owned, type, form_id)
	if step == null: return {"kind": "max", "text": TowerLevels.MaxLevelText, "to": 0, "reason": TowerLevels.MaxLevelText, "lock": false, "note": ""}
	var text := "Upgrade to level %d" % step.to
	if not unlocked:
		var no := "The Blacksmith is not open yet"
		return {"kind": "blocked", "text": text, "to": step.to, "reason": no, "lock": true, "note": no}
	var ok := TowerLevels.can_upgrade(owned, type, form_id)
	var reason := TowerLevels.last_reason
	var lock := reason.begins_with("Raise ")
	return {"kind": "upgrade" if ok else "blocked", "text": text, "to": step.to, "reason": reason,
		"lock": lock, "note": reason if lock else ""}

# ------------------------------------------------------------------ what a level gives

## A step's bonuses as [[stat, "+5", "Max HP"], …] (the green chips).
static func bonus_parts(mods: Array) -> Array:
	var out := []
	for m in mods:
		if m == null: continue
		var t := TowerLevels.bonus_text(m)
		var sp := t.find(" ")
		out.append([m.target, t.substr(0, sp) if sp > 0 else t, t.substr(sp + 1) if sp > 0 else ""])
	return out

## The step to a level of a ladder (null when none).
static func step_to(type: TowerType, form_id: String, to: int) -> TowerLevelDef:
	for s in TowerLevels.ladder(type, form_id):
		if s != null and s.to == to: return s
	return null

## "Archer is at its highest level."
static func max_line(type: TowerType, form_id := BASE) -> String:
	return "%s is at its highest level." % ladder_name(type, form_id)


# ------------------------------------------------------------------ confirm and beat

## "Upgrade Archer to level 3?"
static func confirm_title(type: TowerType, form_id: String, to: int) -> String:
	return "Upgrade %s to level %d?" % [ladder_name(type, form_id), to]

## "It gives +5 Max HP. The next level's tasks start counting." (the last level: "… It is the highest level.";
## no bonus: "No stat change. …"). The bonuses come as BBCode-free text; the screen colours them.
static func confirm_body(owned: OwnedTower, type: TowerType, form_id := BASE) -> String:
	var step := TowerLevels.step_for(owned, type, form_id)
	if step == null: return ""
	var g := TowerLevels.bonuses_text(step.bonuses)
	var head := "It gives %s." % g if g != "" else "No stat change."
	var last := step_to(type, form_id, step.to + 1) == null
	return head + (" It is the highest level." if last else " The next level's tasks start counting.")

## "Archer reached level 3!" (the beat after an upgrade).
static func beat_text(type: TowerType, form_id: String, level: int) -> String:
	return "%s reached level %d!" % [ladder_name(type, form_id), level]

# ------------------------------------------------------------------ the end screen (mockup end-screen-tasks)

## The end screen's task rows from LevelController.task_advances: {who "Archer", where "(tower 3)" or "", text
## "Get 10 kills with it", done, progress "8 / 10 kills", gain "+3", kind}. A done task shows "Done" (no progress).
static func end_rows(advances: Array) -> Array:
	var out := []
	for a in advances:
		var n := int(a.get("count", 1))
		var task := TaskDef.new()
		task.kind = int(a.get("kind", -1))
		out.append({"who": str(a.get("name", "")), "where": "(tower %d)" % int(a.index) if int(a.get("index", 0)) > 0 else "",
			"text": str(a.get("text", "")), "done": bool(a.get("done", false)),
			"progress": ("%d / %d %s" % [int(a.get("after", 0)), n, unit(task, n)]).strip_edges(),
			"gain": "+%d" % int(a.get("gain", 0)), "kind": task.kind})
	return out

## The names whose step this level made upgradeable ("Guardian" → "Guardian is ready to upgrade! Go to the
## Blacksmith."), each once.
static func end_ready(advances: Array) -> Array:
	var out := []
	for a in advances:
		if a.get("ready", false) and not out.has(str(a.name)): out.append(str(a.name))
	return out

## The end screen shows at most this many task rows; the rest fold into "+N more".
const END_ROWS := 4

## "+2 more tasks moved" for the rows past END_ROWS ("" when none).
static func end_more(rows: int) -> String:
	var n := rows - END_ROWS
	return "" if n <= 0 else "+%d more task%s moved" % [n, "" if n == 1 else "s"]

# ------------------------------------------------------------------ the Codex

## The Codex tower page's "Levels" lines for a type's ladder (base or a form): TowerLevels.level_summary.
static func codex_levels(type: TowerType, form_id := BASE) -> Array:
	return TowerLevels.level_summary(TowerLevels.ladder(type, form_id))

## The highest level among the owned towers of a type in a ladder (the Codex header chip); 0 when none is owned.
static func best_level(towers: Array, type_id: String, form_id := BASE) -> int:
	var best := 0
	for o in towers:
		if o == null or o.type != type_id: continue
		if form_id != BASE and not Workshop.is_unlocked(o, form_id): continue
		best = maxi(best, TowerLevels.level_of(o, form_id))
	return best
