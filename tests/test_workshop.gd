extends TestCase
## Workshop — Design: the content (Forms.json, Tokens.json and the form units in data/content), the rules in
## Workshop (unlock, set_form, resolve, drops, found_in), the TokenWallet, saves (old saves migrate), the hand a level
## builds from forms, co-op hand entries "<type>@<form>", the dev cheats and the HUD text helpers.

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func _archer_type(c: AssetConverter = null) -> TowerType:
	if c == null: c = AssetConverter.new()
	return c.tower_type(lib().get_asset("Towers/Archer Tower"))

func _owned(type := "archer", id := "t1") -> OwnedTower:
	var o := OwnedTower.new()
	o.id = id
	o.type = type
	return o

func _wallet(amounts: Dictionary) -> TokenWallet:
	var w := TokenWallet.new()
	w.add_all(amounts)
	return w

func _result(level_id: String, won := true, quit := false) -> LevelResult:
	var r := LevelResult.new()
	r.level_id = level_id
	r.won = won
	r.quit = quit
	return r

# ------------------------------------------------------------------ content

func test_workshop_content_loads_without_problems() -> void:
	assert_eq(lib().problems.size(), 0, "\n".join(lib().problems))
	assert_eq(lib().all_of("FormAsset").size(), 9)
	assert_eq(lib().all_of("TokenAsset").size(), 6)
	assert_eq(lib().file_of(lib().get_asset("Units/Towers/Forms/Fire Archer")), "Units.json", "form units live in the file of their type")
	assert_eq(lib().file_of(lib().get_asset("Forms/Fire Archer")), "Forms.json")
	assert_not_null(lib().get_asset("Units/Towers/Archer"))
	var archer: TowerAsset = lib().get_asset("Towers/Archer Tower")
	assert_seq(archer.forms.map(func(f): return f.get_id()), ["archer-fire", "archer-inferno", "archer-poison", "archer-longbow"])
	assert_eq(lib().catalog.tokens.size(), 6)
	assert_eq(lib().catalog.forms.size(), 9)
	assert_eq(lib().catalog.find_form("guardian-spiked").get_display_name(), "Spiked Guardian")
	assert_eq(lib().catalog.find_token("ember-core").rarity, TokenRarity.Rare)

func test_workshop_forms_paths_and_art() -> void:
	for f in lib().all_of("FormAsset"):
		assert_eq(f.badge, "Assets/Art/UI/KitB/forms/%s.png" % f.get_id())
		assert_true(ResourceLoader.exists(ArtPaths.kit(f.badge)), f.badge)
		assert_eq(f.icon, f.tower.icon, "the base tower's portrait for now")
		assert_eq(f.entity.view, f.tower.entity.view, "the base model for now")
	for t in lib().all_of("TokenAsset"):
		assert_true(ResourceLoader.exists(ArtPaths.kit(t.icon)), t.icon)

func test_workshop_content_validates_and_converts() -> void:
	var findings := ContentCheck.run(lib().all, ContentCheck.vocabulary_of(lib().rules))
	var errors := findings.filter(func(f): return f.error).map(func(f): return f.message)
	assert_eq(errors.size(), 0, "\n".join(errors))
	var drop_warnings := findings.filter(func(f): return f.message.contains("no mission drops it"))
	assert_eq(drop_warnings.size(), 0, "every token drops from some mission")
	var c := AssetConverter.new()
	for a in lib().all_of("FormAsset"): assert_not_null(c.form(a), a.name)
	for a in lib().all_of("EntityAsset"): assert_not_null(c.entity(a), a.name)

func test_workshop_validation_catches_bad_forms() -> void:
	var f := FormAsset.new()
	f.name = "Broken"
	var errors := AssetValidator.validate_form(f)
	for part in ["no form ID", "no tower", "no entity", "costs no tokens"]:
		assert_true(errors.any(func(e): return e.contains(part)), part)
	var a: FormAsset = lib().get_asset("Forms/Fire Archer")
	var deep := FormAsset.new()
	deep.name = "Deep"; deep.id = "deep"; deep.tower = a.tower; deep.entity = a.entity; deep.unlock = a.unlock
	deep.parent = lib().get_asset("Forms/Inferno Archer")
	assert_true(AssetValidator.validate_form(deep).any(func(e): return e.contains("deep")))
	var other := FormAsset.new()
	other.name = "Other"; other.id = "other"; other.tower = lib().get_asset("Towers/Mage Tower"); other.entity = a.entity
	other.unlock = a.unlock; other.parent = a
	assert_true(AssetValidator.validate_form(other).any(func(e): return e.contains("another tower")))

