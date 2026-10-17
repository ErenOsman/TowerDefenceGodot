extends SceneTree
## Builds the UI theme from res://data/content/UITheme.json and the sprite kit (logic: tools/theme_builder.gd, which
## lists every input):
##   godot --headless --path . -s tools/build_theme.gd             writes game/ui/theme/td_tokens.gd, td_theme.tres
##                                                                  and the half-size icons in game/ui/theme/half/
##   godot --headless --path . -s tools/build_theme.gd -- --check  writes nothing; prints what a re-run would change
##                                                                  and exits 1 on drift (tests/test_ui_theme.gd does
##                                                                  the same check in ./test.sh)
## Re-run it after changing an input. The outputs are never edited by hand. After adding a theme icon (a _half_tex
## sprite) run it twice: the first run makes the half-size PNG, the import picks it up, the second run uses it.

const ThemeBuilder := preload("res://tools/theme_builder.gd")

func _initialize() -> void:
	var b := ThemeBuilder.new()
	if "--check" in OS.get_cmdline_user_args():
		var bad := b.drift()
		for line in bad:
			print("THEME DRIFT " + line)
		print("build_theme --check: %s" % ("OK, the outputs match the inputs" if bad.is_empty() else "%d file(s) drifted; re-run tools/build_theme.gd after moving hand edits into the inputs" % bad.size()))
		quit(0 if bad.is_empty() else 1)
		return
	quit(0 if b.write() == OK else 1)
