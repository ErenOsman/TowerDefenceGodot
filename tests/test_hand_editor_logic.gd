extends TestCase
## The hand editor's rules (game/ui/screens/parts/hand_logic.gd) on the real content: roles / delivery / flags
## derived from the towers' abilities, filtering and sorting the collection, the hand edits keeping ≤ 8, and the
## saved layouts round-tripping through the GameData JSON.

static var _lib: ContentLibrary
static var _conv: AssetConverter

func lib() -> ContentLibrary:
	if _lib == null:
		_lib = ContentLibrary.load("res://data/content")
		_conv = AssetConverter.new()
		_conv.rules(_lib.rules)
	return _lib

func _traits(type_id: String) -> Dictionary:
	var t: TowerAsset = lib().catalog.find_tower(type_id)
	return HandLogic.traits(_conv.entity(t.entity))

## A collection of 2 of every tower type (ids in type order: archer, archer, guardian, guardian, …).
func _collection() -> TowerCollection:
	var c := TowerCollection.new()
	for t in lib().catalog.tower_types:
		c.add(t.get_id())
		c.add(t.get_id())
	return c

func _names(list: Array) -> Array:
	return list.map(func(e): return e.name)

func test_roles_and_delivery_come_from_the_abilities() -> void:
	var a := _traits("archer")
	assert_seq(a.roles, ["Attack", "Movement"])
	assert_seq(a.delivery, ["Projectile"])
	assert_true(a.move)
	assert_false(a.heal)
	assert_false(a.status)
	var g := _traits("guardian")
	assert_seq(g.roles, ["Attack", "Control", "Movement"], "Taunt applies Taunted: Control")
	assert_seq(g.delivery, ["Melee"])
	assert_true(g.status)
	var p := _traits("priest")
	assert_seq(p.roles, ["Attack", "Spell", "Support", "Movement"], "Mend heals: Support")
	assert_seq(p.delivery, ["Spell"])
	assert_true(p.heal)
	var d := _traits("drummer")
	assert_seq(d.roles, ["Spell", "Support", "Movement"], "Rally applies a Buff: Support, no attack")
	assert_true(d.status)
	assert_seq(_traits("cannon").delivery, ["Lobbed"])
	assert_seq(_traits("mage").roles, ["Attack", "Spell", "Movement"], "a burn is damage, not control")
	assert_seq(HandLogic.traits(null).roles, [])

func test_entries_are_individuals_with_their_index() -> void:
	var c := _collection()
	var es := HandLogic.entries(c, lib().catalog, _conv)
	assert_eq(es.size(), lib().catalog.tower_types.size() * 2, "one entry per owned tower, never stacked")
	assert_eq(es[0].name, "Archer")
	assert_eq(es[1].name, "Archer")
	assert_ne(es[0].id, es[1].id)
	assert_eq(es[1].index, 2)
	assert_eq(HandLogic.number_text(es[2]), "#2 · tower 3")
	assert_eq(es[0].cost, 100)

