extends TestCase
## The Backpack (Backpack — Design; game/ui/screens/parts/backpack_logic.gd): the popup's gold and token rows (which
## kinds show, spent-out kinds dimmed, "Found in" from the mission drops), the button's count and when it shows, the
## Upgrade view's Pay button (amount, label, enabled, the line under it) and its gold task row, and the Guild's
## "Each win / First win" rows with gold (MissionUiLogic.reward_rows).

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func _missions() -> Array:
	return lib().catalog.to_missions()

func _found(id: String) -> String:
	return WorkshopLogic.found_in_text(id, _missions())

func test_gold_texts() -> void:
	assert_eq(BackpackLogic.gold_text(240), "240")
	assert_eq(BackpackLogic.gold_text(0), "0", "gold always shows, 0 too")
	assert_eq(BackpackLogic.gold_text(-5), "0", "never negative")
	assert_eq(BackpackLogic.button_text(15), "15")
	assert_eq(BackpackLogic.GoldSub, "From missions; spent on upgrades")
	assert_eq(BackpackLogic.ItemsEmpty, "Nothing here yet.")

func test_button_shown_after_camp() -> void:
	assert_false(BackpackLogic.button_shown(false), "hidden before the Camp unlocks")
	assert_true(BackpackLogic.button_shown(true))
	var w := TokenWallet.new()
	w.add("fire-arrow", 2)
	w.add("ember-core", 1)
	assert_eq(BackpackLogic.button_tip(240, w), "240 gold · 3 tokens")
	assert_eq(BackpackLogic.button_tip(0, TokenWallet.new()), "0 gold · 0 tokens")

func test_token_rows_hidden_and_dimmed() -> void:
	var tokens: Array = lib().catalog.tokens
	assert_true(tokens.size() >= 3, "the starter content has token kinds")
	var w := TokenWallet.new()
	var a: String = tokens[0].get_id()
	var b: String = tokens[1].get_id()
	w.add(a, 2)
	w.add(b, 1)
	w.spend({b: 1}) # spent out: stays, ×0, dimmed
	var rows := BackpackLogic.token_rows(tokens, w, _found)
	assert_eq(rows.size(), 2, "never-earned kinds are hidden")
	assert_eq(rows[0].id, a, "catalog order")
	assert_eq(rows[0].count_text, "×2")
	assert_false(rows[0].dim)
	assert_eq(rows[0].name, tokens[0].get_display_name())
	assert_eq(rows[1].id, b)
	assert_eq(rows[1].count, 0)
	assert_eq(rows[1].count_text, "×0")
	assert_true(rows[1].dim, "a spent-out kind is dimmed")
	assert_false(BackpackLogic.ever_had(w, tokens[2].get_id()))
	assert_eq(BackpackLogic.token_rows(tokens, TokenWallet.new(), _found), [], "nothing earned: no token rows")
	assert_eq(BackpackLogic.token_rows(tokens, null, _found), [])

func test_found_in_as_the_workshop() -> void:
	var tokens: Array = lib().catalog.tokens
	var w := TokenWallet.new()
	for t in tokens: w.add(t.get_id(), 1)
	for r in BackpackLogic.token_rows(tokens, w, _found):
		var where := _found(r.id)
		assert_eq(r.found, ("Found in: " + where) if where != "" else "", "the Workshop's Found in for " + r.id)
	assert_eq(BackpackLogic.found_line("Night Watch and Patrol"), "Found in: Night Watch and Patrol")
	assert_eq(BackpackLogic.found_line(""), "")

func test_pay_amount_and_text() -> void:
	assert_eq(BackpackLogic.pay_amount(15, 15), 15)
	assert_eq(BackpackLogic.pay_amount(240, 15), 15, "never more than the task misses")
	assert_eq(BackpackLogic.pay_amount(10, 15), 10, "a partial deposit")
	assert_eq(BackpackLogic.pay_amount(0, 15), 0)
	assert_eq(BackpackLogic.pay_text(240, 15), "Pay 15")
	assert_eq(BackpackLogic.pay_text(10, 15), "Pay 10")
	assert_eq(BackpackLogic.pay_text(0, 15), "Pay", "no gold: just Pay (disabled)")

func test_pay_disabled_rule_and_note() -> void:
	assert_true(BackpackLogic.pay_enabled(15, 15))
	assert_false(BackpackLogic.pay_enabled(0, 15), "disabled with no gold")
	assert_false(BackpackLogic.pay_enabled(100, 0), "nothing missing")
	assert_eq(BackpackLogic.pay_note(0, 15), {"text": "You have no gold. Missions give gold.", "bad": true})
	assert_eq(BackpackLogic.pay_note(10, 15), {"text": "You have 10: pays what you can.", "bad": false})
	assert_eq(BackpackLogic.pay_note(15, 15).text, "")
	assert_eq(BackpackLogic.pay_note(0, 0).text, "", "a full task has no line")

func test_upgrade_gold_task_row() -> void:
	var t := AssetConverter.new().tower_type(lib().catalog.find_tower("archer"))
	var o := OwnedTower.new()
	o.id = "t1"
	o.type = "archer"
	o.level = 2
	var step := TowerLevels.step_for(o, t, "")
	var gi := TowerTasks.gold_task_index(step)
	assert_true(gi >= 0, "every step has a gold task")
	var counts := []
	for i in step.tasks.size(): counts.append(0)
	counts[gi] = 25
	o.task_progress[TowerLevels.step_key("", step.to)] = counts
	var rows := UpgradeLogic.task_rows(o, t)
	var g: Dictionary = rows[gi]
	assert_true(g.gold, "the gold task row gets the Pay button")
	assert_eq(g.index, gi)
	assert_eq(g.progress, "25 / 40 gold")
	assert_eq(g.need_text, "40 gold")
	assert_eq(g.missing, 15)
	assert_eq(UpgradeLogic.task_icon(g.kind), "gold")
	assert_false(rows[0].gold)
	assert_eq(BackpackLogic.pay_text(240, g.missing), "Pay 15")

func test_guild_reward_rows_with_gold() -> void:
	var m := MissionBoard.find(_missions(), "patrol")
	var rows := MissionUiLogic.reward_rows(m)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0][0], "Each win")
	assert_eq(rows[0][1], m.win_tokens)
	assert_eq(rows[0][2], m.win_gold)
	assert_eq(rows[1][0], "First win")
	assert_eq(rows[1][2], m.first_win_gold)
	assert_true(m.win_gold > 0 and m.first_win_gold > 0, "the starter missions give gold")
	var only_gold := MissionDef.new()
	only_gold.win_gold = 5
	assert_eq(MissionUiLogic.reward_rows(only_gold), [["Each win", {}, 5]], "a row with gold and no tokens shows")
	assert_eq(MissionUiLogic.reward_rows(MissionDef.new()), [])
	assert_eq(MissionUiLogic.reward_rows(null), [])
