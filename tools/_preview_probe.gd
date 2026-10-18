extends SceneTree
## TEMP probe: captures every frame of opening and closing the Camp level select (preview flicker).
var out_dir := "user://preview_probe"
var flow: Node
var app: Node
var save: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("SaveData")
	flow = root.get_node("SceneFlow")
	app = root.get_node("GameApp")
	save.path = "user://preview_probe.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	app.complete_chapter1()
	save.data.profile.camp_seen = true
	flow.go(flow.Camp)
	await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 30.0)
	await _frames(30)
	var camp = current_scene
	if camp.has_method("close_welcome") and camp.welcome_card.visible: camp.close_welcome()
	camp.end_tour()
	await _frames(5)
	var ls = camp.open_chapter(0)
	for i in 14: await _shot("open_%02d" % i)
	await _frames(30)
	ls.back()
	for i in 10: await _shot("close_%02d" % i)
	print("PROBE DONE")
	quit()

func _frames(n: int) -> void:
	for i in n: await process_frame

func _until(cond: Callable, timeout: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > timeout * 1000.0: return
		await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out_dir, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", label, " f=", Engine.get_frames_drawn(), " t=", Time.get_ticks_msec())
