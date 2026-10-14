extends SceneTree
## Test runner: godot --headless --path . -s tests/run.gd [--filter name]
## Runs every test_* method of every res://tests/test_*.gd (TestCase subclasses). Exit code 1 on failures.
## A GDScript runtime error inside a test prints an error (see the log) but the run continues; such a test
## is counted as an error when its script printed one (watch for "SCRIPT ERROR" lines).
## The discovery / run / summary logic lives in tests/suite_runner.gd, shared with the resident job runner
## tools/daemon.gd (which runs the same suite in-process: /home/ubuntu/godot/README-daemon.md).

func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--filter" and i + 1 < args.size(): filter = args[i + 1]
	var r: Dictionary = load("res://tests/suite_runner.gd").run(filter)
	print(r.text)
	quit(1 if r.failed > 0 else 0)
