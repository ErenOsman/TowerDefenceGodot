extends TestCase
## The Upgrade screens' pure logic (game/ui/screens/parts/upgrade_logic.gd; Upgrades — Design § The Upgrade view):
## the picker's ready filter and count (a ready form counts), the card lines, ladders, task rows and bar values,
## the one action and its disabled reasons (first missing task, the form cap, max level), what a level gives and
## the "Then" preview, max rows, confirm / beat texts, the end screen's task rows and the Codex lines.

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

func test_ready_filter_counts_ready_forms() -> void:
	var t := _type()
	var a := _owned("archer", "a")          # base step 2: Win a mission (not done)
	var b := _owned("archer", "b")          # base ready
	b.task_progress["2"] = [1]
	var c := _owned("archer", "c")          # base not ready, but its Fire Archer is (level 2 base > form level 1)
	c.level = 2
	c.forms.append("archer-fire")
	c.task_progress["archer-fire:2"] = [1]
	assert_false(UpgradeLogic.is_ready(a, t))
	assert_true(UpgradeLogic.is_ready(b, t))
	assert_true(UpgradeLogic.is_ready(c, t), "a ready form makes the tower ready")
	var ready := {"a": UpgradeLogic.is_ready(a, t), "b": UpgradeLogic.is_ready(b, t), "c": UpgradeLogic.is_ready(c, t)}
	var shown := UpgradeLogic.ready_filter([_entry("a"), _entry("b"), _entry("c")], func(id): return ready[id])
	assert_seq(shown.map(func(e): return e.id), ["b", "c"])
	assert_eq(UpgradeLogic.count_text(2, 10, true), "2 ready")
	assert_eq(UpgradeLogic.count_text(10, 10, false), "10 towers")
	assert_eq(UpgradeLogic.count_text(3, 10, false), "3 of 10 towers")
	assert_eq(UpgradeLogic.ready_count([a, b, c], func(_id): return t), 2)

func test_card_lines() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	o.task_progress["3"] = [1, 42]
	assert_eq(UpgradeLogic.tasks_done_line(o, t), "Level 3: 1 of 2 tasks done")
	assert_eq(UpgradeLogic.ready_line(o, t), "")
	o.forms.append("archer-fire")
	o.task_progress["archer-fire:2"] = [1]
	assert_eq(UpgradeLogic.ready_line(o, t), "Fire Archer is ready to upgrade")
	o.task_progress["3"] = [1, 60]
	assert_eq(UpgradeLogic.ready_line(o, t), "Archer is ready to upgrade", "the base first")
	o.level = 5
	assert_eq(UpgradeLogic.tasks_done_line(o, t), "Max level")
	assert_eq(UpgradeLogic.chip_text(3), "Lv 3")
	assert_eq(UpgradeLogic.chip_text(0), "Lv 1")

# ------------------------------------------------------------------ ladders and tasks

func test_ladders() -> void:
	var t := _type()
	var o := _owned()
	assert_seq(UpgradeLogic.ladder_ids(o, t), [""])
	o.forms.append("archer-poison")
	o.forms.append("archer-fire")
	assert_seq(UpgradeLogic.ladder_ids(o, t), ["", "archer-fire", "archer-poison"], "content order")
	assert_eq(UpgradeLogic.ladder_name(t, ""), "Archer")
	assert_eq(UpgradeLogic.ladder_name(t, "archer-fire"), "Fire Archer")
	assert_eq(UpgradeLogic.of_text(t, ""), "of 5")
	assert_eq(UpgradeLogic.of_text(t, "archer-fire"), "of 4")
	o.level = 2
	assert_eq(UpgradeLogic.level_line(o, t, ""), "Level 2 of 5")
	assert_eq(UpgradeLogic.level_line(o, t, "archer-fire"), "Level 1 of 4")
	assert_eq(UpgradeLogic.form_sub(t, ""), "Base form")
	assert_eq(UpgradeLogic.form_sub(t, "archer-fire"), "Form of Archer")
	assert_eq(UpgradeLogic.start_ladder(o, t), "")
	o.form = "archer-fire"
	assert_eq(UpgradeLogic.start_ladder(o, t), "archer-fire")
	# the levelled type: Archer level 2 = +2 Power on the base entity
	o.form = ""
	var base_power := float(t.entity.base_stats.get("Power", 0.0))
	var lt := UpgradeLogic.levelled_type(o, t, "")
	assert_eq(float(lt.entity.base_stats.get("Power", 0.0)), base_power + 2.0)
	assert_eq(UpgradeLogic.levelled_type(o, t, "archer-fire").name, "Fire Archer")

func test_task_rows_and_bar_values() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	o.task_progress["3"] = [1, 42]
	var rows := UpgradeLogic.task_rows(o, t)
	assert_eq(rows.size(), 2)
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
	o.task_progress["3"] = [0, 0]
	assert_eq(UpgradeLogic.action(o, t).reason, "Win a mission with this tower", "nothing counted: the task itself")
	o.task_progress["3"] = [1, 60]
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
	# max level
	o.level = 5
	a = UpgradeLogic.action(o, t)
	assert_eq(a.kind, "max")
	assert_eq(a.reason, "Max level")

# ------------------------------------------------------------------ gives, then, max

func test_gives_then_and_max() -> void:
	var t := _type()
	var o := _owned()
	o.level = 2
	assert_eq(UpgradeLogic.gives_title(o, t), "What level 3 gives")
	assert_eq(UpgradeLogic.gives(o, t), [["MaxHp", "+5", "Max HP"]])
	var then := UpgradeLogic.then_info(o, t)
	assert_eq(then.title, "Then: level 4")
	assert_seq(then.tasks, ["Win 2 missions with this tower", "Defeat 10 enemies with it"])
	assert_eq(then.bonuses, [["Range", "+1", "Range"]])
	o.level = 4
	then = UpgradeLogic.then_info(o, t)
	assert_eq(then.title, "")
	assert_eq(then.last, "Level 5 is the highest.")
	o.level = 5
	assert_eq(UpgradeLogic.gives_title(o, t), "All levels reached")
	assert_eq(UpgradeLogic.gives(o, t), [])
	assert_eq(UpgradeLogic.then_info(o, t).last, "Nothing more to unlock for Archer.")
	var rows := UpgradeLogic.max_rows(t)
	assert_eq(rows.size(), 4)
	assert_eq(rows[0], ["Level 2", [["Power", "+2", "Power"]]])
	assert_eq(rows[3], ["Level 5", [["Power", "+3", "Power"], ["MaxHp", "+5", "Max HP"]]])
	assert_eq(UpgradeLogic.max_line(t), "Archer is at its highest level.")
	assert_eq(UpgradeLogic.max_rows(t, "archer-fire").size(), 3, "a form: 3 steps to level 4")

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
