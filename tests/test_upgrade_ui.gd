extends TestCase
## The Upgrade screens' pure logic (game/ui/screens/parts/upgrade_logic.gd; Upgrades — Design § The Upgrade view):
## the picker's ready mark (the current form) and count, the card lines, the current-form ladder, the now / after
## types and the changed stats, task rows and bar values, the one action (reasons; a line only for the form cap),
## confirm / beat texts, the end screen's task rows and the Codex lines.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func _type(id := "archer") -> TowerType:
	return AssetConverter.new().tower_type(lib().catalog.find_tower(id))

func _owned(type := "archer", id := "t1") -> OwnedTower:
	var o := OwnedTower.new()
	o.id = id
	o.type = type
	return o

func _entry(id: String) -> Dictionary:
	return {"id": id}

# ------------------------------------------------------------------ the picker

func test_ready_mark_is_the_current_form() -> void:
	var t := _type()
	var a := _owned("archer", "a")          # base step 2: Win a mission (not done)
	var b := _owned("archer", "b")          # base ready (won, 100 gold paid)
	b.task_progress["2"] = [1, 100]
	var c := _owned("archer", "c")          # base not ready; its Fire Archer is (level 2 base > form level 1)
	c.level = 2
	c.forms.append("archer-fire")
	c.task_progress["archer-fire:2"] = [1]  # forms need no gold: the win is the whole step
	assert_false(UpgradeLogic.is_ready(a, t))
	assert_true(UpgradeLogic.is_ready(b, t))
	assert_false(UpgradeLogic.is_ready(c, t), "a ready form it does not wear: no mark (Eren 2026-10-16)")
	c.form = "archer-fire"
	assert_true(UpgradeLogic.is_ready(c, t), "wearing the ready form")
	c.form = ""
	var ready := {"a": UpgradeLogic.is_ready(a, t), "b": UpgradeLogic.is_ready(b, t), "c": UpgradeLogic.is_ready(c, t)}
	var shown := UpgradeLogic.ready_filter([_entry("a"), _entry("b"), _entry("c")], func(id): return ready[id])
	assert_seq(shown.map(func(e): return e.id), ["b"])
	assert_eq(UpgradeLogic.count_text(1, 10, true), "1 ready")
	assert_eq(UpgradeLogic.count_text(10, 10, false), "10 towers")
	assert_eq(UpgradeLogic.count_text(3, 10, false), "3 of 10 towers")
	assert_eq(UpgradeLogic.ready_count([a, b, c], func(_id): return t), 1, "the station counts current forms only")
	c.form = "archer-fire"
	assert_eq(UpgradeLogic.ready_count([a, b, c], func(_id): return t), 2)

func test_card_lines() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	o.task_progress["3"] = [1, 42]
	assert_eq(UpgradeLogic.tasks_done_line(o, t), "Level 3: 1 of 3 tasks done", "win, damage and the gold task")
	assert_eq(UpgradeLogic.ready_line(o, t), "")
	o.forms.append("archer-fire")
	o.task_progress["archer-fire:2"] = [1]
	assert_eq(UpgradeLogic.ready_line(o, t), "", "the form is ready but not worn")
	o.form = "archer-fire"
	assert_eq(UpgradeLogic.ready_line(o, t), "Fire Archer is ready to upgrade")
	assert_eq(UpgradeLogic.tasks_done_line(o, t, "archer-fire"), "Level 2: 1 of 1 task done", "no gold task on a form")
	o.form = ""
	o.task_progress["3"] = [1, 60, 200]
	assert_eq(UpgradeLogic.ready_line(o, t), "Archer is ready to upgrade")
	o.level = 5
	assert_eq(UpgradeLogic.tasks_done_line(o, t), "Max level")
	assert_eq(UpgradeLogic.chip_text(3), "Lv 3")
	assert_eq(UpgradeLogic.chip_text(0), "Lv 1")

# ------------------------------------------------------------------ ladders and tasks

