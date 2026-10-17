extends SceneTree
## Dev: renders the main menu and a settings tab with buttons forced to the pressed look (Eren 2026-10-17: "pressed buttons look buggy").
var flow; var app; var save
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	save = root.get_node("SaveData"); flow = root.get_node("SceneFlow"); app = root.get_node("GameApp")
	save.path = "user://probe_pressed.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path)); save.load_data(); app.ensure_loaded()
	save.profile.player_name = "P"; app.win_first_levels(2); save.save()
	flow.go(flow.MainMenu); await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading); await _frames(20)
	var btns = current_scene.find_children("*", "TdButton", true, false)
	var i := 0
	for b in btns:
		if b.visible and b.interactable:
			b.force_state(false, i % 2 == 0); i += 1
	await _frames(6); await _shot("pressed_main_menu")
	var s = current_scene.open_popup("settings"); await _frames(20); s.show_tab(2); await _frames(5)
	i = 0
	for b in s.find_children("*", "TdButton", true, false):
		if b.visible and b.interactable: b.force_state(false, i % 2 == 0); i += 1
	await _frames(6); await _shot("pressed_settings")
	# the kit demo's states grid (Normal / Hover / Pressed / Selected / Disabled per style; menu: normal, hover, hover+pressed)
	s.close(); await _frames(10)
	change_scene_to_file("res://game/ui/elements/demo.tscn"); await _frames(30)
	await _shot("pressed_kit_demo")
	quit()
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://pressed"))
	root.get_viewport().get_texture().get_image().save_png("user://pressed/%s.png" % n); print("saved ", n)
func _frames(n: int) -> void:
	for k in n: await process_frame
func _until(c: Callable, t: float = 20.0) -> void:
	var st := Time.get_ticks_msec()
	while not c.call():
		if Time.get_ticks_msec() - st > t * 1000.0: print("TIMEOUT"); return
		await process_frame