func test_workshop_starter_numbers() -> void:
	var t := _archer_type()
	assert_eq(t.forms.size(), 4)
	var fire := t.find_form("archer-fire")
	assert_eq(fire.name, "Fire Archer")
	assert_eq(fire.tower, "archer")
	assert_null(fire.parent)
	assert_eq(fire.unlock, {"fire-arrow": 1})
	assert_eq(fire.token_name("fire-arrow"), "Fire Arrow")
	assert_eq(fire.entity.abilities[0].name, "fire-shot")
	var inferno := t.find_form("archer-inferno")
	assert_eq(inferno.parent, fire)
	assert_eq(inferno.depth, 2)
	assert_eq(inferno.unlock, {"ember-core": 1, "fire-arrow": 1})
	assert_eq(inferno.entity.abilities[0].cooldown, 2)
	var longbow := t.find_form("archer-longbow").entity
	assert_num(longbow.base_stats["Power"], 12.0)
	assert_num(longbow.base_stats["Range"], 3.0)
	assert_num(longbow.base_stats["Speed"], 1.0)
	var guardian := AssetConverter.new().tower_type(lib().get_asset("Towers/Guardian Tower"))
	var bastion := guardian.find_form("guardian-bastion").entity
	assert_num(bastion.base_stats["MaxHp"], 55.0)
	assert_num(bastion.base_stats["Range"], 3.0)
	var spiked := guardian.find_form("guardian-spiked").entity
	assert_num(spiked.base_stats["Power"], 8.0)
	assert_eq(spiked.passives[0].display_name, "Spiked Counter-attack")
	assert_eq(guardian.children_of(null).size(), 2)

func test_workshop_drops_come_from_missions() -> void:
	# Missions & Guild — Design: chapter levels drop nothing; "Found in" reads the missions' drops
	var cat := lib().catalog.to_catalog()
	assert_eq(cat.find("chapter1-1").win_tokens, {})
	assert_eq(cat.find("chapter2-2").first_win_tokens, {})
	var ms := lib().catalog.to_missions()
	assert_seq(Workshop.found_in("poison-gland", ms), ["night-watch", "drum-line"])
	assert_seq(Workshop.found_in("ember-core", ms), ["glutton-returns"])
	assert_seq(Workshop.found_in("nothing", ms), [])
	assert_seq(Workshop.found_in("ember-core", cat), ["chapter2-4"], "a LevelCatalog: the levels the missions play")

func test_workshop_content_hash_covers_forms_and_tokens() -> void:
	var names := ContentHash._files_of(ContentFiles.Folder, "").map(func(f): return f[0])
	assert_contains(names, "Forms.json")
	assert_contains(names, "Tokens.json")
	assert_eq(ContentHash.compute(), ContentHash.compute(ContentFiles.Folder))

# ------------------------------------------------------------------ rules

func test_workshop_can_unlock_reasons() -> void:
	var t := _archer_type()
	var fire := t.find_form("archer-fire")
	var inferno := t.find_form("archer-inferno")
	var o := _owned()
	var empty := TokenWallet.new()
	assert_false(Workshop.can_unlock(o, fire, empty))
	assert_eq(Workshop.last_reason, "Needs 1 more Fire Arrow")
	assert_false(Workshop.can_unlock(o, inferno, _wallet({"ember-core": 1, "fire-arrow": 1})))
	assert_eq(Workshop.last_reason, "Needs Fire Archer first")
	assert_false(Workshop.can_unlock(_owned("mage"), fire, _wallet({"fire-arrow": 1})))
	assert_eq(Workshop.last_reason, "Not a form of this tower")
	var reason := []
	assert_true(Workshop.can_unlock(o, fire, _wallet({"fire-arrow": 1}), reason))
	assert_eq(Workshop.last_reason, "")
	assert_null(reason[0])
	o.forms = ["archer-fire"]
	assert_false(Workshop.can_unlock(o, fire, _wallet({"fire-arrow": 1})))
	assert_eq(Workshop.last_reason, "Already unlocked")
	assert_false(Workshop.can_unlock(o, inferno, _wallet({"fire-arrow": 1})))
	assert_eq(Workshop.last_reason, "Needs 1 more Ember Core")
	assert_false(Workshop.can_unlock(o, inferno, empty))
	assert_eq(Workshop.last_reason, "Needs 1 more Ember Core and 1 more Fire Arrow")

