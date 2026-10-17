extends SceneTree
## Dev: the Camp after Chapter 2 with the Blacksmith station button forced pressed (Eren 2026-10-17: its bottom clips).
var flow; var app; var save
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	save = root.get_node("SaveData"); flow = root.get_node("SceneFlow"); app = root.get_node("GameApp")
	save.path = "user://probe_pressed_camp.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path)); save.load_data(); app.ensure_loaded()
	save.profile.player_name = "P"; app.complete_chapter2(); save.save()
	flow.go(flow.Camp); await _until(func(): return flow.current == flow.Camp and not flow.is_loading); await _frames(30)
	var camp = current_scene
	if camp.has_method("close_welcome"): camp.close_welcome()
	if camp.has_method("end_tour"): camp.end_tour()
	await _frames(10)
	var b = camp.buttons.get("Workshop")
	b.force_state(true, true)
	await _frames(6); await _shot("camp_blacksmith_pressed")
	b.force_state(false, false); await _frames(6); await _shot("camp_blacksmith_normal")
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
