extends SceneTree
## Regenerates res://data/coop.json from the co-op missions (Missions & Guild — Design): the relay reads that file
## for a room's shared_pool, the game reads the missions. Run after changing data/content/Missions.json:
##   godot --headless --path . -s tools/coop_json.gd
## (tests/test_missions.gd fails while the two disagree.)

func _initialize() -> void:
	var lib := ContentLibrary.load_game()
	var list := CoopList.from_missions(lib.catalog.to_missions() if lib.catalog != null else [])
	var f := FileAccess.open(CoopList.Path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s" % CoopList.Path)
		quit(1)
		return
	f.store_string(list.to_json_text())
	f.close()
	print("wrote %s: %d co-op mission level(s)" % [CoopList.Path, list.levels.size()])
	quit(0)
