extends SceneTree
## Dev script: the pre-rendered level pictures on screen (LevelPreviewCache). The Camp's level select opened on
## Chapter 2 and shot on its first drawn frames (the picture must already be the board: no minimap, no flicker), a
## second level selected (shot the next frame), the frames right after it closes (nothing left behind), then the
## Guild's mission board and a mission's detail (their thumbnails without waiting for any render).
##   cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot --resolution 1280x720 tools/level_previews_shot.gd -- <out dir>
## Prints "live renders queued: N" (0 when every picture came from a PNG).

var out_dir := "user://level_previews_shot"
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
	save.path = "user://level_previews_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", false)
	app.ensure_loaded()
	app.complete_chapter1()
	app.win_first_levels(6)
	save.data.profile.camp_seen = true
	flow.go(flow.Camp)
	await _until(func(): return flow.current == flow.Camp and not flow.is_loading, 30.0)
	await _frames(30)
	var camp = current_scene
	if camp.has_method("close_welcome") and camp.welcome_card.visible: camp.close_welcome()
	camp.end_tour()
	await _frames(5)
	var ls = camp.open_chapter(1)
	await _shot("level_select_f1")
	await _shot("level_select_f2")
	print("live renders queued: ", CoopBoardPic._queue.size() + (1 if CoopBoardPic._busy else 0))
	var other := ""
	for r in ls.visible_rows:
		if r.level_id != ls.selected and ls._is_unlocked(r.level_id):
			other = r.level_id
			break
	ls.select(other)
	await _shot("level_select_other")
	print("live renders queued: ", CoopBoardPic._queue.size() + (1 if CoopBoardPic._busy else 0))
	ls.back()
	await _shot("closed_f1")
	await _shot("closed_f2")
	await _frames(5)
	var guild = load("res://game/ui/screens/guild.tscn").instantiate()
	root.add_child(guild)
	await _frames(30)
	guild.close_welcome()
	await _frames(5)
	var board = guild.open_missions()
	await _frames(2)
	await _shot("mission_board")
	print("live renders queued: ", CoopBoardPic._queue.size() + (1 if CoopBoardPic._busy else 0))
	board.open_detail("patrol")
	await _frames(2)
	await _shot("mission_detail")
	print("live renders queued: ", CoopBoardPic._queue.size() + (1 if CoopBoardPic._busy else 0))
	print("LEVEL PREVIEWS SHOT DONE")
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
	print("saved ", ProjectSettings.globalize_path(p))
