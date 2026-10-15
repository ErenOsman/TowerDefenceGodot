extends SceneTree
## Regenerates the game reference docs/reference/{README,Towers,Enemies,Statuses,Levels,Codex}.md from data/content
## (GameReference, game/dev/game_reference.gd: the Unity export's sections — per tower / enemy stats, abilities with
## their numbers, passives; statuses; chapters and levels with maps, waves, energy and hand cap; the Codex order).
## Run it after content changes and commit the pages with the content:
##   godot --headless --path . -s tools/game_reference.gd [-- <output folder, default res://docs/reference>]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else GameReference.Folder
	var lib := ContentLibrary.load_game()
	if not lib.problems.is_empty():
		for p in lib.problems: printerr("content problem: " + p)
	var problem := GameReference.export(out, lib)
	if problem != "":
		printerr("game reference: " + problem)
		quit(1)
		return
	print("game reference: wrote %d pages to %s" % [GameReference.pages(lib).size(), ProjectSettings.globalize_path(out)])
	quit(0)
