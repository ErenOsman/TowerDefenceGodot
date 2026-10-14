extends TestCase
## The Workshop screen's pure helpers (WorkshopLogic, and the form-aware parts of HandLogic / MenuLogic / HudText):
## tree ids, states and layout, the arrow-key neighbour, the card's lines, the one action and its texts, the confirm
## texts, "Found in", the picker's lines, the Codex Forms rows.

static var _lib: ContentLibrary
static var _conv: AssetConverter

func lib() -> ContentLibrary:
	if _lib == null:
		_lib = ContentLibrary.load_game()
		_conv = AssetConverter.new()
	return _lib

func _type(asset := "Towers/Archer Tower") -> TowerType:
	lib()
	return _conv.tower_type(lib().get_asset(asset))

func _owned(type := "archer") -> OwnedTower:
	var o := OwnedTower.new()
	o.id = "t1"
	o.type = type
	return o

func _wallet(amounts: Dictionary) -> TokenWallet:
	var w := TokenWallet.new()
	w.add_all(amounts)
	return w

func _found() -> Dictionary:
	var out := {}
	for t in lib().catalog.tokens: out[t.get_id()] = WorkshopLogic.found_in_text(t.get_id(), lib().catalog)
	return out

# ------------------------------------------------------------------ the tree

func test_tree_ids_paths_and_layout() -> void:
	var t := _type()
	assert_seq(WorkshopLogic.node_ids(t), ["", "archer-fire", "archer-inferno", "archer-poison", "archer-longbow"])
	assert_eq(WorkshopLogic.parent_id(t, "archer-inferno"), "archer-fire")
	assert_eq(WorkshopLogic.parent_id(t, "archer-fire"), "")
	assert_null(WorkshopLogic.parent_id(t, ""))
	assert_seq(WorkshopLogic.path_to(t, "archer-inferno"), ["", "archer-fire", "archer-inferno"])
	var pos := WorkshopLogic.positions(t)
	# the mockup's positions (js/workshop.js "at"): order 0 left, 1 right, 2 below; Inferno above Fire Archer
	assert_eq(pos[""], Vector2(320, 330))
	assert_eq(pos["archer-fire"], Vector2(120, 280))
	assert_eq(pos["archer-poison"], Vector2(520, 280))
	assert_eq(pos["archer-longbow"], Vector2(320, 570))
	assert_eq(pos["archer-inferno"], Vector2(120, 80))
	var g := WorkshopLogic.positions(_type("Towers/Guardian Tower"))
	assert_eq(g["guardian-bastion"], Vector2(120, 280))
	assert_eq(g["guardian-spiked"], Vector2(520, 280))
	assert_eq(WorkshopLogic.positions(_type("Towers/Priest Tower")).size(), 1, "no forms: the root alone")

func test_arrow_keys_pick_the_neighbour() -> void:
	var pos := WorkshopLogic.positions(_type())
	assert_eq(WorkshopLogic.neighbour(pos, "archer-poison", Vector2.LEFT), "")
	assert_eq(WorkshopLogic.neighbour(pos, "", Vector2.LEFT), "archer-fire")
	assert_eq(WorkshopLogic.neighbour(pos, "", Vector2.DOWN), "archer-longbow")
	assert_eq(WorkshopLogic.neighbour(pos, "archer-fire", Vector2.UP), "archer-inferno")
	assert_eq(WorkshopLogic.neighbour(pos, "archer-inferno", Vector2.UP), "archer-inferno", "nothing that way: stays")

func test_node_states() -> void:
	var t := _type()
	var o := _owned()
	var w := _wallet({"fire-arrow": 2, "yew-bow": 1})
	assert_eq(WorkshopLogic.node_state(o, t, "", w), "current")
	assert_eq(WorkshopLogic.node_state(o, t, "archer-fire", w), "can")
	assert_eq(WorkshopLogic.node_state(o, t, "archer-poison", w), "need")
	assert_eq(WorkshopLogic.node_state(o, t, "archer-longbow", w), "need", "1 of 2 Yew Bow")
	assert_eq(WorkshopLogic.node_state(o, t, "archer-inferno", w), "locked", "Fire Archer first")
	o.forms = ["archer-fire"]
	o.form = "archer-fire"
	assert_eq(WorkshopLogic.node_state(o, t, "archer-fire", w), "current")
	assert_eq(WorkshopLogic.node_state(o, t, "", w), "unlocked", "the default form is always there")
	assert_eq(WorkshopLogic.node_state(o, t, "archer-inferno", w), "need")
	assert_eq(WorkshopLogic.current_id(o, t), "archer-fire")
	o.form = "gone"
	assert_eq(WorkshopLogic.current_id(o, t), "", "an unknown form: the default")

# ------------------------------------------------------------------ texts