func test_workshop_unlock_spends_and_keeps_the_form() -> void:
	var t := _archer_type()
	var o := _owned()
	var w := _wallet({"fire-arrow": 2})
	assert_true(Workshop.unlock(o, t.find_form("archer-fire"), w))
	assert_eq(w.count("fire-arrow"), 1)
	assert_seq(o.forms, ["archer-fire"])
	assert_eq(o.form, "", "unlocking does not switch the form")
	assert_eq(w.earned["fire-arrow"], 2, "spending never lowers what was earned")
	# refused: nothing spent
	assert_false(Workshop.unlock(o, t.find_form("archer-inferno"), w))
	assert_eq(w.count("fire-arrow"), 1)
	assert_seq(o.forms, ["archer-fire"])
	# per tower: another Archer has nothing unlocked
	var other := _owned("archer", "t2")
	assert_false(Workshop.is_unlocked(other, "archer-fire"))
	assert_seq(Workshop.unlockable(other, t, w).map(func(f): return f.id), ["archer-fire"])
	assert_eq(Workshop.path_cost(other, t.find_form("archer-inferno")), {"ember-core": 1, "fire-arrow": 2})

func test_workshop_set_form_only_to_unlocked_or_default() -> void:
	var o := _owned()
	assert_false(Workshop.set_form(o, "archer-fire"))
	assert_eq(Workshop.last_reason, "Not unlocked on this tower")
	assert_eq(o.form, "")
	o.forms = ["archer-fire"]
	assert_true(Workshop.set_form(o, "archer-fire"))
	assert_eq(o.form, "archer-fire")
	assert_true(Workshop.set_form(o, ""), "the default is always allowed")
	assert_eq(o.form, "")

func test_workshop_resolve_builds_the_form() -> void:
	var t := _archer_type()
	var o := _owned()
	assert_true(is_same(Workshop.resolve(o, t), t), "default form: the base type itself")
	o.forms = ["archer-fire"]
	o.form = "archer-fire"
	var r := Workshop.resolve(o, t)
	assert_eq(r.id, "archer", "keeps the type id")
	assert_eq(r.name, "Fire Archer")
	assert_eq(r.cost, t.cost, "cost -1 = the base's")
	assert_eq(r.entity, t.find_form("archer-fire").entity)
	assert_eq(r.form.id, "archer-fire")
	assert_eq(r.base, t)
	assert_eq(r.forms, t.forms)
	# an own cost wins
	var f := FormDef.new()
	f.id = "x"; f.name = "X"; f.cost = 7
	assert_eq(Workshop.resolve_form(t, f).cost, 7)
	assert_eq(Workshop.resolve_form(r, f).base, t, "resolving a resolved type starts from the base")
	# a form the content lost: the default
	o.form = "archer-gone"
	assert_true(is_same(Workshop.resolve(o, t), t))
	assert_null(Workshop.current_form(o, t))

func test_workshop_drops_first_win_once_win_every_time() -> void:
	var e := CatalogEntry.new()
	e.level_id = "a"
	e.first_win_tokens = {"fire-arrow": 1, "ember-core": 1}
	e.win_tokens = {"ember-core": 1}
	var p := LevelProgress.new()
	var r1 := _result("a")
	assert_eq(Workshop.drops(r1, p.record(r1), e), {"fire-arrow": 1, "ember-core": 2})
	var r2 := _result("a")
	assert_eq(Workshop.drops(r2, p.record(r2), e), {"ember-core": 1})
	var lost := _result("a", false)
	assert_eq(Workshop.drops(lost, p.record(lost), e), {})
	var quit := _result("a", true, true)
	assert_eq(Workshop.drops(quit, p.record(quit), e), {})
	assert_eq(Workshop.drops(_result("a"), null, null), {})
	# a first win after losses still gets the first-win drop
	var p2 := LevelProgress.new()
	var l := _result("a", false)
	p2.record(l)
	var w := _result("a")
	assert_eq(Workshop.drops(w, p2.record(w), e), {"fire-arrow": 1, "ember-core": 2})

