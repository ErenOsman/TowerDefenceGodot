extends TestCase
## Upgrades — Design (data and rules): the `levels` ladders in Towers.json / Forms.json and their validation, the
## Blacksmith unlock in the catalog, TowerLevels (max level, steps, can_upgrade reasons incl. the form cap, upgrade,
## cumulative bonuses baked into the entity, Workshop.resolve at a level), TowerTasks (texts, counting from a played
## level's log, counting only from the unlock), saves, co-op hand entries "<type>@<form>:L<n>" and the dev cheats.

const LevelTests := preload("res://tests/test_level.gd")

static var _lib: ContentLibrary

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func _type(id := "archer", c: AssetConverter = null) -> TowerType:
	if c == null: c = AssetConverter.new()
	return c.tower_type(lib().catalog.find_tower(id))

func _owned(type := "archer", id := "t1") -> OwnedTower:
	var o := OwnedTower.new()
	o.id = id
	o.type = type
	return o

func _result(won := true, towers_lost := 0, quit := false) -> LevelResult:
	var r := LevelResult.new()
	r.won = won
	r.quit = quit
	r.towers_lost = towers_lost
	return r

func _task(kind: int, count := 1, mission := "") -> TaskDef:
	var t := TaskDef.new()
	t.kind = kind
	t.count = count
	t.mission = mission
	t.mission_name = "Drum Line" if mission != "" else ""
	return t

func _step(to: int, tasks: Array, bonuses: Array = []) -> TowerLevelDef:
	var s := TowerLevelDef.new()
	s.to = to
	s.tasks = tasks
	s.bonuses = bonuses
	return s

# ------------------------------------------------------------------ content

func test_every_tower_and_form_has_a_ladder() -> void:
	for t in lib().all_of("TowerAsset"):
		assert_eq(t.levels.size(), 4, "%s: 4 steps to level 5" % t.name)
		assert_eq(TowerLevels.max_level(_type(t.get_id())), 5, t.name)
	for f in lib().all_of("FormAsset"):
		assert_eq(f.levels.size(), 3, "%s: a 3-step ladder" % f.name)
		assert_true(f.levels.size() <= f.tower.levels.size())
	var c := lib().catalog
	assert_not_null(c.blacksmith_unlock)
	assert_eq(c.blacksmith_unlock, c.guild_unlock, "blacksmithUnlock = guildUnlock")

func test_the_starter_ladders_of_the_doc() -> void:
	var archer := _type("archer")
	var rows := []
	for s in archer.levels:
		var tasks: Array = s.tasks.map(func(t): return "%s %d" % [TowerTaskKind.name_of(t.kind), t.count])
		rows.append("%d: %s → %s" % [s.to, ", ".join(PackedStringArray(tasks)), TowerLevels.bonuses_text(s.bonuses)])
	assert_seq(rows, [
		"2: WinMission 1, Pay 100 → +2 Power",
		"3: WinMission 1, Damage 60, Pay 200 → +5 Max HP",
		"4: WinMission 2, Kills 10, Pay 300 → +1 Range",
		"5: WinMission 3, WinNoLoss 1, Pay 500 → +3 Power, +5 Max HP",
	])
	assert_eq(archer.levels[0].tasks[1].currency, "gold")
	assert_eq(TowerTasks.describe(archer.levels[1].tasks[2]), "Pay 200 gold")
	# forms: a shorter ladder without gold
	var fire := archer.find_form("archer-fire")
	assert_seq(fire.levels.map(func(s): return s.tasks.map(func(t): return TowerTaskKind.name_of(t.kind))),
		[["WinMission"], ["WinMission", "Kills"], ["WinMission", "WinNoLoss"]])
	var guardian := _type("guardian")
	assert_eq(TowerTasks.describe(guardian.levels[0].tasks[0]), "Win a mission with this tower")
	assert_eq(TowerLevels.bonuses_text(guardian.levels[0].bonuses), "+10 Max HP")
	assert_eq(TowerTasks.describe(guardian.levels[1].tasks[1]), "Take 40 hits and survive")
	assert_eq(TowerLevels.bonuses_text(guardian.levels[1].bonuses), "+2 Power")
	# the Drummer's placeholder names a mission
	var drum: TaskDef = _type("drummer").levels[1].tasks[0]
	assert_eq(drum.kind, TowerTaskKind.WinMissionId)
	assert_eq(drum.mission, "drum-line")
	assert_eq(TowerTasks.describe(drum), "Win Drum Line with this tower")
	assert_seq(TowerLevels.level_summary(archer.levels), ["Level 2: +2 Power", "Level 3: +5 Max HP", "Level 4: +1 Range", "Level 5: +3 Power, +5 Max HP"])