func test_lines() -> void:
	var t := _type()
	var o := _owned()
	assert_eq(WorkshopLogic.form_line(o, t), "Default form · 0 of 4 forms unlocked")
	o.forms = ["archer-fire"]
	o.form = "archer-fire"
	assert_eq(WorkshopLogic.form_line(o, t), "Form of Archer · 1 of 4 forms unlocked")
	assert_eq(WorkshopLogic.form_line(_owned("priest"), _type("Towers/Priest Tower")), "Default form · no forms yet")
	assert_eq(WorkshopLogic.now_line(o, t), "Form: Fire Archer")
	assert_eq(WorkshopLogic.now_line(_owned(), t), "Form: Default")
	assert_eq(WorkshopLogic.subtitle(t, ""), "Base form")
	assert_eq(WorkshopLogic.subtitle(t, "archer-fire"), "Form of Archer")
	assert_eq(WorkshopLogic.subtitle(t, "archer-inferno"), "Form of Fire Archer")
	assert_eq(WorkshopLogic.leads_to(t, "archer-fire"), "Leads to: Inferno Archer")
	assert_eq(WorkshopLogic.leads_to(t, ""), "Leads to: Fire Archer, Poison Archer, Longbow")
	assert_eq(WorkshopLogic.leads_to(t, "archer-poison"), "")
	assert_eq(WorkshopLogic.number_text(1, 3), "#1 · tower 3")
	assert_eq(WorkshopLogic.chip_text(0, 1), "0/1")
	assert_eq(WorkshopLogic.chip_text(2, 1), "1")
	assert_eq(WorkshopLogic.toast(t, "archer-fire"), "Fire Archer unlocked")
	assert_eq(WorkshopLogic.node_hint(t, "archer-inferno", "locked"), "Inferno Archer: Unlock Fire Archer first")
	assert_eq(WorkshopLogic.spend_text(t.find_form("archer-inferno")), "1 Ember Core + 1 Fire Arrow")
	assert_seq(WorkshopLogic.unlock_parts(t.find_form("archer-fire")), [["fire-arrow", "1 Fire Arrow"]])
	assert_seq(WorkshopLogic.unlock_parts(t.find_form("archer-inferno")), [["ember-core", "1"], ["fire-arrow", "1"]], "two tokens: coins and counts")

func test_found_in() -> void:
	var c := lib().catalog
	# Missions & Guild: missions are the only token source, so "Found in" names the missions (board order)
	assert_eq(WorkshopLogic.found_in_text("poison-gland", c), "Night Watch and Drum Line")
	assert_eq(WorkshopLogic.found_in_text("ember-core", c), "The Glutton Returns")
	assert_eq(WorkshopLogic.found_in_text("fire-arrow", c), "Patrol, Night Watch and Drum Line")
	assert_eq(WorkshopLogic.found_in_text("yew-bow", c), "Patrol")
	assert_eq(WorkshopLogic.found_in_text("nothing", c), "")
	assert_eq(WorkshopLogic.found_in_text("steel-plate", c.to_missions()), "Hold the Gate", "a mission list works too")
	assert_eq(WorkshopLogic.found_in_text("steel-plate", null), "")

func test_trait_lines() -> void:
	lib()
	var vocab := _conv.rules(lib().rules).vocabulary
	var t := _type()
	assert_seq(WorkshopLogic.trait_lines(t.entity, vocab), [], "the plain Archer applies nothing")
	assert_seq(WorkshopLogic.trait_lines(t.find_form("archer-fire").entity, vocab), ["Burn on hit"])
	assert_seq(WorkshopLogic.trait_lines(t.find_form("archer-inferno").entity, vocab), ["Burn around the target"])
	assert_seq(WorkshopLogic.trait_lines(t.find_form("archer-poison").entity, vocab), ["Acid on hit"])
	assert_seq(WorkshopLogic.trait_lines(t.find_form("archer-longbow").entity, vocab), [])
	assert_seq(WorkshopLogic.trait_lines(_type("Towers/Guardian Tower").entity, vocab), ["Applies Taunted"])

# ------------------------------------------------------------------ the Codex Forms page

func test_codex_form_rows() -> void:
	var t := _type()
	var c := TowerCollection.new()
	var a := c.add("archer")
	assert_seq(WorkshopLogic.codex_form_ids(c, t), [""], "nothing unlocked: the base row alone")
	var b := c.add("archer")
	b.forms = ["archer-fire", "archer-inferno"]
	a.forms = ["archer-longbow"]
	assert_seq(WorkshopLogic.codex_form_ids(c, t), ["", "archer-fire", "archer-inferno", "archer-longbow"],
		"base first, then any tower's unlocked forms in content order; locked ones are not listed")
	assert_eq(WorkshopLogic.codex_row_name(t, ""), "Archer")
	assert_eq(WorkshopLogic.codex_row_name(t, "archer-fire"), "Fire Archer")
	assert_eq(WorkshopLogic.codex_row_sub(t, ""), "Base form")
	assert_eq(WorkshopLogic.codex_row_sub(t, "archer-inferno"), "Form of Fire Archer")

# ------------------------------------------------------------------ the action