func test_ladders_now_and_after() -> void:
	var t := _type()
	var o := _owned()
	assert_eq(UpgradeLogic.ladder_name(t, ""), "Archer")
	assert_eq(UpgradeLogic.ladder_name(t, "archer-fire"), "Fire Archer")
	assert_eq(UpgradeLogic.max_of(t, ""), 5)
	assert_eq(UpgradeLogic.max_of(t, "archer-fire"), 4, "a form: 3 steps to level 4")
	assert_eq(UpgradeLogic.form_sub(t, ""), "", "no \"Base form\" line")
	assert_eq(UpgradeLogic.form_sub(t, "archer-fire"), "Form of Archer")
	o.level = 2
	assert_eq(UpgradeLogic.start_ladder(o, t), "")
	o.form = "archer-fire"
	assert_eq(UpgradeLogic.start_ladder(o, t), "", "a form not unlocked: the base")
	o.forms.append("archer-fire")
	assert_eq(UpgradeLogic.start_ladder(o, t), "archer-fire", "the current form")
	o.form = ""
	# now: Archer level 2 = +2 Power; after: level 3 = +5 Max HP on top
	var base_power := float(t.entity.base_stats.get("Power", 0.0))
	var base_hp := float(t.entity.base_stats.get("MaxHp", 0.0))
	var now := UpgradeLogic.levelled_type(o, t, "")
	assert_eq(float(now.entity.base_stats.get("Power", 0.0)), base_power + 2.0)
	var after := UpgradeLogic.after_type(o, t, "")
	assert_eq(after.level, 3)
	assert_eq(float(after.entity.base_stats.get("Power", 0.0)), base_power + 2.0)
	assert_eq(float(after.entity.base_stats.get("MaxHp", 0.0)), base_hp + 5.0)
	assert_eq(UpgradeLogic.levelled_type(o, t, "archer-fire").name, "Fire Archer")
	assert_eq(UpgradeLogic.after_type(o, t, "archer-fire").level, 2)
	o.level = 5
	assert_null(UpgradeLogic.after_type(o, t, ""), "max level: no after card")

func test_stat_diffs() -> void:
	var now := [["MaxHp", "Max HP", "20"], ["Power", "Power", "12"], ["Range", "Range", "2"]]
	var after := [["MaxHp", "Max HP", "25"], ["Power", "Power", "12"], ["Range", "Range", "3"], ["Potency", "Potency", "1"]]
	assert_eq(UpgradeLogic.stat_diffs(now, after), {"MaxHp": "+5", "Range": "+1", "Potency": "+1"})
	assert_eq(UpgradeLogic.stat_diffs(after, now).get("MaxHp"), "-5")
	assert_eq(UpgradeLogic.stat_diffs([["Speed", "Speed", "1.5"]], [["Speed", "Speed", "2"]]), {"Speed": "+0.5"})

func test_task_rows_and_bar_values() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	o.task_progress["3"] = [1, 42]
	var rows := UpgradeLogic.task_rows(o, t)
	assert_eq(rows.size(), 3, "win, damage and the gold task (Pay 40 gold)")
	assert_eq(rows[0].text, "Win a mission with this tower")
	assert_true(rows[0].done)
	assert_false(rows[0].bar, "a one-off task has no bar")
	assert_eq(rows[1].text, "Deal 60 damage with it")
	assert_false(rows[1].done)
	assert_true(rows[1].bar)
	assert_eq(rows[1].progress, "42 / 60 damage")
	assert_eq(rows[1].have_text, "42")
	assert_eq(rows[1].need_text, "60 damage")
	assert_num(rows[1].ratio, 0.7)
	assert_eq(UpgradeLogic.task_icon(rows[1].kind), "power")
	# capped at the count
	o.task_progress["3"] = [1, 99]
	assert_eq(UpgradeLogic.task_rows(o, t)[1].progress, "60 / 60 damage")
	assert_eq(UpgradeLogic.task_rows(o, t)[1].ratio, 1.0)
	# level 4: "1 / 2 missions", "4 / 10 kills"
	o.level = 3
	o.task_progress["4"] = [1, 4]
	rows = UpgradeLogic.task_rows(o, t)
	assert_eq(rows[0].progress, "1 / 2 missions")
	assert_eq(rows[1].progress, "4 / 10 kills")
	assert_eq(UpgradeLogic.task_icon(rows[0].kind), "flag")
	assert_eq(UpgradeLogic.task_icon(rows[1].kind), "range")
	o.level = 5
	assert_eq(UpgradeLogic.task_rows(o, t), [])

# ------------------------------------------------------------------ the action and its reasons

func test_action_reasons() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	o.task_progress["3"] = [1, 42]
	var a := UpgradeLogic.action(o, t)
	assert_eq(a.kind, "blocked")
	assert_eq(a.text, "Upgrade to level 3")
	assert_eq(a.reason, "Deal 18 more damage with it")
	assert_false(a.lock)
	assert_eq(a.note, "", "a missing task: no line under the button (the bar shows it)")
	o.task_progress["3"] = [0, 0]
	assert_eq(UpgradeLogic.action(o, t).reason, "Win a mission with this tower", "nothing counted: the task itself")
	o.task_progress["3"] = [1, 60]
	assert_eq(UpgradeLogic.action(o, t).reason, "Pay 200 gold", "the gold task is still open")
	o.task_progress["3"] = [1, 60, 200]
	a = UpgradeLogic.action(o, t)
	assert_eq(a.kind, "upgrade")
	assert_eq(a.reason, "")
	assert_eq(a.to, 3)
	assert_eq(UpgradeLogic.action(o, t, "", false).reason, "The Blacksmith is not open yet")
	# a form behind its base: the cap, with the lock
	o.forms.append("archer-fire")
	o.form_levels["archer-fire"] = 2
	o.task_progress["archer-fire:3"] = [80]
	a = UpgradeLogic.action(o, t, "archer-fire")
	assert_eq(a.kind, "blocked")
	assert_eq(a.reason, "Raise Archer to level 3 first")
	assert_true(a.lock)
	assert_eq(a.note, "Raise Archer to level 3 first", "the form cap keeps its line")
	# max level
	o.level = 5
	a = UpgradeLogic.action(o, t)
	assert_eq(a.kind, "max")
	assert_eq(a.reason, "Max level")