func test_ladders_validate_and_bad_ones_are_caught() -> void:
	var vocab := ContentCheck.vocabulary_of(lib().rules)
	for t in lib().all_of("TowerAsset"): assert_eq(AssetValidator.validate_tower(t, vocab).size(), 0, "\n".join(AssetValidator.validate_tower(t, vocab)))
	for f in lib().all_of("FormAsset"): assert_eq(AssetValidator.validate_form(f, vocab).size(), 0, "\n".join(AssetValidator.validate_form(f, vocab)))
	var bad := TowerLevelData.new()
	bad.to = 3
	var task := TowerTaskData.new()
	task.kind = TowerTaskKind.WinMissionId
	task.count = 0
	bad.tasks = [task]
	var bonus := LevelBonusData.new()
	bonus.stat = "Charm"
	bonus.kind = ModKind.PctMult
	bonus.amount = "lots"
	bad.bonuses = [bonus]
	var errors := AssetValidator.validate_ladder([bad], vocab)
	for part in ["expected 2", "count must be at least 1", "needs a mission", "'Charm' is not a registered stat", "Flat or PctAdd", "not a number"]:
		assert_true(errors.any(func(e): return e.contains(part)), part + " in " + str(errors))
	var empty := TowerLevelData.new()
	assert_true(AssetValidator.validate_ladder([empty]).any(func(e): return e.contains("no tasks")))
	# a form's ladder longer than its tower's
	var fire: FormAsset = lib().get_asset("Form/Fire Archer")
	var long := FormAsset.new()
	long.name = "Long"; long.id = "long"; long.tower = fire.tower; long.entity = fire.entity; long.unlock = fire.unlock
	long.levels = fire.tower.levels + [fire.levels[0]]
	assert_true(AssetValidator.validate_form(long).any(func(e): return e.contains("past its tower's")))

func test_content_json_round_trips_the_ladder() -> void:
	var archer: TowerAsset = lib().get_asset("Tower/Archer Tower")
	var j := ContentSerializer.to_json(archer, lib())
	assert_eq(j["levels"][1]["tasks"][1]["kind"], "Damage")
	assert_eq(j["levels"][1]["tasks"][1]["count"], 60)
	assert_eq(j["levels"][0]["bonuses"][0], {"stat": "Power", "kind": "Flat", "amount": "2"})
	var c := ContentSerializer.to_json(lib().catalog, lib())
	assert_eq(c["blacksmithUnlock"], c["guildUnlock"])

# ------------------------------------------------------------------ rules

