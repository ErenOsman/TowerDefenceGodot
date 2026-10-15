extends TestCase
## ContentLibrary.load_game(extra): a candidate folder merged on top of data/content (the content check job and the
## wiki's Content Editor use it), and the check job's verdict on a broken candidate and on an empty one.

var _dir := ""

func setup() -> void:
	_dir = ProjectSettings.globalize_path("user://test-content-candidate")
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in DirAccess.get_files_at(_dir): DirAccess.remove_absolute(_dir.path_join(f))

func teardown() -> void:
	for f in DirAccess.get_files_at(_dir): DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)

func _write(file: String, data) -> void:
	var f := FileAccess.open(_dir.path_join(file), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

func _status(id: String, max_stacks: int, reactions: Array = []) -> Dictionary:
	return {"id": id, "displayName": id.capitalize(), "description": "", "icon": null, "loopVfx": null, "tags": ["Debuff"],
		"stacking": "Stack", "maxStacks": max_stacks, "duration": 2, "durationUnit": "Turns", "modifiers": [], "replacements": [],
		"reactions": reactions, "passiveCondition": "", "aura": "", "shieldPool": "", "teamOverride": "None", "fixedTeam": 0,
		"persistsThroughDeath": false}

func test_a_candidate_entry_replaces_the_same_key_and_adds_new_ones() -> void:
	var plain := ContentLibrary.load_game()
	var burn_before: StatusAsset = plain.get_asset("Statuses/Burn")
	assert_not_null(burn_before)
	_write("Statuses.json", {"type": "StatusAsset", "assets": {
		"Statuses/Burn": _status("burn", 7, ["Reactions/Burn Tick"]),
		"Statuses/Candidate Chill": _status("candidate-chill", 3)}})
	var lib := ContentLibrary.load_game(_dir)
	assert_eq(lib.problems, [], "the candidate loads cleanly")
	var burn: StatusAsset = lib.get_asset("Statuses/Burn")
	assert_eq(burn.max_stacks, 7, "same key: the candidate's entry wins")
	assert_eq(lib.key_of(burn.reactions[0]), "Reactions/Burn Tick", "its references resolve into the content")
	assert_not_null(lib.get_asset("Statuses/Candidate Chill"), "a new key is added")
	assert_not_null(lib.get_asset("Statuses/Acid"), "the other entries of the file stay")
	assert_eq(lib.all_of("StatusAsset").size(), plain.all_of("StatusAsset").size() + 1)
	assert_eq(lib.all_of("FormAsset").size(), plain.all_of("FormAsset").size(), "the other files stay")
	assert_eq(ContentLibrary.load_game().get_asset("Statuses/Burn").max_stacks, burn_before.max_stacks, "nothing is written: load_game() alone is unchanged")

func test_a_candidate_replaces_a_workshop_entry() -> void:
	var plain := ContentLibrary.load_game()
	var form_key := ""
	for f in plain.all_of("FormAsset"):
		form_key = plain.key_of(f)
		break
	assert_ne(form_key, "", "the content has forms")
	var entry: Dictionary = ContentSerializer.to_json(plain.get_asset(form_key), plain)
	entry["order"] = 777
	_write("Forms.json", {"type": "FormAsset", "assets": {form_key: entry}})
	var lib := ContentLibrary.load_game(_dir)
	assert_eq(lib.problems, [])
	assert_eq(lib.get_asset(form_key).order, 777, "the key is replaced by the candidate")
	assert_eq(lib.all_of("FormAsset").size(), plain.all_of("FormAsset").size())

func test_a_missing_reference_is_reported() -> void:
	_write("Statuses.json", {"type": "StatusAsset", "assets": {"Statuses/Candidate Chill": _status("candidate-chill", 3, ["Reactions/No Such"])}})
	var lib := ContentLibrary.load_game(_dir)
	assert_true(lib.problems.any(func(p): return p.contains("Reactions/No Such") and p.contains("not found")), str(lib.problems))

func test_the_check_job_refuses_a_broken_candidate_and_passes_a_good_one() -> void:
	var runner = load("res://tools/content_check_runner.gd")
	_write("Statuses.json", {"type": "StatusAsset", "assets": {"Statuses/Candidate Chill": _status("candidate-chill", 3, ["Reactions/No Such"])}})
	var bad: Dictionary = runner.run([_dir])
	assert_eq(bad.code, 1)
	assert_false(bad.json.ok)
	assert_true(bad.json.errors.any(func(e): return str(e).contains("Reactions/No Such")), str(bad.json.errors))
	_write("Statuses.json", {"type": "StatusAsset", "assets": {"Statuses/Candidate Chill": _status("candidate-chill", 3, ["Reactions/Burn Tick"])}})
	var good: Dictionary = runner.run([_dir])
	assert_eq(good.code, 0, str(good.json.errors))
	assert_true(good.json.ok)
	assert_eq(good.json.probes.size(), 1)
	if good.json.probes.size() == 1:
		assert_eq(good.json.probes[0].entry, "Statuses/Candidate Chill")
		assert_true(good.json.probes[0].tables.size() >= 2, "per-turn tables for the plain and the shielded dummy")

func test_the_check_job_passes_an_empty_candidate() -> void:
	var r: Dictionary = load("res://tools/content_check_runner.gd").run([_dir])
	assert_eq(r.code, 0, str(r.json.errors))
	assert_true(r.json.ok)
	assert_true(r.json.warnings.any(func(w): return str(w).contains("no candidate entries")), str(r.json.warnings))
