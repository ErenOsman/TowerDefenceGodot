extends SceneTree
## Soak test: plays every level in the real level scene (board, views, presenters, VFX, plates, HUD) with the
## golden policy (see tools/golden.gd) and instant playback, watching for script errors. Not a rules test (the
## golden logs do that); it exercises the presentation on every level and every enemy/ability.
##   ~/godot/run.sh projects/td -s tools/soak.gd -- [max rounds] [level id]
## Exit code 1 when a level could not be set up. Script errors show as SCRIPT ERROR lines in the log.

var max_rounds := 15
var only := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: max_rounds = int(args[0])
	if args.size() > 1: only = args[1]
	_run.call_deferred()

func _run() -> void:
	var sd = root.get_node_or_null("SaveData")
	if sd != null:
		sd.path = "user://soak.json"
		sd.data = GameData.new()
		sd.data.profile.create("Soak")
		sd.data.settings.instant_playback = true
	var app = root.get_node("GameApp")
	app.ensure_loaded()
	var levels: Array = app.lib.all_of("LevelAsset")
	levels.sort_custom(func(a, b): return a.id < b.id)
	var failed := 0
	for la in levels:
		if only != "" and la.id != only: continue
		var t0 := Time.get_ticks_msec()
		var scene: PackedScene = load("res://game/level/level.tscn")
		var level = scene.instantiate()
		level.test_level_id = la.id
		level.test_hand = PackedStringArray(["archer", "guardian", "mage", "priest", "wisp", "ballista", "alchemist", "drummer", "cannon"])
		level.instant_override = true
		root.add_child(level)
		await _frames(6)
		if level.setup_error != null:
			print("SOAK %s: SETUP ERROR %s" % [la.id, level.setup_error])
			failed += 1
			level.queue_free()
			await _frames(2)
			continue
		var s = level.session
		var rounds := 0
		while not s.is_over and rounds < max_rounds:
			rounds += 1
			await _idle(level)
			for t in s.hand:
				if s.placed.has(t.id): continue
				var tile = null
				for y in s.state.grid.height:
					if tile != null: break
					for x in s.state.grid.width:
						if s.can_place(t.id, Vector2i(x, y)):
							tile = Vector2i(x, y); break
				if tile != null:
					level.toggle_placing(t.id)
					level.hover_override = tile
					await _frames(1)
					level.click_tile(tile) if level.has_method("click_tile") else s.place(t.id, tile)
					level.hover_override = null
					await _idle(level)
				if s.is_over: break
			if s.is_over: break
			for unit in s.player_units.duplicate():
				if not unit.alive: continue
				level.select(unit.id)
				await _frames(1)
				for ability in unit.abilities.duplicate():
					if ability.targeting.is_movement: continue
					if not s.can_cast(unit, ability): continue
					level.quick_cast(ability)
					await _idle(level)
					if s.is_over: break
				if s.is_over: break
			if s.is_over: break
			level.select(-1)
			level.end_round()
			await _idle(level)
		await _frames(10)
		print("SOAK %s: %s round %d energy %d events %d  (%.1f s)" % [la.id, Outcome.name_of(s.outcome), s.round, s.energy, s.log.events.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		level.queue_free()
		await _frames(3)
	print("SOAK DONE, setup failures: %d" % failed)
	quit(1 if failed > 0 else 0)

func _idle(level) -> void:
	var n := 0
	while level.director != null and level.director.busy and n < 600:
		await process_frame
		n += 1
	await process_frame

func _frames(n: int) -> void:
	for i in n: await process_frame