func test_can_upgrade_reasons_and_upgrade() -> void:
	var type := _type("archer")
	var o := _owned()
	assert_eq(TowerLevels.level_of(o), 1)
	assert_eq(TowerLevels.step_for(o, type).to, 2)
	assert_false(TowerLevels.can_upgrade(o, type))
	assert_eq(TowerLevels.last_reason, "Win a mission with this tower")
	o.task_progress["2"] = [1]
	assert_false(TowerLevels.can_upgrade(o, type), "the gold task is open")
	assert_eq(TowerLevels.last_reason, "Pay 100 gold")
	o.task_progress["2"] = [1, 100]
	assert_true(TowerLevels.can_upgrade(o, type), TowerLevels.last_reason)
	assert_true(TowerLevels.upgrade(o, type))
	assert_eq(o.level, 2)
	assert_false(o.task_progress.has("2"), "the step's progress is dropped")
	assert_eq(TowerLevels.task_counts(o, type), [0, 0, 0])
	o.task_progress["3"] = [1, 42, 200]
	assert_false(TowerLevels.upgrade(o, type))
	assert_eq(TowerLevels.last_reason, "Deal 18 more damage with it")
	assert_eq(o.level, 2, "nothing changes on a refusal")
	# forms: own level and ladder, never past the base
	assert_false(TowerLevels.can_upgrade(o, type, "archer-fire"))
	assert_eq(TowerLevels.last_reason, "Not unlocked on this tower")
	assert_false(TowerLevels.can_upgrade(o, type, "mage-pyro"))
	assert_eq(TowerLevels.last_reason, "Not a form of this tower")
	o.forms = ["archer-fire"]
	assert_eq(TowerLevels.level_of(o, "archer-fire"), 1)
	assert_eq(TowerLevels.max_level(type.find_form("archer-fire")), 4)
	assert_false(TowerLevels.can_upgrade(o, type, "archer-fire"))
	assert_eq(TowerLevels.last_reason, "Win a mission with this tower")
	o.task_progress["archer-fire:2"] = [1]
	assert_true(TowerLevels.upgrade(o, type, "archer-fire"), TowerLevels.last_reason)
	assert_eq(o.form_levels, {"archer-fire": 2})
	o.task_progress["archer-fire:3"] = [1, 8]
	assert_false(TowerLevels.can_upgrade(o, type, "archer-fire"))
	assert_eq(TowerLevels.last_reason, "Raise Archer to level 3 first")
	o.task_progress["3"] = [1, 60, 200]
	assert_true(TowerLevels.upgrade(o, type))
	assert_true(TowerLevels.can_upgrade(o, type, "archer-fire"), "the base is ahead again")
	# max level
	o.level = 5
	assert_null(TowerLevels.step_for(o, type))
	assert_false(TowerLevels.can_upgrade(o, type))
	assert_eq(TowerLevels.last_reason, "Max level")
	assert_false(TowerLevels.can_upgrade(null, type))
	assert_eq(TowerLevels.last_reason, "No tower")

func test_missing_texts() -> void:
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.WinMission, 2), 1), "Win 1 more mission with this tower")
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.Kills, 10), 6), "Defeat 4 more enemies with it")
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.Kills, 10), 9), "Defeat 1 more enemy with it")
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.HitsTaken, 40), 28), "Take 12 more hits and survive")
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.Placed, 5), 3), "Place it 2 more times")
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.Damage, 60), 0), "Deal 60 damage with it")
	assert_eq(TowerTasks.missing(_task(TowerTaskKind.Damage, 60), 60), "")
	var own := _task(TowerTaskKind.Kills, 5)
	own.text = "Hunt slimes"
	assert_eq(TowerTasks.describe(own), "Hunt slimes")
	assert_eq(TowerTasks.missing(own, 2), "Hunt slimes (2/5)")
	assert_eq(TowerTasks.describe(_task(TowerTaskKind.WinNoLoss)), "Win without losing a tower")
	assert_eq(TowerTasks.describe(_task(TowerTaskKind.WinLevel, 3)), "Win 3 levels with this tower")
	assert_eq(TowerTasks.progress_text(_task(TowerTaskKind.Damage, 60), 42), "42/60")

