extends SceneTree
var flow; var app; var save
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	save = root.get_node("SaveData"); flow = root.get_node("SceneFlow"); app = root.get_node("GameApp")
	save.path = "user://probe_speed.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path)); save.load_data(); app.ensure_loaded()
	root.get_node("SettingsMgr").set_game_speed(2.0)
	print("after set (no scene): ", Engine.time_scale)
	flow.go(flow.Welcome); await _until(func(): return flow.current == flow.Welcome and not flow.is_loading)
	await _frames(5); print("welcome: ", Engine.time_scale)
	current_scene.name_edit.text = "P"; current_scene.begin(false)
	await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading); await _frames(10)
	print("main menu: ", Engine.time_scale)
	app.play_level(app.catalog.find_level("chapter1-1"))
	await _until(func(): return flow.current == flow.Game and not flow.is_loading, 40.0); await _frames(30)
	print("level: ", Engine.time_scale)
	var hud = current_scene.get_node_or_null("Hud")
	var pause = null
	for n in current_scene.find_children("*", "HudPause", true, false): pause = n
	if pause != null:
		pause.open(); await _frames(5); print("paused: ", Engine.time_scale)
		if pause.has_method("_quit"): pause._quit()
		elif pause.has_method("_on_quit"): pause._on_quit()
		else: print("pause methods: ", pause.get_method_list().filter(func(m): return m.name.begins_with("_on") or "quit" in m.name).map(func(m): return m.name))
		await _until(func(): return flow.current != flow.Game and not flow.is_loading, 40.0); await _frames(10)
		print("after quit: scene=", flow.current, " scale=", Engine.time_scale)
	else: print("no pause node")
	flow.go(flow.MainMenu); await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading); await _frames(5)
	print("main menu again: ", Engine.time_scale)
	quit()
func _frames(n: int) -> void:
	for i in n: await process_frame
func _until(c: Callable, t: float = 20.0) -> void:
	var s := Time.get_ticks_msec()
	while not c.call():
		if Time.get_ticks_msec() - s > t * 1000.0: print("TIMEOUT"); return
		await process_frame