func test_action_texts() -> void:
	var t := _type()
	var o := _owned()
	var w := _wallet({"fire-arrow": 2})
	var f := _found()
	var a := WorkshopLogic.action(o, t, "archer-fire", w, 3, f)
	assert_eq(a.kind, "unlock")
	assert_eq(a.text, "Unlock · 1 Fire Arrow")
	assert_eq(a.note, "Unlocks for this Archer (tower 3).")
	a = WorkshopLogic.action(o, t, "", w, 3, f)
	assert_eq(a.kind, "current")
	assert_eq(a.note, "This is the tower's current form.")
	a = WorkshopLogic.action(o, t, "archer-inferno", w, 3, f)
	assert_eq(a.kind, "blocked")
	assert_eq(a.reason, "Needs Fire Archer first.")
	a = WorkshopLogic.action(o, t, "archer-poison", w, 3, f)
	assert_eq(a.reason, "Needs 1 more Poison Gland. Found in: Night Watch and Drum Line.")
	o.forms = ["archer-fire"]
	o.form = "archer-fire"
	w.spend({"fire-arrow": 1})
	a = WorkshopLogic.action(o, t, "archer-inferno", w, 3, f)
	assert_eq(a.reason, "Needs 1 more Ember Core. Found in: The Glutton Returns.")
	a = WorkshopLogic.action(o, t, "", w, 3, f)
	assert_eq(a.kind, "use")
	assert_eq(a.text, "Use this form")
	assert_eq(a.note, "Free: switch back any time.")
	assert_eq(Workshop.last_reason, Workshop.last_reason, "action() leaves the rules alone")

func test_confirm_texts() -> void:
	var t := _type()
	var w := _wallet({"fire-arrow": 2, "ember-core": 1})
	assert_eq(WorkshopLogic.confirm_title(t, t.find_form("archer-fire")), "Unlock Fire Archer for this Archer?")
	assert_eq(WorkshopLogic.confirm_body(t, t.find_form("archer-fire"), w),
		"Spends 1 Fire Arrow (you have 2 → 1). You can switch back to Archer any time.")
	assert_eq(WorkshopLogic.confirm_body(t, t.find_form("archer-inferno"), w),
		"Spends 1 Ember Core (you have 1 → 0) and 1 Fire Arrow (you have 2 → 1). You can switch back to Archer any time.")

# ------------------------------------------------------------------ elsewhere

func test_formed_towers_in_the_collection() -> void:
	lib()
	var c := TowerCollection.new()
	var a := c.add("archer")
	var b := c.add("archer")
	b.forms = ["archer-fire"]
	b.form = "archer-fire"
	var es := HandLogic.entries(c, lib().catalog, _conv)
	assert_eq(es[1].name, "Fire Archer")
	assert_eq(es[1].base_name, "Archer")
	assert_eq(es[1].def.name, "fire-archer")
	assert_true(str(es[1].badge).ends_with("forms/archer-fire.png"))
	assert_eq(es[0].badge, "")
	assert_true(str(es[1].description).begins_with("Arrows catch fire"))
	var f := HandLogic.default_filter()
	f.q = "archer"
	assert_eq(HandLogic.visible(es, f, []).size(), 2)
	f.q = "fire"
	assert_eq(HandLogic.visible(es, f, []).size(), 1)
	assert_seq(HandLogic.visible(es, HandLogic.default_filter(), [], "number").map(func(e): return e.id), [a.id, b.id],
		"Default sort keeps the collection order within a type")
	var type: TowerAsset = lib().catalog.find_tower("archer")
	assert_eq(MenuLogic.tower_name(b, type), "Fire Archer")
	assert_eq(MenuLogic.tower_name(a, type), "Archer")
	b.custom_name = "Robin"
	assert_eq(MenuLogic.tower_name(b, type), "Robin", "a custom name still wins")
	assert_eq(MenuLogic.form_in(b, type).get_id(), "archer-fire")
	assert_true(WorkshopLogic.anyone_unlocked(c, "archer", "archer-fire"))
	assert_false(WorkshopLogic.anyone_unlocked(c, "archer", "archer-poison"))

func test_token_rows() -> void:
	var rows := HudText.token_rows({"fire-arrow": 2, "nope": 1, "yew-bow": 0}, lib().catalog)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0][0].get_display_name(), "Fire Arrow")
	assert_eq(rows[0][2], 2)
	assert_null(rows[1][0])
	assert_eq(rows[1][1], "nope")

func test_workshop_opens_after_chapter2() -> void:
	var c := lib().catalog
	var last := MenuLogic.main_chapter_last_level(c, 2)
	assert_eq(last.get_id(), "chapter2-4", "Chapter 2's last level (from the catalog)")
	var d := GameData.new()
	assert_false(MenuLogic.workshop_unlocked(c, d.progress))
	DevShortcuts.complete_main_chapters(d, c, 1)
	assert_false(MenuLogic.workshop_unlocked(c, d.progress), "Chapter 1 is not enough")
	DevShortcuts.complete_main_chapters(d, c, 2)
	assert_true(MenuLogic.workshop_unlocked(c, d.progress))
	assert_eq(MenuLogic.workshop_locked_text(c), "Opens after Chapter 2")
