extends SceneTree
## QA: the loading card hands over to the level cleanly. Starts the tutorial through the Loading screen (own save,
## user://loading_handoff.json) and checks every frame that no sequence line shows and no input is read while the
## loading screen is still up (opaque or fading out), and that the first line shows once it has gone. Saves
## <out>/handoff_1_fading.png (mid-fade: the board, no line) and handoff_2_first_line.png (the first frame with the line).
##   ~/godot/run.sh --daemon projects/td -s tools/qa/loading_handoff.gd -- user://handoff
## Prints HANDOFF OK / HANDOFF FAIL <why>.

var out_dir := "user://handoff"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveData")
	var flow = root.get_node("SceneFlow")
	root.get_node("GameApp").ensure_loaded()
	save.path = "user://loading_handoff.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", true) # the tutorial, through Loading
	var fails := []
	var fading_shot := false
	var first_line_frame := -1
	var closed_frame := -1
	for f in 1800:
		await process_frame
		var lc = _controller()
		var up: bool = flow.is_loading_screen_up()
		var loading = flow._loading_screen
		if up and closed_frame >= 0: fails.append("loading screen up again at frame %d" % f)
		if not up and closed_frame < 0 and lc != null: closed_frame = f
		if lc == null: continue
		var line_shown: bool = lc.sequence != null
		if up and line_shown: fails.append("a line shows under the loading screen at frame %d" % f)
		if up and lc.can_act: fails.append("input accepted under the loading screen at frame %d" % f)
		if up and not fading_shot and loading != null and loading.get("root") != null and loading.root.modulate.a < 0.6:
			fading_shot = true
			await _shot("handoff_1_fading")
		if line_shown and first_line_frame < 0:
			first_line_frame = f
			for i in 20: await process_frame # the dialogue box's open transition
			await _shot("handoff_2_first_line")
			break
	if closed_frame < 0: fails.append("the loading screen never closed")
	if first_line_frame < 0: fails.append("no line ever showed")
	print("loading closed at frame %d, first line at frame %d" % [closed_frame, first_line_frame])
	print("HANDOFF OK" if fails.is_empty() else "HANDOFF FAIL " + "; ".join(fails.slice(0, 5)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	quit()

func _controller():
	var s := current_scene
	if s == null: return null
	if s is LevelController: return s
	for n in s.find_children("*", "LevelController", true, false): return n
	return null

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out_dir, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