func test_filters_on_the_real_content() -> void:
	var c := _collection()
	var es := HandLogic.entries(c, lib().catalog, _conv)
	var f := HandLogic.default_filter()
	assert_false(HandLogic.filter_active(f))
	assert_eq(HandLogic.visible(es, f, c.hand).size(), es.size())
	f.q = "arch"
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Archer", "Archer"], "search: name contains, any case")
	f = HandLogic.default_filter()
	f.roles = ["Support"]
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Priest", "Priest", "Drummer", "Drummer"])
	f.roles = ["Support", "Control"]
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Guardian", "Guardian", "Priest", "Priest", "Drummer", "Drummer"], "roles: any of")
	f = HandLogic.default_filter()
	f.delivery = ["Lobbed"]
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Cannon", "Cannon"])
	f = HandLogic.default_filter()
	HandLogic.toggle_cost_chip(f, 0)
	assert_true(HandLogic.filter_active(f))
	assert_eq(HandLogic.cost_text(f), "≤ 100")
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Archer", "Archer", "Guardian", "Guardian", "Priest", "Priest"])
	HandLogic.toggle_cost_chip(f, 0)
	assert_eq(HandLogic.cost_text(f), "any", "the same chip again clears it")
	HandLogic.toggle_cost_chip(f, 2)
	for e in HandLogic.visible(es, f, c.hand): assert_true(e.cost >= 200, e.name)
	f = HandLogic.default_filter()
	f.heal = true
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Priest", "Priest"])
	f = HandLogic.default_filter()
	f.status = true
	assert_seq(_names(HandLogic.visible(es, f, c.hand)), ["Guardian", "Guardian", "Mage", "Mage", "Alchemist", "Alchemist", "Drummer", "Drummer"])
	f = HandLogic.default_filter()
	f.hide = true
	c.add_to_hand(es[0].id)
	var shown := HandLogic.visible(es, f, c.hand)
	assert_eq(shown.size(), es.size() - 1, "Hide my hand leaves out the hand's towers")
	assert_eq(shown[0].id, es[1].id)
	assert_eq(HandLogic.count_text(shown.size(), es.size()), "%d of %d towers" % [es.size() - 1, es.size()])

func test_sort_number_name_cost() -> void:
	var c := _collection()
	var es := HandLogic.entries(c, lib().catalog, _conv)
	var f := HandLogic.default_filter()
	var by_num := HandLogic.visible(es, f, c.hand, "number")
	assert_seq(_names(by_num).slice(0, 4), ["Archer", "Archer", "Guardian", "Guardian"])
	assert_true(by_num[0].index < by_num[1].index, "ties keep the collection order")
	var by_name := _names(HandLogic.visible(es, f, c.hand, "name"))
	assert_seq(by_name.slice(0, 4), ["Alchemist", "Alchemist", "Archer", "Archer"])
	var by_cost := HandLogic.visible(es, f, c.hand, "cost")
	for i in range(1, by_cost.size()): assert_true(by_cost[i - 1].cost <= by_cost[i].cost)
	assert_eq(by_cost[by_cost.size() - 1].name, "Cannon")

func test_add_remove_reorder_keep_at_most_eight() -> void:
	var c := _collection()
	var ids := c.towers.map(func(o): return o.id)
	for i in 8: assert_true(HandLogic.add(c, ids[i]))
	assert_eq(c.hand.size(), 8)
	assert_eq(HandLogic.add_reason(c, ids[8]), HandLogic.FULL_REASON)
	assert_false(HandLogic.add(c, ids[8]), "full")
	assert_false(HandLogic.toggle(c, ids[8]), "double-click on a full hand does nothing")
	assert_eq(c.hand.size(), 8)
	# drop a collection card onto a filled slot: it replaces that tower
	assert_true(HandLogic.drop_on_slot(c, ids[9], 2))
	assert_eq(c.hand[2], ids[9])
	assert_false(c.hand.has(ids[2]))
	assert_eq(c.hand.size(), 8)
	# reorder: slot 0 to slot 3 (the others shift, the key follows)
	assert_true(HandLogic.drop_on_slot(c, ids[0], 3))
	assert_seq(c.hand.slice(0, 4), [ids[1], ids[9], ids[3], ids[0]])
	assert_false(HandLogic.drop_on_slot(c, ids[0], 3), "same place: no change")
	assert_true(HandLogic.drop_on_slot(c, ids[0], 99), "past the end: the last slot")
	assert_eq(c.hand[7], ids[0])
	# take out, then a drop on an empty slot goes to the first empty one
	assert_true(HandLogic.toggle(c, ids[0]))
	assert_eq(c.hand.size(), 7)
	assert_true(HandLogic.drop_on_slot(c, ids[10], 7))
	assert_eq(c.hand[7], ids[10], "the first empty slot")
	assert_false(HandLogic.drop_on_slot(c, "not-owned", 0))
	assert_false(HandLogic.remove(c, "not-owned"))
	assert_true(c.hand.size() <= TowerCollection.MaxHand)
	var seen := {}
	for id in c.hand:
		assert_false(seen.has(id), "each tower once")
		seen[id] = true

