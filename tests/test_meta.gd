extends TestCase
## Port of MetaTests.cs: owned towers, tower IDs and the hand.

var archer: TowerType

func setup() -> void:
	archer = TowerType.new()
	archer.id = "archer"
	archer.name = "Archer"
	archer.cost = 3

func _types(id: String) -> TowerType:
	return archer if id == "archer" else null

func test_two_towers_of_a_type_are_two_towers() -> void:
	var c := TowerCollection.new()
	var a := c.add("archer")
	var b := c.add("archer", "Eren")
	assert_ne(a.id, b.id)
	assert_true(TowerIds.is_valid(a.id), a.id)

	c.add_to_hand(b.id)
	c.add_to_hand(a.id)
	var hand := c.build_hand(_types)

	assert_seq(hand.map(func(t): return t.id), [b.id, a.id], "hand order is kept")
	assert_eq(hand[0].name, "Eren")
	assert_eq(hand[1].name, "Archer")
	assert_true(hand[1].type == archer)

func test_profile_first_run_names_tutorial_and_old_saves() -> void:
	var p := PlayerProfile.new()
	assert_true(p.is_first_run)
	assert_false(p.tutorial_pending)

	p.create("   ")
	assert_eq(p.player_name, PlayerProfile.DefaultName, "an empty name falls back to the default")
	assert_false(p.is_first_run)
	assert_true(p.tutorial_pending)
	p.create("A name far longer than sixteen")
	assert_eq(p.player_name.length(), PlayerProfile.MaxNameLength)

	assert_true(p.mark_intro_seen("chapter1-1"))
	assert_false(p.mark_intro_seen("chapter1-1"), "an intro plays once")
	assert_true(p.has_seen_intro("chapter1-1"))

	var old := PlayerProfile.new() # a save from before profiles
	assert_true(old.adopt_existing_save())
	assert_false(old.is_first_run)
	assert_eq(old.tutorial, TutorialState.Skipped, "existing players never see the tutorial")
	assert_false(old.adopt_existing_save())

func test_hand_rules() -> void:
	var c := TowerCollection.new()
	var towers := []
	for i in 9: towers.append(c.add("archer"))
	for i in 8: c.add_to_hand(towers[i].id)

	assert_false(c.can_add_to_hand(towers[8].id))
	assert_eq(c.last_reason, "The hand is full (8)")
	assert_false(c.can_add_to_hand(towers[0].id))
	assert_eq(c.last_reason, "Already in the hand")
	assert_false(c.can_add_to_hand(TowerIds.new_id()))

	c.move_in_hand(towers[7].id, 0)
	assert_eq(c.hand[0], towers[7].id)

	c.remove(towers[7].id)
	assert_eq(c.hand.size(), 7, "removing a tower takes it out of the hand")

func test_unknown_types_and_ids_are_skipped_and_reported() -> void:
	var c := TowerCollection.new()
	var old := c.add("retired-type")
	var ok := c.add("archer")
	c.hand.append_array([TowerIds.new_id(), old.id, ok.id])

	var problems := []
	var hand := c.build_hand(_types, problems)

	assert_eq(hand.size(), 1)
	assert_eq(problems.size(), 2)

func test_tower_ids() -> void:
	assert_true(TowerIds.is_valid("80a8ee3c-7e0c-4ff1-b4de-7490cd8b9aa1"))
	assert_true(TowerIds.is_valid("{80a8ee3c-7e0c-4ff1-b4de-7490cd8b9aa1}"))
	assert_true(TowerIds.is_valid("80a8ee3c7e0c4ff1b4de7490cd8b9aa1"))
	assert_false(TowerIds.is_valid("archer-1"))
	assert_false(TowerIds.is_valid(""))
	assert_eq(TowerIds.short("80a8ee3c-7e0c-4ff1-b4de-7490cd8b9aa1"), "80a8ee3c")
	assert_eq(TowerIds.short("abc"), "abc")
