class_name TowerTasks
extends RefCounted
## Tower level tasks (Upgrades — Design § Rules), engine-free and static: a task's text, what is still missing, and
## the counting at the end of a level / mission from its result and event log. Counting is per tower (this Archer, not
## any Archer) and only for the step being worked on (TowerLevels.step_for) in the form the tower played as.
## Godot-first (no C# counterpart).
##
## How a placed entity maps back to its owned tower: LevelSession.place opens a Place action whose detail is the hand
## tower's id (TowerDef.id = the OwnedTower id in single player; "<player>:<type>#n" in co-op, see entry()) and the
## tower's entity is the first EntitySpawned of that action. Kills = EntityDied whose source is such an entity;
## damage = the FinalDamage of its DamageDealt events (not on its own towers); hits taken = DamageDealt on it, counted
## only for entities that did not die; placed = its Place actions.
##
## Pay tasks ("Pay 40 gold", Eren 2026-10-16) are never counted from play: the Upgrade view's Pay button deposits
## into them (deposit; GameApp.pay_into takes it from GameData.gold), stored in the same task_progress counts.

const Check := "✓"
## The Pay currency of the gold task every step has (Upgrades — Design § Gold).
const Gold := "gold"

## One tower taking part in a level, for apply(): the owned tower, its BASE type (GameApp.tower_type(owned.type):
## ladders of the base and its forms), the id the session knows it by ("" = owned.id: single player; co-op:
## "<player id>:<type>#n") and the name the end screen shows ("" = the custom name, else the ladder's tower / form name).
## index: the tower's 1-based place in the collection ("tower 3"; 0 = unknown).
static func entry(owned: OwnedTower, type: TowerType, session_id: String = "", display_name: String = "", index: int = 0) -> Dictionary:
	return {"owned": owned, "type": type, "session_id": session_id if session_id != "" else (owned.id if owned != null else ""), "name": display_name, "index": index}

# ------------------------------------------------------------------ texts

## A task for players, from its kind and count unless it has its own text: "Win a mission with this tower",
## "Win 2 missions with this tower", "Deal 60 damage with it", "Defeat 10 enemies with it", "Take 40 hits and survive",
## "Place it 3 times", "Win Drum Line with this tower", "Win without losing a tower", "Pay 40 gold".
static func describe(task: TaskDef) -> String:
	if task == null: return ""
	if task.text != "": return task.text
	var n := maxi(1, task.count)
	match task.kind:
		TowerTaskKind.WinMission: return "Win a mission with this tower" if n == 1 else "Win %d missions with this tower" % n
		TowerTaskKind.WinLevel: return "Win a level with this tower" if n == 1 else "Win %d levels with this tower" % n
		TowerTaskKind.WinMissionId:
			var m := task.mission_name if task.mission_name != "" else task.mission
			return "Win %s with this tower" % m if n == 1 else "Win %s %d times with this tower" % [m, n]
		TowerTaskKind.Kills: return "Defeat an enemy with it" if n == 1 else "Defeat %d enemies with it" % n
		TowerTaskKind.Damage: return "Deal %d damage with it" % n
		TowerTaskKind.HitsTaken: return "Take a hit and survive" if n == 1 else "Take %d hits and survive" % n
		TowerTaskKind.Placed: return "Place it on the board" if n == 1 else "Place it %d times" % n
		TowerTaskKind.WinNoLoss: return "Win without losing a tower" if n == 1 else "Win %d times without losing a tower" % n
		TowerTaskKind.Pay: return "Pay %d %s" % [n, currency_text(task)]
	return TowerTaskKind.name_of(task.kind)

## A Pay task (deposited with the Pay button, never counted from play).
static func is_pay(task: TaskDef) -> bool:
	return task != null and task.kind == TowerTaskKind.Pay

## A Pay task in gold.
static func is_gold(task: TaskDef) -> bool:
	return is_pay(task) and task.currency == Gold

## What a Pay task deposits, for texts: "gold", else the currency (a token id; the screen may show the token's name).
static func currency_text(task: TaskDef) -> String:
	return Gold if task == null or task.currency == "" else task.currency