func test_bonuses_are_cumulative_and_built_into_the_entity() -> void:
	var c := AssetConverter.new()
	var type := _type("archer", c)
	var base_power: float = type.entity.base_stats["Power"]
	assert_eq(base_power, 10.0)
	assert_true(is_same(TowerLevels.apply(type, 1), type), "level 1 = the type itself")
	var l3: TowerType = TowerLevels.apply(type, 3)
	assert_eq(l3.level, 3)
	assert_eq(l3.id, "archer")
	assert_eq(l3.cost, type.cost)
	assert_eq(l3.entity.base_stats["Power"], 12.0)
	assert_eq(l3.entity.base_stats["MaxHp"], 25.0)
	assert_eq(l3.entity.base_stats["Range"], 2.0)
	var l5: TowerType = TowerLevels.apply(type, 5)
	assert_eq(l5.entity.base_stats["Power"], 15.0)
	assert_eq(l5.entity.base_stats["MaxHp"], 30.0)
	assert_eq(l5.entity.base_stats["Range"], 3.0)
	assert_eq(type.entity.base_stats["Power"], 10.0, "the content's definition is untouched")
	assert_true(is_same(l5.entity.levelled_from, type.entity))
	assert_eq(l5.entity.abilities, type.entity.abilities)
	assert_true(is_same(c.asset_of(l5.entity, "EntityAsset"), lib().get_asset("Unit/Tower/Archer")), "model/icon lookups still find the asset")
	assert_eq(TowerLevels.bonuses_at(type.levels, 3).size(), 2)
	# PctAdd after Flat: (10 + 2) × 1.5 = 18
	var mods := [Modifier.new("Power", ModKind.Flat, "2"), Modifier.new("Power", ModKind.PctAdd, "0.5")]
	assert_eq(TowerLevels.stats_with({"Power": 10.0}, mods)["Power"], 18.0)
	assert_eq(TowerLevels.bonus_text(mods[1]), "+50% Power")
	var e: EntityDef = TowerLevels.apply(type.entity, 2, [_step(2, [], [Modifier.new("Speed", ModKind.Flat, "1")])])
	assert_eq(e.base_stats["Speed"], 3.0)
	# a placed levelled tower really has the stats
	l5.cost = 3 # the test level's start energy is 5
	var s := LevelTests._session([_tower_def(l5, "lv5")])
	var made := s.place("lv5", Vector2i(2, 2))
	assert_eq(made.max_hp, 30)
	assert_eq(made.hp, 30)

func _tower_def(t: TowerType, id: String) -> TowerDef:
	var d := TowerDef.new()
	d.id = id
	d.type = t
	return d

func test_workshop_resolve_builds_the_current_forms_level() -> void:
	var c := AssetConverter.new()
	var type := _type("archer", c)
	var o := _owned()
	assert_true(is_same(Workshop.resolve(o, type), type), "level 1, default form: the content type")
	o.level = 3
	var r := Workshop.resolve(o, type)
	assert_eq(r.level, 3)
	assert_eq(r.entity.base_stats["Power"], 12.0)
	o.forms = ["archer-fire"]
	o.form = "archer-fire"
	r = Workshop.resolve(o, type)
	assert_eq(r.form.id, "archer-fire")
	assert_eq(r.level, 1)
	assert_eq(r.entity.base_stats["Power"], 10.0, "the base's bonuses do not carry into a form")
	o.form_levels["archer-fire"] = 2
	r = Workshop.resolve(o, type)
	assert_eq(r.level, 2)
	assert_eq(r.entity.base_stats["Power"], 11.0, "the form's own ladder: +1 Power")
	assert_eq(r.name, "Fire Archer")
	assert_true(is_same(c.asset_of(r.entity, "EntityAsset"), lib().get_asset("Unit/Tower/Form/Fire Archer")))
	# the hand a level builds carries it
	var col := TowerCollection.new()
	col.towers.append(o)
	col.hand = [o.id]
	var hand := col.build_hand(func(id): return type if id == "archer" else null)
	assert_eq(hand[0].id, "t1")
	assert_eq(hand[0].entity.base_stats["Power"], 11.0)

# ------------------------------------------------------------------ tasks from a played level

## Plays test_level's 7 × 3 level with one archer (power 10) that shoots every slime: 3 slimes, 3 kills; won.
func _played(type: TowerType, tower_id: String) -> LevelSession:
	var s := LevelTests._session([_tower_def(type, tower_id)])
	var archer := s.place(tower_id, Vector2i(2, 2))
	var shoot: AbilityDef = archer.abilities[0]
	for guard in 30:
		if s.is_over: break
		var aims := Targeting.valid_aims(s.state, archer.id, shoot)
		if aims.size() > 0 and s.can_cast(archer, shoot): s.cast(archer, shoot, aims[0])
		if not s.is_over: s.end_round()
	return s

func _fixture_type() -> TowerType:
	var t: TowerType = LevelTests._archer_tower().type
	t.levels = [_step(2, [_task(TowerTaskKind.Kills, 10), _task(TowerTaskKind.Damage, 60), _task(TowerTaskKind.WinLevel),
		_task(TowerTaskKind.Placed, 2), _task(TowerTaskKind.HitsTaken, 5), _task(TowerTaskKind.WinMission)], [Modifier.new("Power", ModKind.Flat, "2")])]
	return t