# ------------------------------------------------------------------ gives, then, max

func test_max_line() -> void:
	var t := _type()
	assert_eq(UpgradeLogic.max_line(t), "Archer is at its highest level.")
	assert_eq(UpgradeLogic.max_line(t, "archer-fire"), "Fire Archer is at its highest level.")
	assert_eq(UpgradeLogic.bonus_parts(t.levels[3].bonuses), [["Power", "+3", "Power"], ["MaxHp", "+5", "Max HP"]])

func test_confirm_and_beat_texts() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	assert_eq(UpgradeLogic.confirm_title(t, "", 3), "Upgrade Archer to level 3?")
	assert_eq(UpgradeLogic.confirm_body(o, t), "It gives +5 Max HP. The next level's tasks start counting.")
	o.level = 4
	assert_eq(UpgradeLogic.confirm_body(o, t), "It gives +3 Power, +5 Max HP. It is the highest level.")
	assert_eq(UpgradeLogic.beat_text(t, "", 3), "Archer reached level 3!")
	assert_eq(UpgradeLogic.beat_text(t, "archer-fire", 2), "Fire Archer reached level 2!")

# ------------------------------------------------------------------ end screen and Codex

func test_end_rows() -> void:
	var adv := [
		{"tower": "a", "index": 3, "name": "Archer", "form": "", "to": 4, "task": 1, "kind": TowerTaskKind.Kills,
			"text": "Defeat 10 enemies with it", "noun": "kills", "before": 5, "after": 8, "gain": 3, "count": 10, "done": false, "ready": false},
		{"tower": "g", "index": 7, "name": "Guardian", "form": "", "to": 2, "task": 0, "kind": TowerTaskKind.WinMission,
			"text": "Win a mission with this tower", "noun": "missions won", "before": 0, "after": 1, "gain": 1, "count": 1, "done": true, "ready": true},
	]
	var rows := UpgradeLogic.end_rows(adv)
	assert_eq(rows[0].who, "Archer")
	assert_eq(rows[0].where, "(tower 3)")
	assert_eq(rows[0].progress, "8 / 10 kills")
	assert_eq(rows[0].gain, "+3")
	assert_false(rows[0].done)
	assert_true(rows[1].done)
	assert_seq(UpgradeLogic.end_ready(adv), ["Guardian"])
	assert_eq(UpgradeLogic.end_more(4), "")
	assert_eq(UpgradeLogic.end_more(5), "+1 more task moved")
	assert_eq(UpgradeLogic.end_more(7), "+3 more tasks moved")
	adv[0].index = 0
	assert_eq(UpgradeLogic.end_rows(adv)[0].where, "")

func test_codex_lines() -> void:
	var t := _type()
	assert_seq(UpgradeLogic.codex_levels(t), ["Level 2: +2 Power", "Level 3: +5 Max HP", "Level 4: +1 Range", "Level 5: +3 Power, +5 Max HP"])
	assert_eq(UpgradeLogic.codex_levels(t, "archer-fire").size(), 3)
	var a := _owned("archer", "a")
	var b := _owned("archer", "b")
	b.level = 3
	var g := _owned("guardian", "g")
	g.level = 5
	assert_eq(UpgradeLogic.best_level([a, b, g], "archer"), 3)
	assert_eq(UpgradeLogic.best_level([a, b, g], "mage"), 0)
	assert_eq(UpgradeLogic.best_level([a, b, g], "archer", "archer-fire"), 0, "nobody has the form")
	b.forms.append("archer-fire")
	assert_eq(UpgradeLogic.best_level([a, b, g], "archer", "archer-fire"), 1)

func test_hand_entries_carry_the_level() -> void:
	var c := TowerCollection.new()
	var o: OwnedTower = c.add("archer")
	o.level = 3
	o.forms.append("archer-fire")
	o.form_levels["archer-fire"] = 2
	var es := HandLogic.entries(c, lib().catalog, AssetConverter.new())
	assert_eq(es[0].level, 3)
	o.form = "archer-fire"
	es = HandLogic.entries(c, lib().catalog, AssetConverter.new())
	assert_eq(es[0].level, 2, "the current form's level")