func test_workshop_catalog_grants_drops_into_the_wallet() -> void:
	var mission := MissionBoard.find(lib().catalog.to_missions(), "night-watch")
	var p := MissionProgress.new()
	var wallet := TokenWallet.new()
	var r := _result("chapter2-1")
	var got := lib().catalog.grant_drops(r, p.record(r, mission.id), wallet, mission)
	assert_eq(got, {"arcane-shard": 1, "fire-arrow": 1, "poison-gland": 1})
	var r2 := _result("chapter2-1")
	lib().catalog.grant_drops(r2, p.record(r2, mission.id), wallet, mission)
	assert_eq(wallet.count("fire-arrow"), 2)
	assert_eq(wallet.count("arcane-shard"), 1)
	var lp := LevelProgress.new()
	var r3 := _result("chapter2-4")
	assert_eq(lib().catalog.grant_drops(r3, lp.record(r3), wallet), {}, "a chapter level drops nothing")
	assert_eq(HudText.rewards_text(got, lib().catalog), "Rewards: Arcane Shard ×1, Fire Arrow ×1, Poison Gland ×1")
	assert_eq(HudText.rewards_text({}, lib().catalog), "")
	assert_eq(HudText.rewards_text({"x": 2}), "Rewards: x ×2")

# ------------------------------------------------------------------ wallet and saves

func test_workshop_wallet() -> void:
	var w := TokenWallet.new()
	w.add("a", 2)
	w.add("b")
	w.add("c", 0)
	assert_eq(w.count("a"), 2)
	assert_eq(w.count("c"), 0)
	assert_false(w.counts.has("c"))
	assert_true(w.can_afford({"a": 2, "b": 1}))
	assert_eq(w.missing({"a": 3, "b": 1}), {"a": 1})
	assert_false(w.spend({"a": 3}))
	assert_eq(w.count("a"), 2, "all or nothing")
	assert_true(w.spend({"a": 1, "b": 1}))
	assert_eq(w.total(), 1)
	var back := TokenWallet.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	assert_eq(back.counts, {"a": 1, "b": 0})
	assert_eq(back.earned, {"a": 2, "b": 1})
	assert_eq(TokenWallet.from_dict(null).total(), 0)

func test_workshop_save_round_trip_and_old_saves() -> void:
	var g := GameData.new()
	var o := g.towers.add("archer")
	o.forms = ["archer-fire", "archer-poison"]
	o.form = "archer-poison"
	g.tokens.add("yew-bow", 3)
	var back := GameData.from_json(g.to_json())
	var b: OwnedTower = back.towers.towers[0]
	assert_seq(b.forms, ["archer-fire", "archer-poison"])
	assert_eq(b.form, "archer-poison")
	assert_eq(back.tokens.count("yew-bow"), 3)
	# a save from before the Workshop
	var old := GameData.from_dict({"towers": {"towers": [{"id": "x", "type": "archer", "customName": ""}], "hand": ["x"]}})
	assert_eq(old.towers.towers[0].form, "")
	assert_seq(old.towers.towers[0].forms, [])
	assert_eq(old.tokens.total(), 0)
	# a current form that is not unlocked falls back to the default
	var odd := GameData.from_dict({"towers": {"towers": [{"id": "x", "type": "archer", "form": "archer-fire", "forms": []}]}})
	assert_eq(odd.towers.towers[0].form, "")

# ------------------------------------------------------------------ integration

func test_workshop_hand_builds_forms_keeping_the_tower_id() -> void:
	var c := AssetConverter.new()
	var towers := TowerCollection.new()
	var a := towers.add("archer", "Robin")
	var b := towers.add("archer")
	towers.add_to_hand(a.id)
	towers.add_to_hand(b.id)
	a.forms = ["archer-fire"]
	a.form = "archer-fire"
	var problems := []
	var hand := lib().catalog.build_hand(towers, c, problems)
	assert_eq(problems.size(), 0)
	assert_eq(hand[0].id, a.id)
	assert_eq(hand[0].name, "Robin")
	assert_eq(hand[0].form.id, "archer-fire")
	assert_eq(hand[0].entity.name, "fire-archer")
	assert_eq(HudText.form_name(hand[0]), "Fire Archer")
	assert_true(HudText.badge_path(hand[0]).ends_with("forms/archer-fire.png"))
	assert_null(hand[1].form)
	assert_eq(hand[1].name, "Archer")
	assert_eq(HudText.form_name(hand[1]), "Archer")
	assert_eq(HudText.badge_path(hand[1]), "")
	assert_eq(towers.resolve(a.id, func(id): return c.tower_type(lib().catalog.find_tower(id))).name, "Fire Archer")
	b.form = "archer-gone"
	problems.clear()
	hand = lib().catalog.build_hand(towers, c, problems)
	assert_eq(problems.size(), 1)
	assert_null(hand[1].form, "unknown form: the default")

