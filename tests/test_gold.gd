extends TestCase
## Upgrades — Design § Gold (Eren 2026-10-16): every level step has one gold task "Pay N gold" (TowerTaskKind.Pay with
## a currency), filled only by deposits (TowerTasks.deposit / GameApp.pay_into, never by play); gold is saved in
## GameData.gold (missions are its source: test_missions); the validator's gold rule; the dev action "Grant 500 gold".
## The GameApp part uses its own save path (restored after).

const LevelTests := preload("res://tests/test_level.gd")

static var _lib: ContentLibrary

var _sd
var _old_data
var _old_path := ""

func lib() -> ContentLibrary:
	if _lib == null: _lib = ContentLibrary.load_game()
	return _lib

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func setup() -> void:
	_sd = _tree().root.get_node("SaveData")
	_old_data = _sd.data
	_old_path = _sd.path
	_sd.path = "user://test_gold.json"
	_sd.data = GameData.new()

func teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_sd.path))
	_sd.data = _old_data
	_sd.path = _old_path

func _type(id := "archer") -> TowerType:
	return AssetConverter.new().tower_type(lib().catalog.find_tower(id))

func _owned(type := "archer", id := "t1") -> OwnedTower:
	var o := OwnedTower.new()
	o.id = id
	o.type = type
	return o

func _data_task(kind: int, count := 1, currency := "") -> TowerTaskData:
	var t := TowerTaskData.new()
	t.kind = kind
	t.count = count
	t.currency = currency
	return t

func _data_step(to: int, tasks: Array) -> TowerLevelData:
	var s := TowerLevelData.new()
	s.to = to
	s.tasks = tasks
	return s

func _has(errors: Array, part: String) -> bool:
	return errors.any(func(e): return e.contains(part))

# ------------------------------------------------------------------ content and validation

func test_every_step_has_one_gold_task() -> void:
	for a in lib().all_of("TowerAsset") + lib().all_of("FormAsset"):
		for s in a.levels:
			var gold: Array = s.tasks.filter(func(t): return t.kind == TowerTaskKind.Pay and t.currency == "gold")
			assert_eq(gold.size(), 1, "%s step to %d" % [a.name, s.to])
	# rising placeholders: towers 20/40/70/100, forms 15/30/50
	var archer := _type()
	assert_seq(archer.levels.map(func(s): return s.tasks[TowerTasks.gold_task_index(s)].count), [20, 40, 70, 100])
	var fire := archer.find_form("archer-fire")
	assert_seq(fire.levels.map(func(s): return s.tasks[TowerTasks.gold_task_index(s)].count), [15, 30, 50])
	var j := ContentSerializer.to_json(lib().get_asset("Tower/Archer Tower"), lib())
	assert_eq(j["levels"][0]["tasks"][1], {"kind": "Pay", "currency": "gold", "count": 20, "mission": null, "text": ""})

func test_validator_gold_rule() -> void:
	var none := AssetValidator.validate_ladder([_data_step(2, [_data_task(TowerTaskKind.WinMission)])])
	assert_true(_has(none, "needs exactly one gold Pay task"), str(none))
	assert_true(_has(none, "has 0"), str(none))
	var two := AssetValidator.validate_ladder([_data_step(2, [_data_task(TowerTaskKind.Pay, 10, "gold"), _data_task(TowerTaskKind.Pay, 5, "gold")])])
	assert_true(_has(two, "has 2"), str(two))
	var ok := AssetValidator.validate_ladder([_data_step(2, [_data_task(TowerTaskKind.WinMission), _data_task(TowerTaskKind.Pay, 20, "gold")])])
	assert_eq(ok, [] as Array[String])
	var zero := AssetValidator.validate_ladder([_data_step(2, [_data_task(TowerTaskKind.Pay, 0, "gold")])])
	assert_true(_has(zero, "count must be at least 1"), str(zero))
	var nocur := AssetValidator.validate_ladder([_data_step(2, [_data_task(TowerTaskKind.Pay, 5), _data_task(TowerTaskKind.Pay, 5, "gold")])])
	assert_true(_has(nocur, "Pay needs a currency"), str(nocur))
	var stray := AssetValidator.validate_ladder([_data_step(2, [_data_task(TowerTaskKind.Kills, 5, "gold"), _data_task(TowerTaskKind.Pay, 5, "gold")])])
	assert_true(_has(stray, "currency is only for Pay tasks"), str(stray))
	# a token currency: must be a real token id (validate_ladder with the ids; Validate All passes the content's)
	var token_step := _data_step(2, [_data_task(TowerTaskKind.Pay, 2, "fire-arrow"), _data_task(TowerTaskKind.Pay, 20, "gold")])
	var bad_step := _data_step(2, [_data_task(TowerTaskKind.Pay, 2, "dragon-scale"), _data_task(TowerTaskKind.Pay, 20, "gold")])
	assert_eq(AssetValidator.validate_ladder([token_step], null, ["fire-arrow"]), [] as Array[String])
	assert_true(_has(AssetValidator.validate_ladder([bad_step], null, ["fire-arrow"]), "neither gold nor a token id"))
	var archer: TowerAsset = lib().get_asset("Tower/Archer Tower")
	var probe := TowerAsset.new()
	probe.name = "Probe"; probe.id = "probe"; probe.entity = archer.entity
	probe.levels = [token_step]
	var tokens := lib().all_of("TokenAsset")
	var vocab := ContentCheck.vocabulary_of(lib().rules)
	var msgs := func(list: Array) -> Array: return ContentCheck.run(list, vocab).filter(func(f): return f.error).map(func(f): return f.message)
	assert_false(_has(msgs.call([probe] + tokens), "Pay currency"), "fire-arrow is a token")
	probe.levels = [bad_step]
	assert_true(_has(msgs.call([probe] + tokens), "Pay currency 'dragon-scale' is neither gold nor a token id"))

