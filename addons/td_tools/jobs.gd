extends RefCounted
## The TD Tools jobs: everything that runs the simulation code (Validate All, Balance Sheet, Game Reference,
## the save quick actions, the level list). In the editor they run in a headless Godot process on this project
## (td_tools_cli.gd), because the editor does not initialise the static variables of non-@tool scripts (the
## sim's ContextSpec, Parser, Targeting… tables would be null); elsewhere (tests, the CLI itself) in-process.
## Every job takes a Dictionary of arguments and returns a JSON-safe Dictionary ({"problem": …} on failure).

const CLI := "res://addons/td_tools/td_tools_cli.gd"
const WORK := "user://td_tools"
const TIMEOUT_MS := 180000

## Runs a job here and now.
static func run(cmd: String, args: Dictionary) -> Dictionary:
	var folder: String = args.get("folder", ContentFiles.Folder)
	match cmd:
		"levels": return _levels(ContentLibrary.load(folder))
		"validate":
			var lib := ContentLibrary.load(folder)
			var rows := ContentProblems.of_library(lib, folder)
			return {"rows": rows, "counts": ContentProblems.counts(rows), "assets": lib.all.size()}
		"balance":
			var lib := ContentLibrary.load(folder)
			var ex: bool = args.get("examples", false)
			return {"unit_columns": BalanceSheet.unit_columns(lib, ex), "units": _plain(BalanceSheet.unit_rows(lib, ex)),
				"abilities": _plain(BalanceSheet.ability_rows(lib, ex)), "statuses": _plain(BalanceSheet.status_rows(lib, ex))}
		"balance_csv":
			var path: String = args.get("path", BalanceSheet.CSV_PATH)
			var problem := BalanceSheet.export_csv(ContentLibrary.load(folder), path, args.get("examples", false))
			return {"problem": problem, "path": ProjectSettings.globalize_path(path)}
		"reference":
			var lib := ContentLibrary.load(folder)
			return {"pages": GameReference.pages(lib) if lib.catalog != null else {}}
		"reference_export":
			var lib := ContentLibrary.load(folder)
			var out: String = args.get("out", GameReference.Folder)
			return {"problem": GameReference.export(out, lib), "path": ProjectSettings.globalize_path(out)}
		"save_action":
			var path: String = args.get("path", SaveTools.PATH)
			var data := SaveTools.load_data(path)
			var line := SaveTools.run(str(args.get("action", "")), data, ContentLibrary.load(folder).catalog, args.get("arg"))
			var problem := SaveTools.write_data(path, data)
			return {"line": line, "problem": problem, "summary": SaveTools.summary(data)}
	return {"problem": "unknown job '%s'" % cmd}

## Rows without the asset objects (JSON-safe).
static func _plain(rows: Array) -> Array:
	var out := []
	for r in rows:
		var d: Dictionary = r.duplicate()
		d.erase("asset")
		out.append(d)
	return out

## The playtester's lists: levels in catalog order (tutorial first, then levels outside the catalog) and tower types.
static func _levels(lib: ContentLibrary) -> Dictionary:
	var levels := []
	var seen := {}
	var add := func(l: LevelAsset, group: String):
		if l == null or seen.has(l.get_id()): return
		seen[l.get_id()] = true
		var fixed := PackedStringArray()
		for t in l.fixed_hand:
			if t != null: fixed.append(t.get_display_name())
		levels.append({"id": l.get_id(), "label": "%s — %s (%s)" % [group, l.get_display_name(), l.get_id()],
			"info": "%d×%d · %d waves · energy %d (+%d) · %s" % [l.size.x, l.size.y, l.waves.size(), l.start_energy, l.energy_per_round,
				("its own hand: " + ", ".join(fixed) + " (the hand picked is ignored)") if fixed.size() > 0 else "hand cap %d (extra picks are dropped)" % l.hand_cap]})
	var catalog := lib.catalog
	if catalog != null:
		if catalog.tutorial != null: add.call(catalog.tutorial, "Tutorial")
		for e in catalog.entries():
			var ch = catalog.chapters[e[1]]
			add.call(e[0].level, ch.display_name if ch.display_name != "" else ch.id)
	for l in lib.all_of("LevelAsset"): add.call(l, "Not in the catalog")
	var types: Array = catalog.tower_types.duplicate() if catalog != null else []
	for t in lib.all_of("TowerAsset"):
		if not types.has(t): types.append(t)
	var towers := []
	for t in types:
		if t != null: towers.append({"id": t.get_id(), "label": "%s (%d) · %s" % [t.get_display_name(), t.cost, t.get_id()]})
	return {"levels": levels, "towers": towers, "assets": lib.all.size(), "problems": lib.problems.size()}

# ---------------------------------------------------------------- external runs

## Starts the job in a headless Godot on this project; returns {pid, out} (pid < 0 when it could not start).
static func start_external(cmd: String, args: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK))
	var stamp := "%s_%d_%d" % [cmd, Time.get_ticks_usec(), randi() % 100000]
	var args_path := ProjectSettings.globalize_path(WORK.path_join(stamp + ".args.json"))
	var out_path := ProjectSettings.globalize_path(WORK.path_join(stamp + ".out.json"))
	var f := FileAccess.open(args_path, FileAccess.WRITE)
	if f == null: return {"pid": -1, "out": out_path, "args": args_path}
	f.store_string(JSON.stringify(args))
	f.close()
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", CLI, "--", cmd, args_path, out_path])
	return {"pid": pid, "out": out_path, "args": args_path, "started": Time.get_ticks_msec()}

## The result of a finished external job (and removes its files).
static func finish_external(job: Dictionary) -> Dictionary:
	var result := {"problem": "the tools process gave no result (see the Output panel)"}
	if FileAccess.file_exists(job.out):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(job.out))
		if parsed is Dictionary: result = parsed
		DirAccess.remove_absolute(job.out)
	if FileAccess.file_exists(job.args): DirAccess.remove_absolute(job.args)
	return result

## Runs a job externally and waits for it (bounded by TIMEOUT_MS).
static func run_external(cmd: String, args: Dictionary) -> Dictionary:
	var job := start_external(cmd, args)
	if job.pid < 0: return {"problem": "could not start " + OS.get_executable_path()}
	while OS.is_process_running(job.pid):
		if Time.get_ticks_msec() - job.started > TIMEOUT_MS:
			OS.kill(job.pid)
			return {"problem": "the tools process timed out"}
		OS.delay_msec(50)
	return finish_external(job)

## Normalises a JSON round-trip result back to plain types where the tabs need ints.
static func as_int(v) -> int:
	return int(v) if v != null else 0
