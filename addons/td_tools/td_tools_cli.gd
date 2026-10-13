extends SceneTree
## The TD Tools jobs from the command line (the editor dock runs these in a headless Godot; see jobs.gd):
##   godot --headless --path . -s res://addons/td_tools/td_tools_cli.gd -- <job> <args.json> <out.json>
##   godot --headless --path . -s res://addons/td_tools/td_tools_cli.gd -- reference_export    (args/out optional)
## Jobs: levels, validate, balance, balance_csv, reference, reference_export, save_action. Writes the JSON result
## to out.json (or prints it) and quits.

const Jobs := preload("res://addons/td_tools/jobs.gd")

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("usage: -- <job> [args.json] [out.json]")
		quit(2)
		return
	var args := {}
	if a.size() > 1 and FileAccess.file_exists(a[1]):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(a[1]))
		if parsed is Dictionary: args = parsed
	var result := Jobs.run(a[0], args)
	var text := JSON.stringify(result)
	if a.size() > 2:
		var f := FileAccess.open(a[2], FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
	else:
		print(text if text.length() < 4000 else "%s: %d bytes of JSON" % [a[0], text.length()])
	quit(0 if str(result.get("problem", "")) == "" else 1)
