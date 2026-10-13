extends SceneTree
## Dev script: runs the app shell end to end under Xvfb and saves a screenshot of each step.
##   ~/godot/run.sh projects/td -s tools/shot_flow.gd
## Uses its own save (user://shot_gamedata.json, deleted first) so the real save is untouched.
## Steps: Boot → Welcome (first launch) → begin(skip tutorial) → MainMenu → Camp (first-open frame times
## printed as CAMP FIRST OPEN …) → home (LevelSelect) → a level
## through the Loading screen. PNGs: user://shot_<n>_<scene>.png.

var _n := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var save_data = root.get_node("SaveData")
	var flow = root.get_node("SceneFlow")
	save_data.path = "user://shot_gamedata.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_data.path))
	save_data.load_data()
	if OS.get_environment("TD_SHOT_CAMP_ONLY") != "":
		# cheaper frames (llvmpipe renders ~1 s per 1080p camp frame), so a first-open hitch stands out
		save_data.settings.is_fullscreen = false
		root.get_node("SettingsMgr").apply_all()
		DisplayServer.window_set_size(Vector2i(640, 360))
	change_scene_to_file("res://game/boot.tscn")
	await _frames(20)
	await _shot("boot")
	await _until(func(): return flow.current == flow.Welcome and not flow.is_loading, 15.0)
	await _frames(5)
	await _shot("welcome")
	save_data.begin("Eren", false)
	await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading, 10.0)
	await _frames(5)
	await _shot("main_menu")
	print("profile: ", save_data.profile.player_name, " towers=", save_data.towers.towers.size(), " tutorial=", save_data.profile.tutorial)
	await _measure_open(flow, flow.Camp, "Camp first")
	await _frames(5)
	await _shot("camp")
	if OS.get_environment("TD_SHOT_CAMP_ONLY") != "":
		flow.go(flow.MainMenu)
		await _until(func(): return flow.current == flow.MainMenu and not flow.is_loading, 10.0)
		await _frames(5)
		await _measure_open(flow, flow.Camp, "Camp second")
		print("SHOT FLOW DONE (camp only)")
		quit()
		return
	root.get_node("GameApp").go_home()
	await _until(func(): return flow.current == flow.LevelSelect and not flow.is_loading, 10.0)
	await _frames(5)
	await _shot("level_select")
	var app = root.get_node("GameApp")
	app.play_level(app.next_main_level())
	await _until(func(): return flow.current == flow.Loading and not flow.is_loading, 10.0)
	await _frames(1)
	await _shot("loading")
	await _until(func(): return flow.current == flow.Game and not flow.is_loading and not flow.target_ready, 30.0)
	await _frames(10)
	await _shot("level")
	print("music: ", root.get_node("AudioMgr").current_music())
	print("SHOT FLOW DONE")
	quit()

## Opens a scene and prints how long it took to open and the longest frame of the switch and the 30 frames after.
func _measure_open(flow, id: int, label: String) -> void:
	var t0 := Time.get_ticks_usec()
	var last := t0
	var longest := 0
	flow.go(id)
	while flow.current != id or flow.is_loading:
		await process_frame
		var now := Time.get_ticks_usec()
		longest = maxi(longest, now - last)
		last = now
		if now - t0 > 20000000: break
	var opened := Time.get_ticks_usec() - t0
	var frames := []
	var renders := []
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		longest = maxi(longest, now - last)
		frames.append((now - last) / 1000)
		renders.append(roundi(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()))
		last = now
	var steady := 0.0
	for i in range(15, 30): steady += renders[i] / 15.0
	print("%s OPEN: %d ms until open (load %d ms, instantiate+_ready %d ms), longest frame %d ms; render cpu ms first frames %s, steady %d" % [
		label.to_upper(), opened / 1000, flow.last_load_ms, flow.last_build_ms, longest / 1000, str(renders.slice(0, 6)), steady])

func _frames(n: int) -> void:
	for i in n: await process_frame

func _until(cond: Callable, timeout: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > timeout * 1000.0:
			print("TIMEOUT waiting; scene=", current_scene)
			return
		await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "user://shot_%d_%s.png" % [_n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