# ------------------------------------------------------------------ texts and deposits

func test_pay_texts() -> void:
	var t := TaskDef.new()
	t.kind = TowerTaskKind.Pay
	t.currency = "gold"
	t.count = 40
	assert_true(TowerTasks.is_pay(t))
	assert_true(TowerTasks.is_gold(t))
	assert_eq(TowerTasks.describe(t), "Pay 40 gold")
	assert_eq(TowerTasks.progress_text(t, 25), "25 / 40 gold")
	assert_eq(TowerTasks.progress_text(t, 99), "40 / 40 gold")
	assert_eq(TowerTasks.missing(t, 0), "Pay 40 gold")
	assert_eq(TowerTasks.missing(t, 25), "Pay 15 more gold")
	assert_eq(TowerTasks.missing(t, 40), "")
	assert_eq(TowerTasks.noun(t), "gold")
	t.currency = "fire-arrow"
	t.count = 2
	assert_false(TowerTasks.is_gold(t))
	assert_eq(TowerTasks.describe(t), "Pay 2 fire-arrow")

func test_deposit_partial_and_full() -> void:
	var type := _type()
	var o := _owned()
	var step := TowerLevels.step_for(o, type)
	var gi := TowerTasks.gold_task_index(step)
	assert_eq(gi, 1, "step 2: Win a mission, Pay 20 gold")
	assert_eq(TowerTasks.deposit(o, type, "", gi, 8), 8, "partial: all of a small amount")
	assert_eq(TowerLevels.task_counts(o, type), [0, 8])
	assert_eq(TowerTasks.pay_missing(o, type, "", gi), 12)
	assert_eq(TowerTasks.progress_text(step.tasks[gi], 8), "8 / 20 gold")
	assert_eq(TowerTasks.deposit(o, type, "", gi, 500), 12, "only what is missing")
	assert_eq(TowerLevels.task_counts(o, type), [0, 20])
	assert_eq(TowerTasks.deposit(o, type, "", gi, 500), 0, "full: nothing more taken")
	assert_eq(TowerTasks.deposit(o, type, "", 0, 500), 0, "not a Pay task")
	assert_eq(TowerTasks.deposit(o, type, "", 9, 500), 0, "no such task")
	assert_false(TowerLevels.can_upgrade(o, type))
	assert_eq(TowerLevels.last_reason, "Win a mission with this tower")
	o.task_progress["2"][0] = 1
	assert_true(TowerLevels.upgrade(o, type), TowerLevels.last_reason)
	assert_false(o.task_progress.has("2"), "deposited gold is spent with the step")
	assert_eq(TowerTasks.deposit(o, type, "", 2, 0), 0, "no gold: nothing")
	assert_eq(TowerTasks.deposit(o, type, "", 2, 15), 15, "step 3's gold task (index 2)")
	assert_eq(TowerLevels.task_counts(o, type), [0, 0, 15])
	# forms: only an unlocked form takes gold
	assert_eq(TowerTasks.deposit(o, type, "archer-fire", 1, 50), 0, "not unlocked")
	o.forms = ["archer-fire"]
	assert_eq(TowerTasks.deposit(o, type, "archer-fire", 1, 50), 15)
	assert_eq(o.task_progress["archer-fire:2"], [0, 15])
	o.level = 5
	assert_eq(TowerTasks.deposit(o, type, "", 2, 50), 0, "max level: no step")