func test_tasks_count_from_a_played_level() -> void:
	var type := _fixture_type()
	var o := _owned("archer", "own-1")
	var s := _played(type, "own-1")
	assert_eq(s.outcome, Outcome.Won)
	var result := LevelResults.from(s, "test", "", false)
	var facts := TowerTasks.tally(s.log)
	assert_eq(facts.kills.get("own-1", 0), 3, "the archer killed the three slimes")
	var dealt := 0
	for e in s.log.of_type(GameEventType.DamageDealt):
		if e.source == s.placed["own-1"]: dealt += int(e.facts["FinalDamage"])
	assert_eq(facts.damage.get("own-1", 0), dealt)
	assert_true(dealt >= 30)
	assert_eq(facts.placed.get("own-1", 0), 1)
	var adv := TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type)], "", true)
	assert_eq(o.task_progress["2"], [3, mini(60, dealt), 1, 1, 0, 0], "no mission: WinMission stays 0; no hits taken")
	assert_eq(adv.size(), 4)
	assert_eq(adv[0].text, "Defeat 10 enemies with it")
	assert_eq(adv[2].done, true)
	assert_false(adv.any(func(a): return a.ready), "WinMission still open: not ready")
	var lines := TowerTasks.lines(adv)
	assert_eq(lines[0], "Archer: 3 / 10 kills +3")
	assert_eq(lines[2], "Archer: 1 / 1 levels won +1")
	adv[0].index = 3
	assert_eq(TowerTasks.progress_line(adv[0]), "Archer (tower 3): 3 / 10 kills +3")
	# the same level as a mission: WinMission counts; counts are capped
	var again := TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type, "", "Ayla's Archer")], "patrol", true)
	assert_eq(o.task_progress["2"], [6, mini(60, dealt * 2), 1, 2, 0, 1])
	assert_true(again.any(func(a): return a.name == "Ayla's Archer"))
	assert_false(again.any(func(a): return a.task == 2), "WinLevel was already complete")
	assert_false(again.any(func(a): return a.ready), "Kills 6/10 and hits 0/5 still open")
	# finishing the step in a level marks it ready once
	o.task_progress["2"] = [9, 60, 1, 2, 5, 1]
	var last := TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type, "", "Guardian")], "", true)
	assert_eq(TowerTasks.ready_lines(last), ["Guardian is ready to upgrade! Go to the Blacksmith."])
	assert_eq(TowerTasks.ready_lines(TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type)], "", true)), [], "already ready: no second line")

func test_a_tower_in_a_form_counts_toward_both_ladders() -> void:
	var c := AssetConverter.new()
	var type := _type("archer", c)
	var o := _owned("archer", "own-1")
	o.forms = ["archer-fire"]
	o.form = "archer-fire"
	var log := EventLog.new()
	var adv := TowerTasks.apply(_result(), log, [TowerTasks.entry(o, type)], "patrol", true)
	assert_eq(o.task_progress, {"2": [1, 0], "archer-fire:2": [1]}, "the base's step and the form's step both count (gold untouched; forms have none)")
	assert_seq(adv.map(func(a): return "%s|%s" % [a.name, a.form]), ["Archer|", "Fire Archer|archer-fire"])
	assert_eq(adv[0].ready, false, "the base step still waits for its gold")
	assert_eq(TowerTasks.deposit(o, type, "", 1, 500), 100)
	assert_eq(TowerTasks.deposit(o, type, "archer-fire", 1, 500), 0, "a form has no gold task")
	assert_true(TowerLevels.can_upgrade(o, type), TowerLevels.last_reason)
	assert_false(TowerLevels.can_upgrade(o, type, "archer-fire"), "the form waits for its tower (base level 1 = form level 1)")
	assert_eq(TowerLevels.ready_count([o], func(_id): return type), 0, "the base is ready, but the tower wears the waiting form")
	assert_true(TowerLevels.upgrade(o, type))
	assert_eq(TowerLevels.ready_count([o], func(_id): return type), 1, "now the worn form is the ready one")
	o.task_progress["3"] = [1, 60, 200]
	assert_eq(TowerLevels.ready_count([o], func(_id): return type), 1, "the base is ready too, but only the current form counts")
	o.form = ""
	assert_eq(TowerLevels.ready_count([o], func(_id): return type), 1, "back in the base form: the base counts, the form not")
	assert_eq(TowerLevels.current_ladder(o, type), "")
	# the base form: only the base ladder
	var p := _owned("archer", "own-2")
	p.forms = ["archer-fire"]
	TowerTasks.apply(_result(), log, [TowerTasks.entry(p, type)], "patrol", true)
	assert_eq(p.task_progress, {"2": [1, 0]})

