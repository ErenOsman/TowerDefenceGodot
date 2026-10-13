extends SceneTree
## Dev script: renders the F1 dev panel under Xvfb (its proof) and checks its level shortcuts.
##   ~/godot/run.sh projects/td --resolution 1280x720 -s tools/dev_shot.gd [-- <out dir>]
## Uses its own save (user://dev_shot.json, deleted first). Opens the Level scene (chapter1-1, a DevLaunch request
## with a fixed hand and seed), opens the panel through the DevPanel autoload as F1 would, screenshots the Save,
## Shortcuts and Log tabs, gives +100 energy, closes the panel and checks the session's energy went up.
## PNGs: <out dir>/dev_<n>_<tab>.png (default user://dev_shot).

var out_dir := "user://dev_shot"
var _n := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveData")
	save.path = "user://dev_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	root.get_node("GameApp").ensure_loaded()
	SaveTools.run("chapter1", save.data, root.get_node("GameApp").catalog)
	save.save()
	print("[dev] F1 panel enabled: ", root.get_node("DevPanel").enabled)
	DevLaunch.request(DevLaunch.make("chapter1-1", ["archer", "mage", "cannon"], 3, true, false))
	change_scene_to_file(DevLaunch.LEVEL_SCENE)
	await _until(func(): return current_scene is LevelController and current_scene.session != null, 30.0)
	var lc: LevelController = current_scene
	await _until(func(): return not lc.director.busy, 20.0)
	await _frames(30)
	var hand := lc.session.hand.map(func(t): return t.name)
	print("[dev] level %s, hand %s, instant %s" % [lc.level.get_id(), hand, lc.instant])
	print("[dev] something to show in the log")
	push_warning("[dev] a warning for the log tab")
	# F1 (as the autoload sees it)
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	root.push_input(key)
	await _frames(3)
	var panel: TdDevPanel = root.get_node("DevPanel").panel
	print("[dev] panel open: ", panel != null and panel.visible, ", tree paused: ", paused)
	await _frames(5)
	await _shot("save")
	panel.tabs.current_tab = 1
	await _frames(5)
	var before: int = lc.session.energy
	panel._add_energy(100)
	await _frames(3)
	await _shot("shortcuts")
	panel.tabs.current_tab = 2
	await _frames(5)
	await _shot("log")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await _frames(3)
	print("[dev] after Esc: panel open %s, paused %s" % [panel.visible, paused])
	await _until(func(): return not lc.director.busy, 10.0)
	await _frames(10)
	print("[dev] energy %d -> %d (%s)" % [before, lc.session.energy, "OK" if lc.session.energy == before + 100 else "WRONG"])
	await _shot("level_after")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
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
	_n += 1
	var p := "%s/dev_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