## The index of a step's gold Pay task (-1 when it has none; the validator requires exactly one).
static func gold_task_index(step: TowerLevelDef) -> int:
	if step == null: return -1
	for i in step.tasks.size():
		if is_gold(step.tasks[i]): return i
	return -1

## Deposits from a wallet into the Pay task task_index of the tower's current step in that form ("" = the base
## ladder): takes min(wallet_amount, what the task still misses), adds it to the step's task_progress count and
## returns the amount taken (the caller removes it from the wallet). 0 when there is no such step / Pay task, the
## form is not unlocked on the tower, the task is already full, or wallet_amount ≤ 0. Partial deposits are allowed;
## deposited currency is spent (an upgrade drops the step's progress like any task's).
static func deposit(tower: OwnedTower, type: TowerType, form_id: String, task_index: int, wallet_amount: int) -> int:
	if tower == null or type == null or wallet_amount <= 0: return 0
	if form_id != "":
		var base: TowerType = type.base if type.base != null else type
		if base.find_form(form_id) == null or not Workshop.is_unlocked(tower, form_id): return 0
	var step := TowerLevels.step_for(tower, type, form_id)
	if step == null or task_index < 0 or task_index >= step.tasks.size(): return 0
	var task: TaskDef = step.tasks[task_index]
	if not is_pay(task): return 0
	var key := TowerLevels.step_key(form_id, step.to)
	var counts := TowerLevels.counts_of(tower, key, step.tasks.size())
	var take := mini(wallet_amount, maxi(1, task.count) - int(counts[task_index]))
	if take <= 0: return 0
	counts[task_index] = int(counts[task_index]) + take
	tower.task_progress[key] = counts
	return take

## What a Pay task of the tower's current step still misses (0 when full or not a Pay task).
static func pay_missing(tower: OwnedTower, type: TowerType, form_id: String, task_index: int) -> int:
	var step := TowerLevels.step_for(tower, type, form_id)
	if step == null or task_index < 0 or task_index >= step.tasks.size() or not is_pay(step.tasks[task_index]): return 0
	var counts := TowerLevels.task_counts(tower, type, form_id)
	return maxi(0, maxi(1, step.tasks[task_index].count) - int(counts[task_index]))

## What is still missing of a task with `have` counted (the Upgrade button's disabled reason): nothing counted yet →
## describe(); else "Deal 18 more damage with it", "Win 1 more mission with this tower", "Defeat 4 more enemies with
## it", "Take 12 more hits and survive", "Place it 2 more times"; a task with its own text: "<text> (2/5)".
## "" when complete.
static func missing(task: TaskDef, have: int) -> String:
	if task == null: return ""
	var n := maxi(1, task.count)
	var left := n - have
	if left <= 0: return ""
	if have <= 0: return describe(task)
	if task.text != "": return "%s (%d/%d)" % [task.text, have, n]
	match task.kind:
		TowerTaskKind.WinMission: return "Win %d more mission%s with this tower" % [left, _s(left)]
		TowerTaskKind.WinLevel: return "Win %d more level%s with this tower" % [left, _s(left)]
		TowerTaskKind.WinMissionId:
			return "Win %s %d more time%s with this tower" % [task.mission_name if task.mission_name != "" else task.mission, left, _s(left)]
		TowerTaskKind.Kills: return "Defeat %d more enem%s with it" % [left, "y" if left == 1 else "ies"]
		TowerTaskKind.Damage: return "Deal %d more damage with it" % left
		TowerTaskKind.HitsTaken: return "Take %d more hit%s and survive" % [left, _s(left)]
		TowerTaskKind.Placed: return "Place it %d more time%s" % [left, _s(left)]
		TowerTaskKind.WinNoLoss: return "Win %d more time%s without losing a tower" % [left, _s(left)]
		TowerTaskKind.Pay: return "Pay %d more %s" % [left, currency_text(task)]
	return describe(task)

