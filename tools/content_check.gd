extends SceneTree
## Content check (direct run; the resident daemon runs the same as its job `content_check`):
##   godot --headless --path . -s tools/content_check.gd -- <candidate dir> [level id]
##   godot --headless --path . -s tools/content_check.gd -- --schema
## <candidate dir> holds one or more <Type>.json files in the content format ({"type": "StatusAsset", "assets": {key: entry}},
## the same shape as data/content-godot). They are merged over data/content + data/content-godot (same key → the
## candidate wins), validated and probed; see tools/content_check_runner.gd. Prints ONE JSON object between the lines
## CONTENT_CHECK_BEGIN / CONTENT_CHECK_END ({ok, errors[], warnings[], probes[{entry, kind, lines[], tables[], warnings[]}],
## candidates[], baseline{}, elapsed_ms}); --schema prints the content format between CONTENT_SCHEMA_BEGIN / _END.
## Exit code 0 ok, 1 errors, 2 usage.

func _initialize() -> void:
	var r: Dictionary = load("res://tools/content_check_runner.gd").run(Array(OS.get_cmdline_user_args()))
	var marker: String = r.get("marker", "CONTENT_CHECK")
	print(marker + "_BEGIN")
	print(JSON.stringify(r.json, "", false))
	print(marker + "_END")
	quit(int(r.code))
