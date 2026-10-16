extends TestCase
## The Backpack (Backpack — Design; game/ui/screens/parts/backpack_logic.gd): the popup's gold and token rows (which
## kinds show, spent-out kinds dimmed; no "found in" / "from missions" texts: Eren 2026-10-16), the button's count and
## when it shows, the Upgrade view's Pay button (amount, label, enabled; no line under it) and its gold task row.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func _missions() -> Array:
	return lib().catalog.to_missions()

func test_gold_texts() -> void:
	assert_eq(BackpackLogic.gold_text(240), "240")
	assert_eq(BackpackLogic.gold_text(0), "0", "gold always shows, 0 too")
	assert_eq(BackpackLogic.gold_text(-5), "0", "never negative")
	assert_eq(BackpackLogic.button_text(15), "15")
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
	var rows := BackpackLogic.token_rows(tokens, w)
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
	assert_eq(BackpackLogic.token_rows(tokens, TokenWallet.new()), [], "nothing earned: no token rows")
	assert_eq(BackpackLogic.token_rows(tokens, null), [])

func test_token_rows_without_found_in() -> void:
	# Eren 2026-10-16: where things are earned needs no explaining; the rows carry no "found" text
	var tokens: Array = lib().catalog.tokens
	var w := TokenWallet.new()
	for t in tokens: w.add(t.get_id(), 1)
	var rows := BackpackLogic.token_rows(tokens, w)
	assert_eq(rows.size(), tokens.size())
	for r in rows:
		assert_seq(r.keys(), ["id", "name", "count", "count_text", "dim"], "only these fields: " + r.id)

func test_pay_amount_and_text() -> void:
	assert_eq(BackpackLogic.pay_amount(15, 15), 15)
	assert_eq(BackpackLogic.pay_amount(240, 15), 15, "never more than the task misses")
	assert_eq(BackpackLogic.pay_amount(10, 15), 10, "a partial deposit")
	assert_eq(BackpackLogic.pay_amount(0, 15), 0)
	assert_eq(BackpackLogic.pay_text(240, 15), "Pay 15")
	assert_eq(BackpackLogic.pay_text(10, 15), "Pay 10")
	assert_eq(BackpackLogic.pay_text(0, 15), "Pay", "no gold: just Pay (disabled)")

func test_pay_disabled_rule_no_line() -> void:
	assert_true(BackpackLogic.pay_enabled(15, 15))
	assert_false(BackpackLogic.pay_enabled(0, 15), "disabled with no gold")
	assert_false(BackpackLogic.pay_enabled(100, 0), "nothing missing")
	assert_eq(BackpackLogic.NoGold, "You have no gold.", "the disabled button's tooltip only")
	assert_false(BackpackLogic.new().has_method("pay_note"), "no line under the Pay button")

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
	assert_eq(g.progress, "25 / 200 gold")
	assert_eq(g.need_text, "200 gold")
	assert_eq(g.missing, 175)
	assert_eq(UpgradeLogic.task_icon(g.kind), "gold")
	assert_false(rows[0].gold)
	assert_eq(BackpackLogic.pay_text(240, g.missing), "Pay 175")
