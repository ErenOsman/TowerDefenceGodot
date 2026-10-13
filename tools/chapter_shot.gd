extends SceneTree
## Dev script: screenshots the Camp's chapter select (cards with board thumbnails, level dots, bar, reward).
##   ~/godot/run.sh projects/td -s tools/chapter_shot.gd [-- <out dir>]
##   ~/godot/run.sh projects/td -s tools/chapter_shot.gd -- <out dir> complete   (only the first two shots: quick)
##   ~/godot/run.sh projects/td --resolution 1280x720 -s tools/chapter_shot.gd -- <out dir>
## Own save (user://chapter_shot.json, deleted first). Shots: chapter_complete (Chapter 1 complete via
## GameApp.complete_chapter1, Chapter 2 active), chapter_progress (+ one Chapter 2 level won), chapter_locked
## (a save with only 2 levels won: Chapter 2 locked; not reachable in play, the Camp opens after Chapter 1, but
## it shows the locked card), chapter_placeholder (the first frames, minimaps before the thumbnails render).

var out_dir := "user://chapter_shot"
var flow: Node
var app: Node
var save: Node
var quick := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	quick = args.size() > 1 and args[1] == "complete"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("SaveData")
	flow = root.get_node("SceneFlow")
	app = root.get_node("GameApp")
	save.path = "user://chapter_shot.json"
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
	var ch = camp.open_chapters()
	await _frames(2)
	await _shot("chapter_placeholder")
	await _frames(60)
	await _shot("chapter_complete")
	for c in ch.card_infos: print("card: ", c.name, " | ", c.progress, " | ", c.reason, " | active=", c.active, " | reward=", c.reward_name)
	if quick:
		print("CHAPTER SHOT DONE")
		quit()
		return
	# one Chapter 2 level won
	app.win_first_levels(5)
	ch.draw()
	await _frames(30)
	await _shot("chapter_progress")
	# hover the second card
	ch.close()
	await _frames(20)
	# a save with only the first two levels won: Chapter 2 locked
	save.data.progress.levels.clear()
	app.win_first_levels(2)
	ch = camp.open_chapters()
	await _frames(40)
	await _shot("chapter_locked")
	for c in ch.card_infos: print("card: ", c.name, " | ", c.progress, " | ", c.reason, " | active=", c.active)
	# clicking an open chapter opens the Camp's level panel on it
	ch.cards[0].clicked.emit()
	await _frames(40)
	await _shot("chapter_click_levels")
	for p in TdPopup.open_popups.duplicate(): p.close()
	await _frames(20)
	# two sample side chapters (in memory only, never saved) to check the second row: one open, one locked
	app.complete_chapter1()
	var ch1: ChapterData = app.catalog.chapters[0]
	var ch2: ChapterData = app.catalog.chapters[1]
	var mill := ChapterData.new()
	mill.display_name = "The Old Mill"
	mill.kind = ChapterKind.Side
	mill.requires = [ch1.levels[2].level]
	for d in ch2.levels.slice(0, 3): mill.levels.append(d)
	var crypt := ChapterData.new()
	crypt.display_name = "The Crypt"
	crypt.kind = ChapterKind.Side
	crypt.requires = [ch2.levels[3].level]
	for d in ch1.levels.slice(1, 3): crypt.levels.append(d)
	app.catalog.chapters.append(mill)
	app.catalog.chapters.append(crypt)
	ch = camp.open_chapters()
	await _frames(60)
	await _shot("chapter_side_rows")
	for c in ch.card_infos: print("card: ", c.name, " | ", c.progress, " | ", c.reason, " | active=", c.active)
	app.catalog.chapters.resize(2)
	print("CHAPTER SHOT DONE")
	quit()

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
	var p := "%s/%s.png" % [out_dir, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p), " t=", Time.get_ticks_msec())