func test_only_the_acting_tower_and_towers_present_count() -> void:
	var type := _fixture_type()
	var o := _owned("archer", "own-1")
	var other := _owned("archer", "own-2")
	var s := _played(type, "own-1")
	var result := LevelResults.from(s, "test", "", false)
	TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type), TowerTasks.entry(other, type)], "", true)
	assert_eq(other.task_progress["2"][0], 0, "kills only for the tower that made them")
	assert_eq(other.task_progress["2"][2], 1, "a win counts for every tower in the hand")
	var absent := _owned("archer", "own-3")
	TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type)], "", true)
	assert_true(absent.task_progress.is_empty(), "a tower not in the level gets nothing")

func test_counting_starts_at_the_blacksmith_unlock() -> void:
	var type := _fixture_type()
	var o := _owned("archer", "own-1")
	var s := _played(type, "own-1")
	var result := LevelResults.from(s, "test", "", false)
	assert_eq(TowerTasks.apply(result, s.log, [TowerTasks.entry(o, type)], "patrol", false), [])
	assert_true(o.task_progress.is_empty(), "nothing counts before the unlock")
	assert_eq(TowerTasks.apply(LevelResults.from(s, "test", "", true), s.log, [TowerTasks.entry(o, type)], "", true), [], "a quit counts nothing")
	# the unlock itself: Chapter 2's last level won
	var g := GameData.new()
	assert_false(lib().catalog.blacksmith_unlocked(g.progress))
	SaveTools.run("chapter2", g, lib().catalog)
	assert_true(lib().catalog.blacksmith_unlocked(g.progress))
	var none := GameCatalogAsset.new()
	assert_false(none.blacksmith_unlocked(g.progress), "no unlock level: closed")

func test_win_tasks_mission_ids_and_no_loss() -> void:
	var t := TowerType.new()
	t.id = "archer"
	t.name = "Archer"
	t.levels = [_step(2, [_task(TowerTaskKind.WinMissionId, 1, "drum-line"), _task(TowerTaskKind.WinNoLoss, 2), _task(TowerTaskKind.WinMission)])]
	var o := _owned()
	var log := EventLog.new()
	TowerTasks.apply(_result(true, 1), log, [TowerTasks.entry(o, t)], "patrol")
	assert_eq(o.task_progress["2"], [0, 0, 1], "another mission; a tower was lost")
	TowerTasks.apply(_result(false), log, [TowerTasks.entry(o, t)], "drum-line")
	assert_eq(o.task_progress["2"], [0, 0, 1], "a loss wins nothing")
	TowerTasks.apply(_result(true), log, [TowerTasks.entry(o, t)], "drum-line")
	assert_eq(o.task_progress["2"], [1, 1, 1])
	assert_false(TowerLevels.can_upgrade(o, t))
	assert_eq(TowerLevels.last_reason, "Win 1 more time without losing a tower")
	# at max level nothing is counted
	o.level = 2
	assert_eq(TowerTasks.apply(_result(true), log, [TowerTasks.entry(o, t)], "drum-line"), [])

# ------------------------------------------------------------------ saves, co-op, dev