## "42/60" (capped at the count); a Pay task: "25 / 40 gold".
static func progress_text(task: TaskDef, have: int) -> String:
	var n := maxi(1, task.count) if task != null else 1
	if is_pay(task): return "%d / %d %s" % [mini(have, n), n, currency_text(task)]
	return "%d/%d" % [mini(have, n), n]

## The end screen's lines for apply()'s advances: every progress_line ("Archer (tower 3): 8 / 10 kills +3"), then the
## ready_lines ("Guardian is ready to upgrade! Go to the Blacksmith.").
static func lines(advances: Array) -> Array:
	var out := []
	for a in advances: out.append(progress_line(a))
	out.append_array(ready_lines(advances))
	return out

static func _s(n: int) -> String:
	return "" if n == 1 else "s"

# ------------------------------------------------------------------ counting

## Counts the level's tasks for the towers that took part (entries from entry(): the level's hand, which is what
## "present" means) and stores them on the owned towers. A tower in its default form counts toward its base ladder's
## current step; a tower fighting in a form counts toward BOTH its base ladder's step (its career) and that form's
## step (Upgrades — Design § Rules). result: the LevelResult; log: the session's EventLog; mission_id: the mission
## played ("" for a chapter level). Nothing counts when `unlocked` is false (before the Blacksmith unlock: counting
## starts there) or on a quit. Counts never pass a task's count. Returns the advances, one per task that moved, in
## entry, ladder (base first) and task order:
## {tower (owned id), index (1-based place in the collection, 0 unknown), name (custom name, else the ladder's tower /
## form name), form ("" = the base ladder), to (the step's level), task (index), kind, text, noun, before, after,
## gain, count, done, ready (this level made the step upgradeable: TowerLevels.can_upgrade turned true)}.
static func apply(result: LevelResult, log: EventLog, towers: Array, mission_id: String = "", unlocked: bool = true) -> Array:
	var out := []
	if not unlocked or result == null or result.quit: return out
	var facts := tally(log)
	var reason := TowerLevels.last_reason
	for e in towers:
		var owned: OwnedTower = e.get("owned")
		var type: TowerType = e.get("type")
		if owned == null or type == null: continue
		var base: TowerType = type.base if type.base != null else type
		var form_id: String = owned.form if owned.form != "" and base.find_form(owned.form) != null else ""
		var sid: String = e.get("session_id", owned.id)
		var ladders := [""] if form_id == "" else ["", form_id]
		for lf in ladders:
			var step := TowerLevels.step_for(owned, base, lf)
			if step == null or step.tasks.is_empty(): continue
			var was_ready := TowerLevels.can_upgrade(owned, base, lf)
			var key := TowerLevels.step_key(lf, step.to)
			var counts := TowerLevels.counts_of(owned, key, step.tasks.size())
			var moved := []
			for i in step.tasks.size():
				var task: TaskDef = step.tasks[i]
				var n := maxi(1, task.count)
				var before: int = counts[i]
				var after := mini(n, before + _gain(task, result, mission_id, facts, sid))
				if after == before: continue
				counts[i] = after
				var f := base.find_form(lf) if lf != "" else null
				var shown: String = e.get("name", "")
				if shown == "": shown = owned.custom_name if owned.custom_name != "" else (f.name if f != null else base.name)
				moved.append({"tower": owned.id, "index": int(e.get("index", 0)), "name": shown, "form": lf, "to": step.to,
					"task": i, "kind": task.kind, "text": describe(task), "noun": noun(task), "before": before, "after": after,
					"gain": after - before, "count": n, "done": after >= n, "ready": false})
			if moved.is_empty(): continue
			owned.task_progress[key] = counts
			if not was_ready and TowerLevels.can_upgrade(owned, base, lf): moved[-1].ready = true
			out.append_array(moved)
	TowerLevels.last_reason = reason
	return out