func test_pay_never_advances_from_play() -> void:
	var t: TowerType = LevelTests._archer_tower().type
	var pay := TaskDef.new()
	pay.kind = TowerTaskKind.Pay
	pay.currency = "gold"
	pay.count = 30
	var kills := TaskDef.new()
	kills.kind = TowerTaskKind.Kills
	kills.count = 10
	var step := TowerLevelDef.new()
	step.to = 2
	step.tasks = [kills, pay]
	t.levels = [step]
	var d := TowerDef.new()
	d.id = "own-1"
	d.type = t
	var s := LevelTests._session([d])
	var archer := s.place("own-1", Vector2i(2, 2))
	var shoot: AbilityDef = archer.abilities[0]
	for guard in 30:
		if s.is_over: break
		var aims := Targeting.valid_aims(s.state, archer.id, shoot)
		if aims.size() > 0 and s.can_cast(archer, shoot): s.cast(archer, shoot, aims[0])
		if not s.is_over: s.end_round()
	var o := _owned("archer", "own-1")
	var result := LevelResults.from(s, "test", "", false)
	assert_true(result.won)
	var adv := TowerTasks.apply(result, s.log, [TowerTasks.entry(o, t)], "patrol", true)
	assert_eq(o.task_progress["2"][1], 0, "a won mission pays no gold into the step")
	assert_true(o.task_progress["2"][0] > 0, "the kills counted")
	assert_false(adv.any(func(a): return a.kind == TowerTaskKind.Pay))

# ------------------------------------------------------------------ saves, GameApp, dev

func test_gold_save_round_trip_and_old_saves() -> void:
	var g := GameData.new()
	assert_eq(g.gold, 0)
	g.gold = 240
	var d := g.to_dict()
	assert_eq(d["gold"], 240)
	assert_eq(GameData.from_json(g.to_json()).gold, 240)
	var old := GameData.from_dict({"towers": {"towers": [], "hand": []}, "profile": {"created": true}})
	assert_eq(old.gold, 0, "a save from before gold has none")
	assert_eq(GameData.from_dict({"gold": -5}).gold, 0, "never negative")
	assert_eq(GameData.from_dict({"gold": "lots"}).gold, 0, "not a number: 0")

func test_grant_gold_action() -> void:
	var g := GameData.new()
	assert_eq(SaveTools.run("grant_gold", g, lib().catalog), "+500 gold (now 500).")
	SaveTools.run("grant_gold", g, lib().catalog)
	assert_eq(g.gold, 1000)
	assert_contains(SaveTools.ACTIONS.map(func(x): return x[0]), "grant_gold")

func test_game_app_pay_into() -> void:
	var app = _tree().root.get_node("GameApp")
	var o: OwnedTower = _sd.towers.add("archer")
	_sd.data.gold = 30
	assert_eq(app.gold(), 30)
	assert_eq(app.pay_into(o, "", 1), 0, "the Blacksmith is closed: no levels yet")
	DevShortcuts.complete_main_chapters(_sd.data, app.catalog, 2)
	assert_true(app.blacksmith_unlocked())
	assert_eq(app.pay_into(o, "", 0), 0, "not the gold task")
	assert_eq(app.pay_into(o, "", 1), 20, "Pay 20 gold: 20 of 30 taken")
	assert_eq(app.gold(), 10)
	assert_eq(o.task_progress["2"], [0, 20])
	assert_eq(app.pay_into(o, "", 1), 0, "already paid")
	assert_eq(app.gold(), 10)
	var saved := GameData.from_json(FileAccess.get_file_as_string(_sd.path))
	assert_eq(saved.gold, 10, "saved")
	o.task_progress["2"][0] = 1
	assert_true(app.upgrade_tower(o))
	assert_eq(app.pay_into(o, "", 2), 10, "partial: all the 10 left into Pay 40 gold")
	assert_eq(app.gold(), 0)
	assert_eq(app.pay_into(o, "", 2), 0, "no gold left")
	assert_eq(TowerLevels.task_counts(o, app.tower_type("archer")), [0, 0, 10])