func test_layouts_round_trip_through_game_data_json() -> void:
	var g := GameData.new()
	var a := g.towers.add("archer")
	var b := g.towers.add("guardian")
	var p := g.towers.add("priest")
	g.towers.add_to_hand(a.id)
	g.towers.add_to_hand(b.id)
	g.ensure_layouts()
	assert_eq(g.hand_layouts.size(), GameData.LAYOUTS)
	assert_eq(GameData.LAYOUTS, 4, "four fixed layouts (user, 2026-10-13)")
	assert_seq(g.hand_layouts[0].hand, [a.id, b.id], "Layout 1 holds the hand")
	assert_eq(g.hand_layouts[1].name, "Layout 2")
	assert_seq(g.hand_layouts[1].hand, [], "2–4 start empty")
	# switch to layout 3, fill it, rename it
	assert_true(HandLogic.switch_layout(g, 2))
	assert_seq(g.towers.hand, [], "an empty layout: an empty hand")
	HandLogic.add(g.towers, p.id)
	HandLogic.sync_layout(g)
	assert_true(HandLogic.rename_layout(g, 2, "  Healers and a very long name that is cut  "))
	assert_eq(g.hand_layouts[2].name, "Healers and a very long")
	assert_false(HandLogic.rename_layout(g, 2, "   "), "an empty name keeps the old one")
	var back := GameData.from_json(g.to_json())
	var d: Dictionary = JSON.parse_string(g.to_json())
	assert_true(d.has("handLayouts"))
	assert_eq(d.handLayouts.layouts.size(), 4)
	assert_eq(back.active_layout, 2)
	assert_eq(back.hand_layouts[2].name, "Healers and a very long")
	assert_seq(back.hand_layouts[2].hand, [p.id])
	assert_seq(back.hand_layouts[0].hand, [a.id, b.id], "the left layout kept its hand")
	assert_seq(back.towers.hand, [p.id])
	# back to Layout 1: its hand returns; towers no longer owned are dropped
	back.towers.remove(b.id)
	assert_true(HandLogic.switch_layout(back, 0))
	assert_seq(back.towers.hand, [a.id])
	assert_seq(back.hand_layouts[2].hand, [p.id])
	assert_false(HandLogic.switch_layout(back, 0), "already active")
	assert_false(HandLogic.switch_layout(back, 7))

func test_save_without_layouts_gives_layout_one_the_hand() -> void:
	var g := GameData.new()
	var a := g.towers.add("archer")
	g.towers.add_to_hand(a.id)
	var d: Dictionary = JSON.parse_string(g.to_json())
	d.erase("handLayouts")
	var back := GameData.from_dict(d)
	assert_eq(back.hand_layouts.size(), 4)
	assert_eq(back.active_layout, 0)
	assert_seq(back.hand_layouts[0].hand, [a.id])

func test_detail_texts() -> void:
	assert_eq(HandLogic.ability_subtitle(["Attack", "Projectile"], 1, false), "Attack · projectile · 1 turn CD")
	assert_eq(HandLogic.ability_subtitle(["Movement"], 2, false), "Movement · 2 turn CD")
	assert_eq(HandLogic.ability_subtitle(["Attack", "Spell", "Fire"], 2, false), "Attack · spell · 2 turn CD")
	assert_eq(HandLogic.cap_note("Two Roads", 4), "Two Roads takes the first 4")
	assert_eq(HandLogic.cap_note("", 4), "")
	var t: TowerAsset = lib().catalog.find_tower("archer")
	var me := DefStats.new(_conv.entity(t.entity))
	var vocab: Vocabulary = _conv.rules(lib().rules).vocabulary
	assert_seq(HandLogic.stat_tiles(me, vocab).map(func(x): return "%s %s" % [x[2], x[1]]), ["20 Max HP", "10 Power", "2 Range", "2 Speed"])