## What a task counts, for "8 / 10 kills": kills, damage, hits survived, times placed, missions won, levels won,
## "Drum Line wins", wins without a loss (a task with its own text: that text).
static func noun(task: TaskDef) -> String:
	if task == null: return ""
	if task.text != "": return task.text
	match task.kind:
		TowerTaskKind.WinMission: return "missions won"
		TowerTaskKind.WinLevel: return "levels won"
		TowerTaskKind.WinMissionId: return "%s wins" % (task.mission_name if task.mission_name != "" else task.mission)
		TowerTaskKind.Kills: return "kills"
		TowerTaskKind.Damage: return "damage"
		TowerTaskKind.HitsTaken: return "hits survived"
		TowerTaskKind.Placed: return "times placed"
		TowerTaskKind.WinNoLoss: return "wins without a loss"
		TowerTaskKind.Pay: return currency_text(task)
	return TowerTaskKind.name_of(task.kind)

## The end screen's progress line of one advance: "Archer (tower 3): 8 / 10 kills +3" ("Archer: …" without an index).
static func progress_line(a: Dictionary) -> String:
	var who: String = a.name if int(a.get("index", 0)) <= 0 else "%s (tower %d)" % [a.name, a.index]
	return "%s: %d / %d %s +%d" % [who, a.after, a.count, a.noun, a.gain]

## The end screen's "ready" lines: one per tower / form whose step this level made upgradeable:
## "Guardian is ready to upgrade! Go to the Blacksmith."
static func ready_lines(advances: Array) -> Array:
	var out := []
	for a in advances:
		if a.get("ready", false): out.append("%s is ready to upgrade! Go to the Blacksmith." % a.name)
	return out

## What one task gains from this level for the session tower sid.
static func _gain(task: TaskDef, result: LevelResult, mission_id: String, facts: Dictionary, sid: String) -> int:
	match task.kind:
		TowerTaskKind.WinMission: return 1 if result.won and mission_id != "" else 0
		TowerTaskKind.WinLevel: return 1 if result.won else 0
		TowerTaskKind.WinMissionId: return 1 if result.won and mission_id != "" and mission_id == task.mission else 0
		TowerTaskKind.WinNoLoss: return 1 if result.won and result.towers_lost == 0 else 0
		TowerTaskKind.Kills: return int(facts.kills.get(sid, 0))
		TowerTaskKind.Damage: return int(facts.damage.get(sid, 0))
		TowerTaskKind.HitsTaken: return int(facts.hits.get(sid, 0))
		TowerTaskKind.Placed: return int(facts.placed.get(sid, 0))
		TowerTaskKind.Pay: return 0 # deposited with the Pay button (deposit), never counted from play
	return 0

## The per-tower facts of a level's log: {entity: {entity id: session tower id}, placed, kills, damage, hits:
## {session tower id: n}} (see the class doc for what counts).
static func tally(log: EventLog) -> Dictionary:
	var out := {"entity": {}, "placed": {}, "kills": {}, "damage": {}, "hits": {}}
	if log == null: return out
	var of_entity: Dictionary = out.entity
	var seen_action := {}
	var died := {}
	for e in log.events:
		if e.type == GameEventType.EntitySpawned and e.action >= 0 and e.action < log.actions.size() and not seen_action.has(e.action):
			var a: ActionInfo = log.actions[e.action]
			if a.kind == ActionKind.Place and a.detail != null:
				seen_action[e.action] = true
				of_entity[e.target] = str(a.detail)
				out.placed[str(a.detail)] = int(out.placed.get(str(a.detail), 0)) + 1
		elif e.type == GameEventType.EntityDied:
			died[e.target] = true
			if of_entity.has(e.source) and not of_entity.has(e.target):
				var t: String = of_entity[e.source]
				out.kills[t] = int(out.kills.get(t, 0)) + 1
		elif e.type == GameEventType.DamageDealt:
			if of_entity.has(e.source) and not of_entity.has(e.target):
				var t: String = of_entity[e.source]
				out.damage[t] = int(out.damage.get(t, 0)) + int(floor(float(e.facts.get("FinalDamage", 0.0))))
	# hits taken and survived: every DamageDealt on a tower entity that never died (a sold or still standing tower)
	for e in log.events:
		if e.type == GameEventType.DamageDealt and of_entity.has(e.target) and not died.has(e.target):
			var t: String = of_entity[e.target]
			out.hits[t] = int(out.hits.get(t, 0)) + 1
	return out