func test_workshop_level_places_the_form() -> void:
	var c := AssetConverter.new()
	var level := c.level(lib().get_asset("Levels/Chapter 1/1 First Steps"))
	var type := _archer_type(c)
	var f := FormDef.new()
	f.id = "cheap"; f.name = "Cheap Fire Archer"; f.cost = 1; f.entity = type.find_form("archer-fire").entity
	var t := TowerDef.new()
	t.id = "t1"
	t.type = Workshop.resolve_form(type, f)
	var s := LevelSession.new(level, c.rules(lib().rules), [t], 1)
	s.start()
	var energy := s.energy
	var placed: Entity = null
	for tile in level.buildable:
		if s.can_place("t1", tile):
			placed = s.place("t1", tile)
			break
	assert_not_null(placed)
	assert_eq(placed.def.name, "fire-archer")
	assert_eq(s.energy, energy - 1, "the form's cost")
	assert_eq(s.tower_id_of(placed), "t1")

func test_workshop_coop_hand_entries() -> void:
	assert_seq(CoopSession.parse_hand_entry("archer@archer-fire"), ["archer", "archer-fire"])
	assert_seq(CoopSession.parse_hand_entry("archer"), ["archer", ""])
	assert_eq(CoopSession.hand_entry("archer", "archer-fire"), "archer@archer-fire")
	assert_eq(CoopSession.hand_entry("archer"), "archer")
	var c := AssetConverter.new()
	var by_id := func(id): var ta: TowerAsset = lib().catalog.find_tower(id); return c.tower_type(ta) if ta != null else null
	var hand := CoopSession.build_hand("p1", ["archer@archer-fire", "archer", "archer@nope", "ghost@x"], by_id)
	assert_eq(hand.size(), 3)
	assert_seq(hand.map(func(d): return d.id), ["p1:archer#1", "p1:archer#2", "p1:archer#3"])
	assert_eq(hand[0].name, "Fire Archer")
	assert_eq(hand[0].entity.name, "fire-archer")
	assert_null(hand[1].form)
	assert_null(hand[2].form, "unknown form: the default")

func test_workshop_dev_cheats() -> void:
	var g := GameData.new()
	g.towers.add("archer")
	g.towers.add("cannon")
	assert_eq(SaveTools.unlock_all_forms(g, lib().catalog), 4)
	assert_eq(SaveTools.unlock_all_forms(g, lib().catalog), 0)
	assert_true(SaveTools.run("add_tokens", g, lib().catalog, ["ember-core", 5]).contains("Ember Core"))
	assert_eq(g.tokens.count("ember-core"), 5)
	assert_true(SaveTools.run("add_tokens", g, lib().catalog, ["nope", 1]).begins_with("Unknown token"))
	# the dev shortcuts win levels; chapter levels drop no tokens (missions do)
	var d := GameData.new()
	DevShortcuts.complete_chapter1(d, lib().catalog)
	assert_eq(d.tokens.total(), 0)

func test_workshop_menu_helpers() -> void:
	var o := _owned()
	assert_eq(MenuLogic.form_name(o, lib().catalog), "Archer")
	assert_eq(MenuLogic.badge_path(o, lib().catalog), "")
	o.forms = ["archer-longbow"]
	o.form = "archer-longbow"
	assert_eq(MenuLogic.form_name(o, lib().catalog), "Longbow")
	assert_eq(MenuLogic.badge_path(o, lib().catalog), "res://art/ui/KitB/forms/archer-longbow.png")
	o.form = "mage-pyro" # a form of another type is ignored
	assert_eq(MenuLogic.form_name(o, lib().catalog), "Archer")
