extends "res://tools/hud_shot.gd"
## Headless-render proof of the guided tutorial (hud_shot.gd's tutorial mode on the tutorial level): saves
## <prefix>_t2_piece … _t8c_refused PNGs (see hud_shot.gd `_tutorial`).
##   ~/godot/run.sh projects/td -s tools/tutorial_shot.gd -- <out dir> [prefix] [short]   (short: stop after t6b)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	level_id = "tutorial"
	prefix = "tut"
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: prefix = args[1]
	tutorial_short = args.size() > 2 and args[2] == "short"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()