func test_save_round_trip_and_old_saves() -> void:
	var g := GameData.new()
	var o := g.towers.add("archer")
	o.level = 3
	o.forms = ["archer-fire"]
	o.form_levels = {"archer-fire": 2}
	o.task_progress = {"4": [1, 6], "archer-fire:3": [0, 2]}
	var plain := g.towers.add("guardian")
	g.profile.blacksmith_seen = true
	var d := g.to_dict()
	assert_false(d["towers"]["towers"][1].has("level"), "a level-1 tower's save entry is unchanged")
	assert_true(d["profile"]["blacksmithSeen"])
	var back := GameData.from_json(g.to_json())
	var b := back.towers.find(o.id)
	assert_eq(b.level, 3)
	assert_eq(b.form_levels, {"archer-fire": 2})
	assert_eq(b.task_progress, {"4": [1, 6], "archer-fire:3": [0, 2]})
	assert_eq(back.towers.find(plain.id).level, 1)
	assert_true(back.profile.blacksmith_seen)
	var old := GameData.from_dict({"towers": {"towers": [{"id": "x", "type": "archer", "customName": "", "form": "", "forms": []}], "hand": ["x"]}, "profile": {"created": true}})
	assert_eq(old.towers.find("x").level, 1)
	assert_true(old.towers.find("x").form_levels.is_empty())
	assert_true(old.towers.find("x").task_progress.is_empty())
	assert_false(old.profile.blacksmith_seen)

func test_coop_hand_entries_carry_the_level() -> void:
	assert_seq(CoopSession.parse_hand_entry("archer@archer-fire:L3"), ["archer", "archer-fire", 3])
	assert_seq(CoopSession.parse_hand_entry("guardian:L2"), ["guardian", "", 2])
	assert_seq(CoopSession.parse_hand_entry("guardian:Lx"), ["guardian:Lx", "", 1], "a bad suffix is not a level")
	assert_eq(CoopSession.hand_entry("archer", "archer-fire", 3), "archer@archer-fire:L3")
	assert_eq(CoopSession.hand_entry("guardian", "", 2), "guardian:L2")
	assert_eq(CoopSession.hand_entry("guardian", "", 1), "guardian", "level 1 adds nothing (older clients read it)")
	var c := AssetConverter.new()
	var by_id := func(id): return _type(id, c)
	var hand := CoopSession.build_hand("p1", ["archer:L5", "archer@archer-fire:L2", "guardian", "archer:L99"], by_id)
	assert_seq(hand.map(func(t): return t.id), ["p1:archer#1", "p1:archer#2", "p1:guardian#1", "p1:archer#3"])
	assert_eq(hand[0].entity.base_stats["Power"], 15.0)
	assert_eq(hand[1].form.id, "archer-fire")
	assert_eq(hand[1].entity.base_stats["Power"], 11.0)
	assert_eq(hand[2].type.level, 1)
	assert_eq(hand[3].type.level, 5, "capped at the max level")
	# the co-op session ids map back through TowerTasks.entry's session id
	var e := TowerTasks.entry(_owned("archer", "own"), _type("archer", c), "p1:archer#1")
	assert_eq(e.session_id, "p1:archer#1")

func test_dev_actions_and_ready_count() -> void:
	var g := GameData.new()
	var cat := lib().catalog
	var a := g.towers.add("archer")
	a.forms = ["archer-fire"]
	g.towers.add("guardian")
	var lookup := SaveTools.type_lookup(cat)
	assert_eq(TowerLevels.ready_count(g.towers.towers, lookup), 0)
	var line := SaveTools.run("complete_tasks", g, cat)
	assert_true(line.contains("3 step(s)"), line)
	assert_eq(TowerLevels.ready_count(g.towers.towers, lookup), 2)
	assert_false(TowerLevels.can_upgrade(a, lookup.call("archer"), "archer-fire"), "the form waits for its tower")
	assert_eq(TowerLevels.last_reason, "Raise Archer to level 2 first")
	line = SaveTools.run("level_up_towers", g, cat)
	assert_true(line.contains("3 level(s)"), line)
	assert_eq(a.level, 2)
	assert_eq(TowerLevels.level_of(a, "archer-fire"), 2, "the form follows up to its tower's level")
	assert_false(a.task_progress.has("2"), "the completed step's progress is dropped")
	SaveTools.run("level_up_towers", g, cat)
	assert_eq(a.level, 3)
	assert_eq(TowerLevels.level_of(a, "archer-fire"), 3)
	for i in 5: SaveTools.run("level_up_towers", g, cat)
	assert_eq(a.level, 5)
	assert_eq(TowerLevels.level_of(a, "archer-fire"), 4)
	var ids := SaveTools.ACTIONS.map(func(x): return x[0])
	assert_contains(ids, "level_up_towers")
	assert_contains(ids, "complete_tasks")
